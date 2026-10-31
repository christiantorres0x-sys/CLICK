import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import 'playback_controller.dart';

/// View and edit the playback queue (FR-QUEUE-01..04). Reordering is a
/// "Should" requirement (FR-QUEUE-05) and is not part of this version.
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final current = s.current;
    final upNext = s.upNext;
    final firstUpNextIndex = (s.currentIndex ?? -1) + 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          TextButton(
            onPressed: upNext.isEmpty ? null : controller.clearUpcoming,
            child: const Text('Clear queue'),
          ),
        ],
      ),
      body: current == null
          ? const EmptyView(
              icon: Icons.queue_music_rounded,
              title: 'The queue is empty',
              message: 'Play a track or add one with the ⋮ menu.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              children: [
                const _SectionLabel('Now playing'),
                ListTile(
                  leading: Artwork(track: current, size: 48, radius: 8),
                  title: Text(
                    current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ClickColors.accent, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(current.artistName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Icon(
                    s.isPlaying ? Icons.equalizer_rounded : Icons.pause_rounded,
                    color: ClickColors.accent,
                  ),
                ),
                const _SectionLabel('Up next'),
                if (upNext.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    child: Text(
                      'No upcoming tracks.',
                      style: TextStyle(color: ClickColors.textSecondary),
                    ),
                  ),
                for (var i = 0; i < upNext.length; i++)
                  ListTile(
                    onTap: () => controller.skipTo(firstUpNextIndex + i),
                    leading: Artwork(track: upNext[i], size: 48, radius: 8),
                    title: Text(upNext[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      [
                        upNext[i].artistName,
                        if (upNext[i].durationMs != null) formatDuration(upNext[i].duration!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove from queue',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => controller.removeFromQueue(firstUpNextIndex + i),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: ClickColors.textSecondary),
      ),
    );
  }
}
