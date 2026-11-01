import 'package:click/app/providers.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/music_provider.dart';
import 'package:click/features/player/playback_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_external_player.dart';
import 'support/in_memory_library.dart';
import 'support/test_container.dart';

class _Named extends SampleMusicProvider {
  _Named(this._name, {this.source}) : super(latency: Duration.zero);
  final String _name;
  final PlayableSource? source;

  @override
  String get name => _name;

  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async => source ?? const PlayableSource.simulated();
}

void main() {
  test('the saved choice selects the provider, and unknown names fall back to the first', () async {
    final library = InMemoryLibrary();
    final a = _Named('A');
    final b = _Named('B');
    final container = ProviderContainer(overrides: [
      libraryRepositoryProvider.overrideWithValue(library),
      settingsStoreProvider.overrideWithValue(library),
      musicProvidersProvider.overrideWithValue([a, b]),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedSourceProvider, (_, __) {});

    expect(container.read(musicProviderProvider), same(a));
    await container.read(selectedSourceProvider.notifier).select('B');
    expect(container.read(musicProviderProvider), same(b));
    expect(await library.getSetting(SelectedSourceNotifier.settingKey), 'B');

    await container.read(selectedSourceProvider.notifier).select('Gone');
    expect(container.read(musicProviderProvider), same(a));
  });

  test('a saved choice is restored on startup', () async {
    final library = InMemoryLibrary();
    await library.setSetting(SelectedSourceNotifier.settingKey, 'B');
    final container = ProviderContainer(overrides: [
      libraryRepositoryProvider.overrideWithValue(library),
      settingsStoreProvider.overrideWithValue(library),
      musicProvidersProvider.overrideWithValue([_Named('A'), _Named('B')]),
    ]);
    addTearDown(container.dispose);
    container.listen(selectedSourceProvider, (_, __) {});
    await pumpEventQueue();
    expect(container.read(musicProviderProvider).name, 'B');
  });

  test('a queued track plays with its own provider after the source is switched', () async {
    final youtube = FakeExternalPlayer();
    final audio = FakeExternalPlayer();
    addTearDown(youtube.dispose);
    addTearDown(audio.dispose);

    // Tracks below carry providerName 'Sample...'; 'Audio' is the selected source but must not resolve them.
    final owner = SampleMusicProvider(latency: Duration.zero);
    final selected = _Named('Audio', source: PlayableSource.stream(Uri.parse('https://x.example/a.mp3')));
    final container = makeContainer(
      provider: selected,
      providers: [selected, owner],
      externalPlayer: youtube,
      audioPlayer: audio,
    );
    addTearDown(container.dispose);
    container.listen(playbackProvider, (_, __) {});
    await pumpEventQueue();

    final tracks = SampleMusicProvider.catalog.take(2).toList();
    await container.read(playbackProvider.notifier).playTracks(tracks);

    // The owner (sample) is simulated: nothing goes to either engine.
    expect(audio.loaded, isEmpty);
    expect(youtube.loaded, isEmpty);
    expect(container.read(playbackProvider).isPlaying, isTrue);
  });
}
