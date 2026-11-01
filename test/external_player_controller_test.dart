import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/external_player.dart';
import 'package:click/features/player/playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_external_player.dart';
import 'support/test_container.dart';

void main() {
  final tracks = SampleMusicProvider.catalog.take(3).toList();

  late FakeExternalPlayer player;
  late ProviderContainer container;

  PlaybackController controller() => container.read(playbackProvider.notifier);
  PlaybackState state() => container.read(playbackProvider);

  setUp(() async {
    player = FakeExternalPlayer();
    container = makeContainer(provider: ExternalSourceProvider(), externalPlayer: player);
    container.listen(playbackProvider, (_, __) {});
    await pumpEventQueue();
  });

  tearDown(() async {
    container.dispose();
    await player.dispose();
  });

  test('stop tells the engine to stop and ignores its late events', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();

    controller().stop();
    await pumpEventQueue();
    expect(player.calls, contains('stop'));
    expect(state().current, isNull);

    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    expect(state().isPlaying, isFalse);
    expect(state().current, isNull);
  });

  test('loads the video id and waits for the player before showing "playing"', () async {
    await controller().playTracks(tracks);
    expect(player.loaded, [tracks.first.providerId]);
    expect(state().isLoading, isTrue);
    expect(state().isPlaying, isFalse);

    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    expect(state().isLoading, isFalse);
    expect(state().isPlaying, isTrue);
  });

  test('the simulated clock does not run while an external player is in charge', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    controller().tick(const Duration(seconds: 30));
    expect(state().position, Duration.zero);
  });

  test('position events update the position while playing', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    player.emit(const ExternalPositionChanged(Duration(seconds: 42)));
    await pumpEventQueue();
    expect(state().position, const Duration(seconds: 42));
  });

  test('pause, play and seek are forwarded to the player', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();

    controller().togglePlayPause();
    expect(state().isPlaying, isFalse);
    controller().togglePlayPause();
    expect(state().isPlaying, isTrue);
    controller().seek(const Duration(seconds: 20));
    await pumpEventQueue();
    expect(player.calls, ['pause', 'play', 'seek:20']);
  });

  test('an ended event advances to the next track', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    player.emit(const ExternalStateChanged(ExternalPlayerState.ended));
    await pumpEventQueue();
    expect(state().current, tracks[1]);
    expect(player.loaded, [tracks[0].providerId, tracks[1].providerId]);
  });

  test('a player error marks the track unavailable without crashing (FR-PLAY-06)', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalPlayerError('Embedding is disabled for this video.'));
    await pumpEventQueue();
    expect(state().isLoading, isFalse);
    expect(state().isPlaying, isFalse);
    expect(state().errorMessage, 'Embedding is disabled for this video.');
    expect(state().unavailableKeys, contains(tracks.first.key));
  });

  test('tapping a failed track again retries it and clears the unavailable flag', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalPlayerError('boom'));
    await pumpEventQueue();
    expect(state().unavailableKeys, contains(tracks.first.key));

    await controller().playTracks(tracks); // the user taps the row again
    expect(state().unavailableKeys, isNot(contains(tracks.first.key)));
    expect(state().errorMessage, isNull);

    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    expect(state().isPlaying, isTrue);
  });

  test('pressing play after an error reloads the track', () async {
    await controller().playTracks(tracks);
    player.emit(const ExternalPlayerError('boom'));
    await pumpEventQueue();
    controller().togglePlayPause();
    await pumpEventQueue();
    expect(player.loaded, [tracks.first.providerId, tracks.first.providerId]);
    expect(state().errorMessage, isNull);
  });

  test('repeat one seeks to the start and plays again when the video ends', () async {
    controller().cycleRepeat();
    controller().cycleRepeat();
    await controller().playTracks(tracks);
    player.emit(const ExternalStateChanged(ExternalPlayerState.playing));
    await pumpEventQueue();
    player.emit(const ExternalStateChanged(ExternalPlayerState.ended));
    await pumpEventQueue();
    expect(state().current, tracks.first);
    expect(player.calls, containsAll(['seek:0', 'play']));
  });
}
