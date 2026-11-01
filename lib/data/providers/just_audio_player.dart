import 'dart:async';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../../domain/repositories/external_player.dart';

/// Plays plain audio streams (e.g. Jamendo) with no video. Adapts just_audio to
/// the [ExternalPlayer] port so [PlaybackController] stays the only owner of
/// queue and state. [load] takes the stream URL.
class JustAudioPlayer implements ExternalPlayer {
  JustAudioPlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _subs.add(_player.playerStateStream.listen(_onPlayerState, onError: _onError));
    _subs.add(_player.positionStream.listen(_onPosition, onError: _onError));
  }

  static const _positionStep = Duration(milliseconds: 500);

  final AudioPlayer _player;
  final StreamController<ExternalPlayerEvent> _events = StreamController<ExternalPlayerEvent>.broadcast();
  final List<StreamSubscription<Object?>> _subs = [];

  ExternalPlayerState? _lastState;
  Duration _lastPosition = Duration.zero;
  bool _disposed = false;

  @override
  Stream<ExternalPlayerEvent> get events => _events.stream;

  @override
  Future<void> load(String sourceId, {MediaInfo? info}) async {
    _lastState = null;
    _lastPosition = Duration.zero;
    await _player.stop();
    // The MediaItem tag feeds the notification and lock screen (just_audio_background).
    // It is required once JustAudioBackground.init has run, so it is always set.
    final art = info?.artworkUrl;
    final item = MediaItem(
      id: info?.id ?? sourceId,
      title: info?.title ?? 'CLICK',
      artist: info?.artist,
      album: info?.album,
      artUri: art == null ? null : Uri.tryParse(art),
    );
    // throws PlayerException if the stream cannot be opened
    await _player.setAudioSource(AudioSource.uri(Uri.parse(sourceId), tag: item));
    // play() only completes when playback stops, so it is not awaited.
    unawaited(_player.play().catchError((Object e) => _onError(e)));
  }

  @override
  Future<void> play() async {
    unawaited(_player.play().catchError((Object e) => _onError(e)));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _lastState = null;
    await _player.stop(); // also dismisses the media notification
  }

  @override
  Future<void> seekTo(Duration position) => _player.seek(position);

  void _onPlayerState(PlayerState state) {
    final ExternalPlayerState? mapped = switch (state.processingState) {
      ProcessingState.completed => ExternalPlayerState.ended,
      ProcessingState.loading || ProcessingState.buffering => ExternalPlayerState.buffering,
      ProcessingState.ready => state.playing ? ExternalPlayerState.playing : ExternalPlayerState.paused,
      ProcessingState.idle => null, // before load or after stop: nothing to report
    };
    if (mapped == null || mapped == _lastState) return;
    _lastState = mapped;
    _emit(ExternalStateChanged(mapped));
  }

  void _onPosition(Duration position) {
    final delta = (position - _lastPosition).abs();
    if (delta < _positionStep) return;
    _lastPosition = position;
    _emit(ExternalPositionChanged(position));
  }

  void _onError(Object error) {
    _emit(const ExternalPlayerError('This track could not be streamed. Tap it to try again.'));
  }

  void _emit(ExternalPlayerEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final sub in _subs) {
      await sub.cancel();
    }
    await _player.dispose();
    await _events.close();
  }
}
