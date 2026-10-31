import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../core/errors/app_exception.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/playlist_dialogs.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/track_tile.dart';
import '../player/mini_player.dart';
import '../player/playback_controller.dart';
import 'library_controller.dart';

enum _PlaylistMenu { rename, delete }

/// One playlist: play, rename, delete, remove tracks (FR-LIB-03, FR-LIB-04).
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(libraryProvider.select((s) {
      for (final p in s.playlists) {
        if (p.id == playlistId) return p;
      }
      return null;
    }));

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyView(icon: Icons.queue_music_rounded, title: 'Playlist not found'),
      );
    }

    final tracksAsync = ref.watch(playlistTracksProvider(playlistId));

    Future<void> rename() async {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(libraryProvider.notifier);
      final name = await showPlaylistNameDialog(
        context,
        title: 'Rename playlist',
        confirmLabel: 'Rename',
        initial: playlist.name,
      );
      if (name == null) return;
      await guardAction(messenger, () => notifier.renamePlaylist(playlistId, name));
    }

    Future<void> delete() async {
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(libraryProvider.notifier);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text('"${playlist.name}" will be deleted. The tracks themselves are not affected.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final ok = await guardAction(messenger, () => notifier.deletePlaylist(playlistId));
      if (ok) navigator.pop();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<_PlaylistMenu>(
            tooltip: 'Playlist options',
            onSelected: (action) {
              switch (action) {
                case _PlaylistMenu.rename:
                  rename();
                case _PlaylistMenu.delete:
                  delete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _PlaylistMenu.rename, child: Text('Rename')),
              PopupMenuItem(value: _PlaylistMenu.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: tracksAsync.when(
        skipLoadingOnReload: true,
        loading: () => const LoadingView(label: 'Loading playlist'),
        error: (error, _) => ErrorView(
          message: error is AppException ? error.userMessage : 'Could not load this playlist.',
          onRetry: () => ref.invalidate(playlistTracksProvider(playlistId)),
        ),
        data: (tracks) {
          if (tracks.isEmpty) {
            return const EmptyView(
              icon: Icons.library_music_outlined,
              title: 'This playlist is empty',
              message: 'Add tracks with the ⋮ menu on any track in Home, Search or Library.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => ref.read(playbackProvider.notifier).playTracks(tracks),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Play · ${tracks.length} tracks'),
                  ),
                ),
              ),
              for (var i = 0; i < tracks.length; i++)
                TrackTile(
                  track: tracks[i],
                  onTap: () => ref.read(playbackProvider.notifier).playTracks(tracks, startIndex: i),
                  onRemoveFromPlaylist: () => guardAction(
                    ScaffoldMessenger.of(context),
                    () => ref.read(libraryProvider.notifier).removeFromPlaylist(playlistId, tracks[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
