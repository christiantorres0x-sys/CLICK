import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../domain/repositories/library_repository.dart';

const _keyShuffleDefault = 'shuffle_default';
const _keyRepeatMode = 'repeat_mode';

Future<AppSettings> loadAppSettings(SettingsStore store) async {
  final shuffle = await store.getSetting(_keyShuffleDefault);
  final repeat = await store.getSetting(_keyRepeatMode);
  return AppSettings(shuffleDefault: shuffle == 'true', repeatMode: RepeatMode.parse(repeat));
}

class SettingsNotifier extends Notifier<AppSettings> {
  bool _disposed = false;

  @override
  AppSettings build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(_load);
    return const AppSettings();
  }

  Future<void> _load() async {
    try {
      final loaded = await loadAppSettings(ref.read(settingsStoreProvider));
      if (!_disposed) state = loaded;
    } catch (_) {
      // Keep defaults if the store cannot be read.
    }
  }

  Future<void> setShuffleDefault(bool value) async {
    state = state.copyWith(shuffleDefault: value);
    await ref.read(settingsStoreProvider).setSetting(_keyShuffleDefault, value.toString());
  }

  Future<void> setRepeatMode(RepeatMode mode) async {
    state = state.copyWith(repeatMode: mode);
    await ref.read(settingsStoreProvider).setSetting(_keyRepeatMode, mode.name);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
