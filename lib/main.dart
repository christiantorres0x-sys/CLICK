import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'app/theme/app_theme.dart';
import 'data/local/sqlite_library_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background playback + notification/lock-screen controls for audio streams (FR-BG).
  // If this fails the app still works; audio just stops when the app is closed.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.click.channel.audio',
      androidNotificationChannelName: 'CLICK playback',
      androidNotificationOngoing: true,
    );
  } catch (_) {}

  final SqliteLibraryRepository repository;
  try {
    repository = await SqliteLibraryRepository.open();
  } catch (_) {
    // NFR-REL: show a readable message instead of crashing on launch.
    runApp(const _StartupErrorApp());
    return;
  }

  runApp(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        settingsStoreProvider.overrideWithValue(repository),
      ],
      child: const ClickApp(),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildClickTheme(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'CLICK could not open its local database. Restart the app, or clear the app data '
              'from Android settings if the problem continues.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
