import 'dart:math';

import 'package:click/app/providers.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/music_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_memory_library.dart';

/// Overrides shared by controller and widget tests: no latency, fixed random
/// seed, in-memory storage.
List<Override> testOverrides({InMemoryLibrary? library, MusicProvider? provider, int seed = 1}) {
  final lib = library ?? InMemoryLibrary();
  return [
    libraryRepositoryProvider.overrideWithValue(lib),
    settingsStoreProvider.overrideWithValue(lib),
    musicProviderProvider.overrideWithValue(provider ?? SampleMusicProvider(latency: Duration.zero)),
    randomProvider.overrideWithValue(Random(seed)),
  ];
}

ProviderContainer makeContainer({InMemoryLibrary? library, MusicProvider? provider, int seed = 1}) {
  final container = ProviderContainer(
    overrides: testOverrides(library: library, provider: provider, seed: seed),
  );
  return container;
}
