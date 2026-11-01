import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../domain/repositories/external_player.dart';

/// [ExternalPlayer] backed by the official YouTube IFrame player.
///
/// The player widget (see YoutubeDockHost) must stay visible while playing:
/// YouTube requires an embedded viewport of at least 200x200 px and forbids
/// covering it. CLICK never extracts or separates audio.
///
/// This file and youtube_dock.dart are the only code that touches the
/// youtube_player_iframe package, so API differences between package versions
/// are confined here.
class YoutubeIframePlayer extends ChangeNotifier implements ExternalPlayer {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _valueSub;
  StreamSubscription<YoutubeVideoState>? _positionSub;
  final StreamController<ExternalPlayerEvent> _events = StreamController<ExternalPlayerEvent>.broadcast();
  bool _disposed = false;

  /// Null until the first track is loaded; listen for changes with [addListener].
  YoutubePlayerController? get controller => _controller;

  @override
  Stream<ExternalPlayerEvent> get events => _events.stream;

  @override
  Future<void> load(String sourceId, {MediaInfo? info}) async {
    final existing = _controller;
    if (existing != null) {
      await existing.loadVideoById(videoId: sourceId);
      return;
    }
    final created = YoutubePlayerController.fromVideoId(
      videoId: sourceId,
      autoPlay: true,
      params: const YoutubePlayerParams(
  showControls: true,
  showFullscreenButton: false,
  strictRelatedVideos: true,
  origin: 'https://www.youtube-nocookie.com',
),
    );
    _controller = created;
    _valueSub = created.stream.listen(_onValue);
    _positionSub = created.videoStateStream.listen((s) => _emit(ExternalPositionChanged(s.position)));
    notifyListeners();
  }

  @override
  Future<void> play() async => _controller?.playVideo();

  @override
  Future<void> pause() async => _controller?.pauseVideo();

  @override
  Future<void> stop() async => _controller?.stopVideo();

  @override
  Future<void> seekTo(Duration position) async {
    await _controller?.seekTo(seconds: position.inMilliseconds / 1000.0, allowSeekAhead: true);
  }

  void _onValue(YoutubePlayerValue value) {
    if (value.hasError) {
      _emit(ExternalPlayerError('YouTube could not play this video (${value.error}). Tap it to try again.'));
      return;
    }
    switch (value.playerState) {
      case PlayerState.playing:
        _emit(const ExternalStateChanged(ExternalPlayerState.playing));
      case PlayerState.paused:
        _emit(const ExternalStateChanged(ExternalPlayerState.paused));
      case PlayerState.buffering:
        _emit(const ExternalStateChanged(ExternalPlayerState.buffering));
      case PlayerState.ended:
        _emit(const ExternalStateChanged(ExternalPlayerState.ended));
      default:
        break; // unknown / unStarted / cued carry no useful information
    }
  }

  void _emit(ExternalPlayerEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  @override
  void dispose() {
    _disposed = true;
    _valueSub?.cancel();
    _positionSub?.cancel();
    _controller?.close();
    _events.close();
    super.dispose();
  }
}
