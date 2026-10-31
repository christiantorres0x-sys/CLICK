import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/artwork.dart';
import 'now_playing_screen.dart';
import 'playback_controller.dart';

/// Compact player shown above the navigation bar whenever a track is loaded
/// (FR-UI-04). Tapping it opens the full Now Playing screen.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(playbackProvider);
    final track = s.current;
    if (track == null) return const SizedBox.shrink();

    final controller = ref.read(playbackProvider.notifier);
    final totalMs = s.duration.inMilliseconds;
    final double progress =
        totalMs > 0 ? (s.position.inMilliseconds / totalMs).clamp(0.0, 1.0).toDouble() : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
      child: Material(
        color: ClickColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => openNowPlaying(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                child: Row(
                  children: [
                    Artwork(track: track, size: 44, radius: 8),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            s.errorMessage ?? track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: s.errorMessage != null ? ClickColors.error : ClickColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (s.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      )
                    else
                      IconButton(
                        tooltip: s.isPlaying ? 'Pause' : 'Play',
                        icon: Icon(s.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                        onPressed: controller.togglePlayPause,
                      ),
                    IconButton(
                      tooltip: 'Next track',
                      icon: const Icon(Icons.skip_next_rounded),
                      onPressed: controller.next,
                    ),
                  ],
                ),
              ),
            ),
            LinearProgressIndicator(
              value: progress,
              minHeight: 2,
              backgroundColor: ClickColors.outline,
            ),
          ],
        ),
      ),
    );
  }
}
