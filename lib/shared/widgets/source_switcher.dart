import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../data/providers/jamendo_music_provider.dart';
import '../../data/providers/youtube_music_provider.dart';
import '../../features/search/search_controller.dart';

/// Lets the user pick where Home and Search get music from. Appears only when
/// more than one provider is configured. Tracks already queued keep playing
/// with their own provider.
class SourceSwitcher extends ConsumerWidget {
  const SourceSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final providers = ref.watch(musicProvidersProvider);
    if (providers.length < 2) return const SizedBox.shrink();
    final active = ref.watch(musicProviderProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final p in providers)
            ButtonSegment<String>(
              value: p.name,
              icon: Icon(_iconFor(p.name), size: 18),
              label: Text(_labelFor(p.name)),
            ),
        ],
        selected: {active.name},
        onSelectionChanged: (selection) {
          final name = selection.first;
          if (name == active.name) return;
          ref.read(searchProvider.notifier).clear(); // old results belong to the previous source
          ref.read(selectedSourceProvider.notifier).select(name);
        },
      ),
    );
  }

  static String _labelFor(String name) => switch (name) {
        YouTubeMusicProvider.providerName => 'YouTube (video)',
        JamendoMusicProvider.providerName => 'Jamendo (audio)',
        _ => name,
      };

  static IconData _iconFor(String name) => switch (name) {
        YouTubeMusicProvider.providerName => Icons.smart_display_rounded,
        JamendoMusicProvider.providerName => Icons.headphones_rounded,
        _ => Icons.library_music_rounded,
      };
}
