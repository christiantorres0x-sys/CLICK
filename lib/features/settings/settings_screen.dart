import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/constants/app_info.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../shared/widgets/feedback.dart';
import '../library/library_controller.dart';
import 'settings_controller.dart';

/// Profile / Settings (SRS FR-SET-01..04, 6.1).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(musicProviderProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final theme = Theme.of(context);

    Future<void> clearData() async {
      final messenger = ScaffoldMessenger.of(context);
      final library = ref.read(libraryProvider.notifier);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Clear listening history?'),
          content: const Text(
            'This removes your recently played list and cached track metadata. '
            'Liked songs and playlists are kept.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final ok = await guardAction(messenger, library.clearHistory);
      if (ok) showSnack(messenger, 'Listening history cleared.');
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Text(
              'Profile / Settings',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const _Section('Music provider'),
          ListTile(
            title: Text(provider.name),
            subtitle: Text(provider.attributionText),
          ),
          if (provider.attributionUrl != null)
            ListTile(
              title: const Text('Provider link'),
              subtitle: SelectableText(provider.attributionUrl!),
            ),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text(
              'The catalog and playback availability are controlled by the external music provider.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const _Section('Appearance'),
          const ListTile(
            title: Text('Theme'),
            subtitle: Text('Dark (the only theme in this version)'),
          ),
          const _Section('Playback'),
          SwitchListTile(
            title: const Text('Start with shuffle on'),
            subtitle: const Text('Applied the next time CLICK starts.'),
            value: settings.shuffleDefault,
            onChanged: (value) => guardAction(
              ScaffoldMessenger.of(context),
              () => notifier.setShuffleDefault(value),
            ),
          ),
          ListTile(
            title: const Text('Start with repeat'),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: SegmentedButton<RepeatMode>(
                showSelectedIcon: false,
                segments: [
                  for (final mode in RepeatMode.values)
                    ButtonSegment<RepeatMode>(value: mode, label: Text(mode.label)),
                ],
                selected: {settings.repeatMode},
                onSelectionChanged: (selection) => guardAction(
                  ScaffoldMessenger.of(context),
                  () => notifier.setRepeatMode(selection.first),
                ),
              ),
            ),
          ),
          const _Section('Data and privacy'),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Clear listening history'),
            subtitle: const Text('Also clears cached track metadata. Liked songs and playlists are kept.'),
            onTap: clearData,
          ),
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text(
              'CLICK has no account and no analytics. Your library is stored only on this device. '
              'Search requests may be processed by the music provider under its privacy policy.',
              style: TextStyle(fontSize: 14),
            ),
          ),
          const _Section('About'),
          const ListTile(
            title: Text(appName),
            subtitle: Text('Version $appVersion'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ClickColors.accent),
      ),
    );
  }
}
