import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/sample_music_provider.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/music_provider.dart';

/// The single active music provider (SRS FR-PROV-01). Swap the adapter here
/// once a real provider passes the Phase 0 gate.
final musicProviderProvider = Provider<MusicProvider>((ref) => SampleMusicProvider());

/// Overridden in main() with the opened SQLite repository.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => throw UnimplementedError('libraryRepositoryProvider must be overridden (see main.dart).'),
);

/// Overridden in main() with the opened SQLite repository.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider must be overridden (see main.dart).'),
);

final randomProvider = Provider<Random>((ref) => Random());
