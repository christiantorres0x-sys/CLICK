import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/external_player.dart';
import '../../domain/repositories/music_provider.dart';
import '../library/library_controller.dart';
import '../settings/settings_controller.dart';

class PlaybackState {
  const PlaybackState({
    this.queue = const [],
    this.currentIndex,
    this.isPlaying = false,
    this.isLoading = false,
    this.position = Duration.zero,
    this.shuffle = false,
    this.repeat = RepeatMode.off,
    this.errorMessage,
    this.unavailableKeys = const {},
  });

  final List<Track> queue;
  final int? currentIndex;
  final bool isPlaying;
  final bool isLoading;
  final Duration position;
  final bool shuffle;
  final RepeatMode repeat;
  final String? errorMessage;

  /// Keys of tracks the provider reported as unavailable this session.
  final Set<String> unavailableKeys;

  Track? get current {
    final i = currentIndex;
    if (i == null || i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  Duration get duration => current?.duration ?? Duration.zero;

  List<Track> get upNext {
    final i = currentIndex;
    if (i == null || i + 1 >= queue.length) return const [];
    return queue.sublist(i + 1);
  }

  PlaybackState copyWith({
    List<Track>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isLoading,
    Duration? position,
    bool? shuffle,
    RepeatMode? repeat,
    String? errorMessage,
    bool clearError = false,
    Set<String>? unavailableKeys,
  }) =>
      PlaybackState(
        queue: queue ?? this.queue,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        isLoading: isLoading ?? this.isLoading,
        position: position ?? this.position,
        shuffle: shuffle ?? this.shuffle,
        repeat: repeat ?? this.repeat,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        unavailableKeys: unavailableKeys ?? this.unavailableKeys,
      );
}

/// The single playback controller (SRS 9.2): widgets never create their own
/// player. A track plays either on a simulated clock (the sample catalog has no
/// audio) or through an [ExternalPlayer] (the official YouTube player), chosen
/// by the [PlayableSource] the provider returns.
class PlaybackController extends Notifier<PlaybackState> {
  static const tickInterval = Duration(milliseconds: 500);
  static const restartThreshold = Duration(seconds: 3);
  static const externalLoadTimeout = Duration(seconds: 20);

  Timer? _timer;
  Timer? _loadTimeout;
  int _token = 0;
  bool _disposed = false;

  ExternalPlayer? _external;
  StreamSubscription<ExternalPlayerEvent>? _externalSub;

  @override
  PlaybackState build() {
    ref.onDispose(() {
      _disposed = true;
      _stopTimer(); // FR-PLAY-08: release resources on dispose
      _loadTimeout?.cancel();
      _externalSub?.cancel();
      _safe(_external?.pause());
    });
    Future.microtask(_applySavedDefaults);
    return const PlaybackState();
  }

  Future<void> _applySavedDefaults() async {
    try {
      final settings = await loadAppSettings(ref.read(settingsStoreProvider));
      if (_disposed) return;
      state = state.copyWith(shuffle: settings.shuffleDefault, repeat: settings.repeatMode);
    } catch (_) {
      // Keep built-in defaults.
    }
  }

  /// Fire-and-forget a player call without letting an error escape.
  void _safe(Future<void>? call) {
    if (call != null) unawaited(call.catchError((Object _) {}));
  }

  // --- starting playback ---------------------------------------------------

  /// Replaces the queue with [tracks] and starts at [startIndex] (FR-HOME-02,
  /// FR-SEARCH-04). With shuffle on, the chosen track plays first and the rest
  /// follow in random order.
  Future<void> playTracks(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    final start = min(max(startIndex, 0), tracks.length - 1);
    var queue = List<Track>.of(tracks);
    var index = start;
    if (state.shuffle) {
      final others = List<Track>.of(tracks)..removeAt(start);
      others.shuffle(ref.read(randomProvider));
      queue = [tracks[start], ...others];
      index = 0;
    }
    state = state.copyWith(queue: queue, clearError: true);
    await _play(index);
  }

  Future<void> _play(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    final token = ++_token;
    final track = state.queue[index];
    _stopTimer();
    _loadTimeout?.cancel();
    state = state.copyWith(
      currentIndex: index,
      position: Duration.zero,
      isLoading: true,
      isPlaying: false,
      clearError: true,
      // A retry gets a fresh chance: forget an earlier (possibly temporary) failure.
      unavailableKeys: {...state.unavailableKeys}..remove(track.key),
    );

    final PlayableSource source;
    try {
      source = await _providerFor(track).resolvePlayableSource(track.providerId);
    } on AppException catch (e) {
      if (_disposed || token != _token) return;
      _fail(track, e.userMessage, unavailable: e is ProviderUnavailableException);
      return;
    } catch (_) {
      if (_disposed || token != _token) return;
      _fail(track, 'Playback failed. Press play to try again.');
      return;
    }
    if (_disposed || token != _token) return;

    final videoId = source.youtubeVideoId;
    final streamUri = source.uri;
    if (videoId == null && streamUri == null) {
      // Simulated playback (sample catalog).
      _detachExternal();
      state = state.copyWith(isLoading: false, isPlaying: true);
      _startTimer();
    } else {
      try {
        // YouTube plays in its official player; plain audio streams play in CLICK's own audio player.
        final player = _attachExternal(ref.read(videoId != null ? externalPlayerProvider : audioPlayerProvider));
        await player.load(
          videoId ?? streamUri!.toString(),
          info: MediaInfo(
            id: track.key,
            title: track.title,
            artist: track.artistName,
            album: track.albumTitle,
            artworkUrl: track.artworkUrl,
          ),
        );
      } catch (_) {
        if (_disposed || token != _token) return;
        _fail(track, 'Could not start playback. Press play to try again.');
        return;
      }
      if (_disposed || token != _token) return;
      // isLoading stays true until the player reports "playing".
      _loadTimeout = Timer(externalLoadTimeout, () {
        if (_disposed || token != _token || !state.isLoading) return;
        _fail(track, 'Playback did not start. Check your connection and press play to retry.');
      });
    }
    unawaited(ref.read(libraryProvider.notifier).recordPlay(track));
  }

  void _fail(Track track, String message, {bool unavailable = false}) {
    _stopTimer();
    _loadTimeout?.cancel();
    state = state.copyWith(
      isLoading: false,
      isPlaying: false,
      errorMessage: message,
      unavailableKeys: unavailable ? {...state.unavailableKeys, track.key} : null,
    );
  }

  // --- external player -----------------------------------------------------

  /// A track plays with the provider that owns it, even if the user has since
  /// switched the Home/Search source.
  MusicProvider _providerFor(Track track) {
    final selected = ref.read(musicProviderProvider);
    if (selected.name == track.providerName) return selected;
    for (final p in ref.read(musicProvidersProvider)) {
      if (p.name == track.providerName) return p;
    }
    return selected;
  }

  ExternalPlayer _attachExternal(ExternalPlayer player) {
    if (!identical(player, _external)) {
      _safe(_external?.pause()); // switching engines: silence the previous one
      _externalSub?.cancel();
      _external = player;
      _externalSub = player.events.listen(_onExternalEvent);
    }
    return player;
  }

  void _detachExternal() {
    _safe(_external?.pause());
    _externalSub?.cancel();
    _externalSub = null;
    _external = null;
  }

  void _onExternalEvent(ExternalPlayerEvent event) {
    final track = state.current;
    if (_disposed || _external == null || track == null) return;
    switch (event) {
      case ExternalStateChanged(:final playerState):
        switch (playerState) {
          case ExternalPlayerState.playing:
            _loadTimeout?.cancel();
            state = state.copyWith(isLoading: false, isPlaying: true, clearError: true);
          case ExternalPlayerState.paused:
            if (!state.isLoading) state = state.copyWith(isPlaying: false);
          case ExternalPlayerState.buffering:
            break; // the spinner is only for the initial load
          case ExternalPlayerState.ended:
            if (!state.isLoading) unawaited(_onTrackCompleted());
        }
      case ExternalPositionChanged(:final position):
        if (!state.isLoading && state.isPlaying) state = state.copyWith(position: position);
      case ExternalPlayerError(:final message, :final unavailable):
        _fail(track, message, unavailable: unavailable);
    }
  }

  // --- transport controls --------------------------------------------------

  /// FR-PLAY-01. After a failure, pressing play retries the current track.
  void togglePlayPause() {
    final index = state.currentIndex;
    if (index == null || state.isLoading) return;
    if (state.isPlaying) {
      _stopTimer();
      _safe(_external?.pause());
      state = state.copyWith(isPlaying: false);
    } else if (state.errorMessage != null) {
      unawaited(_play(index));
    } else {
      state = state.copyWith(isPlaying: true);
      final external = _external;
      if (external != null) {
        _safe(external.play());
      } else {
        _startTimer();
      }
    }
  }

  /// FR-PLAY-03.
  void seek(Duration to) {
    if (state.current == null) return;
    final total = state.duration;
    final clamped = to < Duration.zero ? Duration.zero : (to > total ? total : to);
    state = state.copyWith(position: clamped);
    _safe(_external?.seekTo(clamped));
  }

  /// FR-PLAY-04. On the last track with repeat off, this does nothing.
  Future<void> next() async {
    final index = state.currentIndex;
    if (index == null) return;
    final target = _nextIndex(index);
    if (target != null) await _play(target);
  }

  /// FR-PLAY-04. Restarts the track if more than 3 seconds in.
  Future<void> previous() async {
    final index = state.currentIndex;
    if (index == null) return;
    if (state.position > restartThreshold) {
      seek(Duration.zero);
    } else if (index > 0) {
      await _play(index - 1);
    } else if (state.repeat == RepeatMode.all && state.queue.length > 1) {
      await _play(state.queue.length - 1);
    } else {
      seek(Duration.zero);
    }
  }

  /// Jumps to a queue position (used by the Queue screen).
  Future<void> skipTo(int index) => _play(index);

  int? _nextIndex(int index) {
    if (index + 1 < state.queue.length) return index + 1;
    if (state.repeat == RepeatMode.all && state.queue.isNotEmpty) return 0;
    return null;
  }

  // --- shuffle / repeat ----------------------------------------------------

  /// FR-PLAY-05. Turning shuffle on randomizes the upcoming tracks; turning it
  /// off keeps the current order.
  void toggleShuffle() {
    final on = !state.shuffle;
    var queue = state.queue;
    final index = state.currentIndex;
    if (on && index != null && index + 1 < queue.length) {
      final upcoming = queue.sublist(index + 1)..shuffle(ref.read(randomProvider));
      queue = [...queue.sublist(0, index + 1), ...upcoming];
    }
    state = state.copyWith(shuffle: on, queue: queue);
  }

  void cycleRepeat() => state = state.copyWith(repeat: state.repeat.next);

  // --- queue (FR-QUEUE-01..04) ---------------------------------------------

  /// Adds to the end of the queue. If nothing is loaded, the track starts playing.
  void addToQueue(Track track) {
    if (state.currentIndex == null || state.queue.isEmpty) {
      unawaited(playTracks([track]));
      return;
    }
    state = state.copyWith(queue: [...state.queue, track]);
  }

  /// The currently playing track cannot be removed.
  void removeFromQueue(int index) {
    final current = state.currentIndex;
    if (index < 0 || index >= state.queue.length || index == current) return;
    final queue = List<Track>.of(state.queue)..removeAt(index);
    state = state.copyWith(
      queue: queue,
      currentIndex: (current != null && index < current) ? current - 1 : current,
    );
  }

  /// Moves an upcoming track (FR-QUEUE-05). [from] and [to] are queue indexes
  /// (to = final position); the current track and earlier tracks cannot move,
  /// and nothing can be moved in front of the current track.
  void moveInQueue(int from, int to) {
    final current = state.currentIndex;
    final length = state.queue.length;
    if (current == null || from <= current || to <= current) return;
    if (from >= length || to >= length || from == to) return;
    final queue = List<Track>.of(state.queue);
    queue.insert(to, queue.removeAt(from));
    state = state.copyWith(queue: queue);
  }

  /// Removes every upcoming track; the current track keeps playing.
  void clearUpcoming() {
    final current = state.currentIndex;
    if (current == null) return;
    state = state.copyWith(queue: state.queue.sublist(0, current + 1));
  }

  // --- simulated clock -----------------------------------------------------

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(tickInterval, (_) => tick(tickInterval));
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// Advances the simulated position (no-op when an external player is in
  /// charge). Public so tests can drive time.
  @visibleForTesting
  void tick(Duration elapsed) {
    if (_external != null || !state.isPlaying || state.isLoading) return;
    final nextPosition = state.position + elapsed;
    final total = state.duration;
    if (total > Duration.zero && nextPosition >= total) {
      unawaited(_onTrackCompleted());
    } else {
      state = state.copyWith(position: nextPosition);
    }
  }

  Future<void> _onTrackCompleted() async {
    final index = state.currentIndex;
    if (index == null) return;
    if (state.repeat == RepeatMode.one) {
      state = state.copyWith(position: Duration.zero);
      final external = _external;
      if (external != null) {
        _safe(external.seekTo(Duration.zero));
        _safe(external.play());
      }
      return;
    }
    final target = _nextIndex(index);
    if (target == null) {
      _stopTimer();
      state = state.copyWith(isPlaying: false, position: Duration.zero);
    } else {
      await _play(target);
    }
  }
}

final playbackProvider = NotifierProvider<PlaybackController, PlaybackState>(PlaybackController.new);
