import 'package:flutter/material.dart' hide RepeatMode;
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/repeat_mode.dart';
import '../../shared/widgets/artwork.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/state_views.dart';
import '../library/library_controller.dart';
import 'playback_controller.dart';
import 'queue_screen.dart';

void openNowPlaying(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const NowPlayingScreen(),
    ),
  );
}

/// Full-screen player (SRS 6.1 Now Playing): artwork, track/artist, seek bar,
/// transport controls, shuffle/repeat, queue and like actions.
class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(playbackProvider);
    final controller = ref.read(playbackProvider.notifier);
    final track = s.current;
    final playbackNotice = ref.watch(musicProviderProvider).playbackNotice;

    if (track == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(
          icon: Icons.music_off_rounded,
          title: 'Nothing is playing',
          message: 'Pick a track from Home, Search or your Library.',
        ),
      );
    }

    final liked = ref.watch(libraryProvider.select((l) => l.likedKeys.contains(track.key)));
    final totalMs = s.duration.inMilliseconds;
    final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final positionMs = math.min(math.max(_dragMs ?? s.position.inMilliseconds.toDouble(), 0.0), maxMs);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Close Now Playing',
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Now Playing'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Queue',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const QueueScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Artwork(track: track, radius: 18),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          track.albumTitle == null
                              ? track.artistName
                              : '${track.artistName} · ${track.albumTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: ClickColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
                    iconSize: 28,
                    icon: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: liked ? ClickColors.accent : ClickColors.textSecondary,
                    ),
                    onPressed: () => guardAction(
                      ScaffoldMessenger.of(context),
                      () => ref.read(libraryProvider.notifier).toggleLike(track),
                    ),
                  ),
                ],
              ),
              if (s.errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: ClickColors.error, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${s.errorMessage} Press play to retry.',
                        style: const TextStyle(color: ClickColors.error),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Slider(
                value: positionMs,
                max: maxMs,
                onChanged: totalMs > 0 ? (v) => setState(() => _dragMs = v) : null,
                onChangeEnd: (v) {
                  controller.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragMs = null);
                },
                semanticFormatterCallback: (v) => formatDuration(Duration(milliseconds: v.round())),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(formatDuration(Duration(milliseconds: positionMs.round()))),
                    Text(formatDuration(s.duration)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: s.shuffle ? 'Shuffle: on' : 'Shuffle: off',
                    iconSize: 28,
                    icon: Icon(
                      Icons.shuffle_rounded,
                      color: s.shuffle ? ClickColors.accent : ClickColors.textSecondary,
                    ),
                    onPressed: controller.toggleShuffle,
                  ),
                  IconButton(
                    tooltip: 'Previous track',
                    iconSize: 40,
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: controller.previous,
                  ),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: IconButton.filled(
                      tooltip: s.isPlaying ? 'Pause' : 'Play',
                      iconSize: 40,
                      icon: s.isLoading
                          ? const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            )
                          : Icon(s.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                      onPressed: controller.togglePlayPause,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next track',
                    iconSize: 40,
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: controller.next,
                  ),
                  IconButton(
                    tooltip: 'Repeat: ${s.repeat.label.toLowerCase()}',
                    iconSize: 28,
                    icon: Icon(
                      s.repeat == RepeatMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                      color: s.repeat == RepeatMode.off ? ClickColors.textSecondary : ClickColors.accent,
                    ),
                    onPressed: controller.cycleRepeat,
                  ),
                ],
              ),
              if (playbackNotice != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  playbackNotice,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: ClickColors.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
