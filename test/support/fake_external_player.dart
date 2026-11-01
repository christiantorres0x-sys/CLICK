import 'dart:async';

import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/external_player.dart';
import 'package:click/domain/repositories/music_provider.dart';

/// Records calls and lets a test push player events.
class FakeExternalPlayer implements ExternalPlayer {
  final StreamController<ExternalPlayerEvent> _controller = StreamController<ExternalPlayerEvent>.broadcast();
  final List<String> loaded = [];
  final List<String> calls = [];
  final List<MediaInfo?> infos = [];

  @override
  Stream<ExternalPlayerEvent> get events => _controller.stream;

  void emit(ExternalPlayerEvent event) => _controller.add(event);

  @override
  Future<void> load(String sourceId, {MediaInfo? info}) async {
    loaded.add(sourceId);
    infos.add(info);
  }

  @override
  Future<void> play() async => calls.add('play');

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> seekTo(Duration position) async => calls.add('seek:${position.inSeconds}');

  Future<void> dispose() => _controller.close();
}

/// A provider whose tracks play through an [ExternalPlayer], like YouTube.
class ExternalSourceProvider extends SampleMusicProvider {
  ExternalSourceProvider() : super(latency: Duration.zero);

  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async => PlayableSource.youtube(trackId);
}

/// A provider whose tracks are plain audio streams (like Jamendo): no video.
class StreamSourceProvider extends SampleMusicProvider {
  StreamSourceProvider() : super(latency: Duration.zero);

  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async =>
      PlayableSource.stream(Uri.parse('https://audio.example/$trackId.mp3'));
}
