import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/entities/repeat_mode.dart';
import 'package:click/domain/entities/track.dart';
import 'package:click/features/player/playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/in_memory_library.dart';
import 'support/test_container.dart';

void main() {
  final tracks = SampleMusicProvider.catalog.take(4).toList();

  late InMemoryLibrary library;
  late ProviderContainer container;

  PlaybackController controller() => container.read(playbackProvider.notifier);
  PlaybackState state() => container.read(playbackProvider);

  setUp(() async {
    library = InMemoryLibrary();
    container = makeContainer(library: library);
    // Keep the notifier alive for the whole test.
    container.listen(playbackProvider, (_, __) {});
    // Let the startup "apply saved defaults" step finish before each test.
    await pumpEventQueue();
  });

  tearDown(() => container.dispose());

  test('playTracks starts the chosen track (FR-HOME-02, FR-SEARCH-04)', () async {
    await controller().playTracks(tracks, startIndex: 2);
    expect(state().current, tracks[2]);
    expect(state().isPlaying, isTrue);
    expect(state().isLoading, isFalse);
    expect(state().position, Duration.zero);
    expect(state().queue, tracks);
  });

  test('playing a track records it in listening history', () async {
    await controller().playTracks(tracks);
    await pumpEventQueue();
    expect(await library.recentlyPlayed(), [tracks.first]);
  });

  test('play/pause toggles (FR-PLAY-01)', () async {
    await controller().playTracks(tracks);
    controller().togglePlayPause();
    expect(state().isPlaying, isFalse);
    controller().togglePlayPause();
    expect(state().isPlaying, isTrue);
  });

  test('tick advances position only while playing (FR-PLAY-02)', () async {
    await controller().playTracks(tracks);
    controller().tick(const Duration(seconds: 10));
    expect(state().position, const Duration(seconds: 10));
    controller().togglePlayPause();
    controller().tick(const Duration(seconds: 10));
    expect(state().position, const Duration(seconds: 10));
  });

  test('seek clamps to the track length (FR-PLAY-03)', () async {
    await controller().playTracks(tracks);
    controller().seek(const Duration(seconds: 30));
    expect(state().position, const Duration(seconds: 30));
    controller().seek(const Duration(hours: 1));
    expect(state().position, tracks.first.duration);
    controller().seek(const Duration(seconds: -5));
    expect(state().position, Duration.zero);
  });

  test('next and previous move through the queue (FR-PLAY-04)', () async {
    await controller().playTracks(tracks);
    await controller().next();
    expect(state().current, tracks[1]);
    await controller().previous();
    expect(state().current, tracks[0]);
  });

  test('previous restarts the track when more than 3 seconds in', () async {
    await controller().playTracks(tracks, startIndex: 1);
    controller().tick(const Duration(seconds: 10));
    await controller().previous();
    expect(state().current, tracks[1]);
    expect(state().position, Duration.zero);
  });

  test('next on the last track with repeat off does nothing', () async {
    await controller().playTracks(tracks, startIndex: 3);
    await controller().next();
    expect(state().current, tracks[3]);
  });

  test('repeat all wraps around in both directions (FR-PLAY-05)', () async {
    controller().cycleRepeat(); // all
    expect(state().repeat, RepeatMode.all);
    await controller().playTracks(tracks, startIndex: 3);
    await controller().next();
    expect(state().current, tracks[0]);
    await controller().previous();
    expect(state().current, tracks[3]);
  });

  test('track completion advances to the next track', () async {
    await controller().playTracks(tracks);
    controller().tick(tracks.first.duration!);
    await pumpEventQueue();
    expect(state().current, tracks[1]);
    expect(state().isPlaying, isTrue);
  });

  test('repeat one replays the same track on completion', () async {
    controller().cycleRepeat();
    controller().cycleRepeat(); // one
    await controller().playTracks(tracks);
    controller().tick(tracks.first.duration!);
    await pumpEventQueue();
    expect(state().current, tracks.first);
    expect(state().position, Duration.zero);
    expect(state().isPlaying, isTrue);
  });

  test('finishing the last track with repeat off stops playback', () async {
    await controller().playTracks(tracks, startIndex: 3);
    controller().tick(tracks[3].duration!);
    await pumpEventQueue();
    expect(state().isPlaying, isFalse);
    expect(state().position, Duration.zero);
    expect(state().current, tracks[3]);
  });

  test('shuffle keeps the current track and permutes the upcoming ones', () async {
    await controller().playTracks(tracks);
    controller().toggleShuffle();
    expect(state().shuffle, isTrue);
    expect(state().current, tracks.first);
    expect(state().queue.first, tracks.first);
    expect(state().queue.toSet(), tracks.toSet());
    expect(state().queue, hasLength(tracks.length));
  });

  test('with shuffle on, playTracks starts at the chosen track', () async {
    controller().toggleShuffle();
    await controller().playTracks(tracks, startIndex: 2);
    expect(state().current, tracks[2]);
    expect(state().currentIndex, 0);
    expect(state().queue.toSet(), tracks.toSet());
  });

  group('queue (FR-QUEUE-01..04)', () {
    test('addToQueue appends; on an empty queue it starts playback', () async {
      controller().addToQueue(tracks[0]);
      await pumpEventQueue();
      expect(state().current, tracks[0]);
      controller().addToQueue(tracks[1]);
      expect(state().upNext, [tracks[1]]);
    });

    test('removeFromQueue removes upcoming tracks but never the current one', () async {
      await controller().playTracks(tracks);
      controller().removeFromQueue(0); // current: ignored
      expect(state().queue, hasLength(4));
      controller().removeFromQueue(2);
      expect(state().queue, [tracks[0], tracks[1], tracks[3]]);
      expect(state().current, tracks[0]);
    });

    test('removing a track before the current one keeps the current track', () async {
      await controller().playTracks(tracks, startIndex: 2);
      controller().removeFromQueue(0);
      expect(state().current, tracks[2]);
      expect(state().currentIndex, 1);
    });

    test('clearUpcoming keeps only the current track', () async {
      await controller().playTracks(tracks, startIndex: 1);
      controller().clearUpcoming();
      expect(state().queue, [tracks[0], tracks[1]]);
      expect(state().upNext, isEmpty);
      expect(state().current, tracks[1]);
    });

    test('moveInQueue reorders upcoming tracks only and keeps the current track playing (FR-QUEUE-05)', () async {
      await controller().playTracks(tracks); // current = 0
      controller().moveInQueue(3, 1);
      expect(state().queue.take(4).toList(), [tracks[0], tracks[3], tracks[1], tracks[2]]);
      expect(state().currentIndex, 0);

      controller().moveInQueue(0, 2); // current track cannot move
      controller().moveInQueue(2, 0); // nothing goes in front of the current track
      controller().moveInQueue(1, 99); // out of range
      expect(state().queue.take(4).toList(), [tracks[0], tracks[3], tracks[1], tracks[2]]);
    });

    test('skipTo jumps to a queue position', () async {
      await controller().playTracks(tracks);
      await controller().skipTo(3);
      expect(state().current, tracks[3]);
    });
  });

  group('errors (FR-PLAY-06, FR-LIB-07)', () {
    const retired = Track(
      providerName: SampleMusicProvider.providerName,
      providerId: 'retired-999',
      title: 'Retired',
      artistName: 'Nobody',
      durationMs: 100000,
    );

    test('an unavailable track sets an error instead of crashing', () async {
      await controller().playTracks([retired]);
      expect(state().isPlaying, isFalse);
      expect(state().isLoading, isFalse);
      expect(state().errorMessage, isNotNull);
      expect(state().unavailableKeys, contains(retired.key));
    });

    test('playing a good track afterwards clears the error', () async {
      await controller().playTracks([retired]);
      await controller().playTracks(tracks);
      expect(state().errorMessage, isNull);
      expect(state().isPlaying, isTrue);
    });
  });

  test('saved shuffle/repeat defaults are applied at startup', () async {
    final lib = InMemoryLibrary();
    await lib.setSetting('shuffle_default', 'true');
    await lib.setSetting('repeat_mode', 'all');
    final c = makeContainer(library: lib);
    addTearDown(c.dispose);
    c.listen(playbackProvider, (_, __) {});
    await pumpEventQueue();
    expect(c.read(playbackProvider).shuffle, isTrue);
    expect(c.read(playbackProvider).repeat, RepeatMode.all);
  });
}
