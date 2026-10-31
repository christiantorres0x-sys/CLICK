import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/sample_music_provider.dart';
import '../data/providers/youtube_iframe_player.dart';
import '../data/providers/youtube_music_provider.dart';
import '../domain/repositories/external_player.dart';
import '../domain/repositories/library_repository.dart';
import '../domain/repositories/music_provider.dart';

// Build-time configuration, passed with --dart-define-from-file=secrets.json
// (never committed: see .gitignore and FR-PROV-05).
const String _youtubeApiKey = String.fromEnvironment('YOUTUBE_API_KEY');
const String _youtubeRegion = String.fromEnvironment('YOUTUBE_REGION', defaultValue: 'PH');
const String _androidPackage = String.fromEnvironment('ANDROID_PACKAGE');
const String _androidCertSha1 = String.fromEnvironment('ANDROID_CERT_SHA1');

/// The single active music provider (SRS FR-PROV-01): YouTube when an API key
/// was supplied at build time, otherwise the labeled sample catalog.
final musicProviderProvider = Provider<MusicProvider>((ref) {
  if (_youtubeApiKey.isNotEmpty) {
    final provider = YouTubeMusicProvider(
      apiKey: _youtubeApiKey,
      regionCode: _youtubeRegion,
      androidPackage: _androidPackage.isEmpty ? null : _androidPackage,
      androidCertSha1: _androidCertSha1.isEmpty ? null : _androidCertSha1,
    );
    ref.onDispose(provider.close);
    return provider;
  }
  return SampleMusicProvider();
});

/// The YouTube player. Created lazily, only when a YouTube track is played.
final youtubePlayerProvider = Provider<YoutubeIframePlayer>((ref) {
  final player = YoutubeIframePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Player used for sources that are not simulated. Tests override this.
final externalPlayerProvider = Provider<ExternalPlayer>((ref) => ref.watch(youtubePlayerProvider));

/// Overridden in main() with the opened SQLite repository.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => throw UnimplementedError('libraryRepositoryProvider must be overridden (see main.dart).'),
);

/// Overridden in main() with the opened SQLite repository.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider must be overridden (see main.dart).'),
);

final randomProvider = Provider<Random>((ref) => Random());
