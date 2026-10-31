import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../domain/entities/track.dart';
import '../../features/library/library_controller.dart';
import '../../features/player/playback_controller.dart';
import 'artwork.dart';
import 'feedback.dart';
import 'playlist_dialogs.dart';

enum _TrackAction { addToQueue, addToPlaylist, removeFromPlaylist }

/// One track row: artwork, title, artist, like button and overflow menu.
/// Shows an "unavailable" state for tracks the provider no longer offers
/// (FR-LIB-07, FR-PLAY-06).
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onRemoveFromPlaylist,
  });

  final Track track;
  final VoidCallback onTap;

  /// When set, the overflow menu offers "Remove from this playlist".
  final VoidCallback? onRemoveFromPlaylist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(playbackProvider.select((s) => s.current?.key == track.key));
    final unavailable = ref.watch(playbackProvider.select((s) => s.unavailableKeys.contains(track.key)));
    final liked = ref.watch(libraryProvider.select((s) => s.likedKeys.contains(track.key)));

    final subtitle = unavailable
        ? 'Unavailable from provider'
        : [track.artistName, if (track.durationMs != null) formatDuration(track.duration!)].join(' · ');

    return ListTile(
      // Stays tappable when unavailable: tapping retries, since a failure can be
      // temporary (network, YouTube hiccup). It is only dimmed.
      onTap: onTap,
      leading: Artwork(track: track, size: 48, radius: 8),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent
              ? ClickColors.accent
              : (unavailable ? ClickColors.textSecondary : null),
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: unavailable ? ClickColors.error : ClickColors.textSecondary),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: liked ? 'Remove from Liked Songs' : 'Add to Liked Songs',
            icon: Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: liked ? ClickColors.accent : ClickColors.textSecondary,
            ),
            onPressed: () => guardAction(
              ScaffoldMessenger.of(context),
              () => ref.read(libraryProvider.notifier).toggleLike(track),
            ),
          ),
          PopupMenuButton<_TrackAction>(
            tooltip: 'More options',
            onSelected: (action) {
              switch (action) {
                case _TrackAction.addToQueue:
                  ref.read(playbackProvider.notifier).addToQueue(track);
                  showSnack(ScaffoldMessenger.of(context), 'Added to queue');
                case _TrackAction.addToPlaylist:
                  showAddToPlaylistSheet(context, track);
                case _TrackAction.removeFromPlaylist:
                  onRemoveFromPlaylist?.call();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: _TrackAction.addToQueue, child: Text('Add to queue')),
              const PopupMenuItem(value: _TrackAction.addToPlaylist, child: Text('Add to playlist')),
              if (onRemoveFromPlaylist != null)
                const PopupMenuItem(
                  value: _TrackAction.removeFromPlaylist,
                  child: Text('Remove from this playlist'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
