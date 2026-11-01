import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/constants/app_info.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/source_switcher.dart';
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
          title: const Text('Clear history?'),
          content: const Text('Liked songs and playlists are kept.'),
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
      if (ok) showSnack(messenger, 'History cleared');
    }

    // Provider disclosure (FR-SET-02) and the privacy note live one tap away instead of
    // filling the screen.
    Future<void> showSourceInfo() => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(provider.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(provider.attributionText),
                  if (provider.attributionUrl != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SelectableText(provider.attributionUrl!),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'CLICK has no account and no analytics. Your library stays on this device. '
                    'Searches go to the music provider.',
                    style: TextStyle(color: ClickColors.textSecondary),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Close')),
            ],
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Text(
              'Profile',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const _Section('Music source'),
          const SourceSwitcher(),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: Text('About ${provider.name}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: showSourceInfo,
          ),
          const _Section('Playback'),
          SwitchListTile(
            title: const Text('Shuffle on start'),
            value: settings.shuffleDefault,
            onChanged: (value) => guardAction(
              ScaffoldMessenger.of(context),
              () => notifier.setShuffleDefault(value),
            ),
          ),
          ListTile(
            title: const Text('Repeat on start'),
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
          const _Section('Data'),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('Clear listening history'),
            onTap: clearData,
          ),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: Text(
              '$appName · v$appVersion',
              style: TextStyle(color: ClickColors.textSecondary, fontSize: 13),
            ),
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
