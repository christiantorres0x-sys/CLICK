import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/state_views.dart';
import 'playback_controller.dart';

/// View and edit the playback queue (FR-QUEUE-01..05). Drag the handle on an
/// upcoming track to reorder it.
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
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: upNext.length,
                  // ReorderableListView reports newIndex as if the dragged row were still in place.
                  onReorder: (oldIndex, newIndex) {
                    final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
                    controller.moveInQueue(firstUpNextIndex + oldIndex, firstUpNextIndex + target);
                  },
                  itemBuilder: (context, i) => ListTile(
                    key: ValueKey('${firstUpNextIndex + i}:${upNext[i].key}'),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Remove from queue',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => controller.removeFromQueue(firstUpNextIndex + i),
                        ),
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(8),
                            child: Icon(Icons.drag_handle_rounded, semanticLabel: 'Drag to reorder'),
                          ),
                        ),
                      ],
                    ),
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
