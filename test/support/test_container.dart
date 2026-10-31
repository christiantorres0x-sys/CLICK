import 'dart:math';

import 'package:click/app/providers.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/repositories/external_player.dart';
import 'package:click/domain/repositories/music_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_memory_library.dart';

/// Overrides shared by controller and widget tests: no latency, fixed random
/// seed, in-memory storage.
List<Override> testOverrides({
  InMemoryLibrary? library,
  MusicProvider? provider,
  ExternalPlayer? externalPlayer,
  int seed = 1,
}) {
  final lib = library ?? InMemoryLibrary();
  return [
    libraryRepositoryProvider.overrideWithValue(lib),
    settingsStoreProvider.overrideWithValue(lib),
    musicProviderProvider.overrideWithValue(provider ?? SampleMusicProvider(latency: Duration.zero)),
    randomProvider.overrideWithValue(Random(seed)),
    if (externalPlayer != null) externalPlayerProvider.overrideWithValue(externalPlayer),
  ];
}

ProviderContainer makeContainer({
  InMemoryLibrary? library,
  MusicProvider? provider,
  ExternalPlayer? externalPlayer,
  int seed = 1,
}) {
  return ProviderContainer(
    overrides: testOverrides(
      library: library,
      provider: provider,
      externalPlayer: externalPlayer,
      seed: seed,
    ),
  );
}
