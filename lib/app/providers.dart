import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers/jamendo_music_provider.dart';
import '../data/providers/just_audio_player.dart';
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

const String _jamendoClientId = String.fromEnvironment('JAMENDO_CLIENT_ID');

/// Every provider configured at build time. Each real provider appears only if
/// its credential was supplied (FR-PROV-05); with none, the labeled sample
/// catalog is the only entry.
final musicProvidersProvider = Provider<List<MusicProvider>>((ref) {
  final providers = <MusicProvider>[];
  if (_jamendoClientId.isNotEmpty) {
    final jamendo = JamendoMusicProvider(clientId: _jamendoClientId);
    ref.onDispose(jamendo.close);
    providers.add(jamendo); // first = the default source: audio-only, no video
  }
  if (_youtubeApiKey.isNotEmpty) {
    final youtube = YouTubeMusicProvider(
      apiKey: _youtubeApiKey,
      regionCode: _youtubeRegion,
      androidPackage: _androidPackage.isEmpty ? null : _androidPackage,
      androidCertSha1: _androidCertSha1.isEmpty ? null : _androidCertSha1,
    );
    ref.onDispose(youtube.close);
    providers.add(youtube);
  }
  if (providers.isEmpty) providers.add(SampleMusicProvider());
  return providers;
});

/// Name of the source the user picked (saved in settings), or null for the default.
class SelectedSourceNotifier extends Notifier<String?> {
  static const settingKey = 'music_source';
  bool _disposed = false;

  @override
  String? build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return null;
  }

  Future<void> _load() async {
    try {
      final saved = await ref.read(settingsStoreProvider).getSetting(settingKey);
      if (!_disposed && saved != null && saved.isNotEmpty) state = saved;
    } catch (_) {
      // Keep the default source.
    }
  }

  Future<void> select(String providerName) async {
    state = providerName;
    try {
      await ref.read(settingsStoreProvider).setSetting(settingKey, providerName);
    } catch (_) {
      // The choice still applies for this session.
    }
  }
}

final selectedSourceProvider = NotifierProvider<SelectedSourceNotifier, String?>(SelectedSourceNotifier.new);

/// The provider used for Home and Search (SRS FR-PROV-01): the saved choice if
/// it is configured, otherwise the first configured provider.
final musicProviderProvider = Provider<MusicProvider>((ref) {
  final providers = ref.watch(musicProvidersProvider);
  final selected = ref.watch(selectedSourceProvider);
  return providers.firstWhere((p) => p.name == selected, orElse: () => providers.first);
});

/// The YouTube player. Created lazily, only when a YouTube track is played.
final youtubePlayerProvider = Provider<YoutubeIframePlayer>((ref) {
  final player = YoutubeIframePlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Player for YouTube videos. Tests override this.
final externalPlayerProvider = Provider<ExternalPlayer>((ref) => ref.watch(youtubePlayerProvider));

/// Audio-only player for plain stream URLs (Jamendo). Created lazily; tests override this.
final audioPlayerProvider = Provider<ExternalPlayer>((ref) {
  final player = JustAudioPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Overridden in main() with the opened SQLite repository.
final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => throw UnimplementedError('libraryRepositoryProvider must be overridden (see main.dart).'),
);

/// Overridden in main() with the opened SQLite repository.
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => throw UnimplementedError('settingsStoreProvider must be overridden (see main.dart).'),
);

final randomProvider = Provider<Random>((ref) => Random());
