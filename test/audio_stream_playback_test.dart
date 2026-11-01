import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/external_player.dart';
import 'package:click/domain/repositories/music_provider.dart';
import 'package:click/features/player/playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_external_player.dart';
import 'support/test_container.dart';

void main() {
  final tracks = SampleMusicProvider.catalog.take(3).toList();

  late FakeExternalPlayer youtube;
  late FakeExternalPlayer audio;
  late ProviderContainer container;

  PlaybackController controller() => container.read(playbackProvider.notifier);
  PlaybackState state() => container.read(playbackProvider);

  Future<void> start(MusicProvider provider) async {
    youtube = FakeExternalPlayer();
    audio = FakeExternalPlayer();
    container = makeContainer(provider: provider, externalPlayer: youtube, audioPlayer: audio);
    container.listen(playbackProvider, (_, __) {});
    await pumpEventQueue();
  }

  tearDown(() async {
    container.dispose();
    await youtube.dispose();
    await audio.dispose();
  });

  test('a stream source plays in the audio player, never the YouTube player', () async {
    await start(StreamSourceProvider());
    await controller().playTracks(tracks);
    expect(audio.loaded, ['https://audio.example/${tracks.first.providerId}.mp3']);
    expect(youtube.loaded, isEmpty);
    expect(state().isLoading, isTrue);

    audio.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    expect(state().isPlaying, isTrue);
    expect(state().isLoading, isFalse);
  });

  test('pause, seek and track end are driven through the audio player', () async {
    await start(StreamSourceProvider());
    await controller().playTracks(tracks);
    audio.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();

    controller().togglePlayPause();
    controller().seek(const Duration(seconds: 15));
    await pumpEventQueue();
    expect(audio.calls, ['pause', 'seek:15']);

    controller().togglePlayPause();
    audio.emit(const ExternalStateChanged(ExternalPlayerState.ended));
    await pumpEventQueue();
    expect(state().current, tracks[1]);
    expect(audio.loaded.length, 2);
  });

  test('a stream failure marks the track unavailable and can be retried', () async {
    await start(StreamSourceProvider());
    await controller().playTracks(tracks);
    audio.emit(const ExternalPlayerError('This track could not be streamed.'));
    await pumpEventQueue();
    expect(state().errorMessage, 'This track could not be streamed.');
    expect(state().unavailableKeys, contains(tracks.first.key));

    await controller().playTracks(tracks);
    expect(state().unavailableKeys, isNot(contains(tracks.first.key)));
    expect(audio.loaded.length, 2);
  });

  test('moving from a YouTube track to a stream track pauses the YouTube player', () async {
    await start(_MixedProvider(youtubeId: tracks[0].providerId));
    await controller().playTracks(tracks);
    youtube.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    expect(youtube.loaded, [tracks[0].providerId]);

    await controller().next();
    expect(youtube.calls, contains('pause'));
    expect(audio.loaded, ['https://audio.example/${tracks[1].providerId}.mp3']);

    // Late events from the silenced YouTube player must not affect the audio track.
    youtube.emit(const ExternalStateChanged(ExternalPlayerState.ended));
    await pumpEventQueue();
    expect(state().current, tracks[1]);
  });
}

/// Resolves one track to YouTube and every other track to a plain audio stream.
class _MixedProvider extends StreamSourceProvider {
  _MixedProvider({required this.youtubeId});
  final String youtubeId;

  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) =>
      trackId == youtubeId ? Future.value(PlayableSource.youtube(trackId)) : super.resolvePlayableSource(trackId);
}
