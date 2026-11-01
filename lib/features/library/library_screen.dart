import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_theme.dart';
import '../../shared/widgets/feedback.dart';
import '../../shared/widgets/playlist_dialogs.dart';
import '../../shared/widgets/state_views.dart';
import '../../shared/widgets/track_tile.dart';
import '../player/mini_player.dart';
import '../player/playback_controller.dart';
import 'library_controller.dart';
import 'playlist_screen.dart';

/// Liked Songs, playlists and recently played (SRS 6.1 Library).
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final theme = Theme.of(context);

    Future<void> createPlaylist() async {
      final messenger = ScaffoldMessenger.of(context);
      final notifier = ref.read(libraryProvider.notifier);
      final name = await showPlaylistNameDialog(
        context,
        title: 'New playlist',
        confirmLabel: 'Create',
      );
      if (name == null) return;
      await guardValue(messenger, () => notifier.createPlaylist(name));
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.sm, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Library',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'New playlist',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: createPlaylist,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: ClickColors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.favorite_rounded, color: ClickColors.onAccent),
            ),
            title: const Text('Liked Songs', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${library.liked.length} tracks'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LikedSongsScreen()),
            ),
          ),
          const _Label('Playlists'),
          if (library.playlists.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Text(
                'No playlists yet. Tap + to create one.',
                style: TextStyle(color: ClickColors.textSecondary),
              ),
            ),
          for (final playlist in library.playlists)
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ClickColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.queue_music_rounded, color: ClickColors.textSecondary),
              ),
              title: Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('${playlist.trackCount} tracks'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => PlaylistScreen(playlistId: playlist.id)),
              ),
            ),
          const _Label('Recently played'),
          if (library.recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Text(
                'Tracks you play will appear here.',
                style: TextStyle(color: ClickColors.textSecondary),
              ),
            ),
          for (var i = 0; i < library.recent.length; i++)
            TrackTile(
              track: library.recent[i],
              onTap: () => ref.read(playbackProvider.notifier).playTracks(library.recent, startIndex: i),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class LikedSongsScreen extends ConsumerWidget {
  const LikedSongsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(libraryProvider.select((s) => s.liked));
    return Scaffold(
      appBar: AppBar(title: const Text('Liked Songs')),
      bottomNavigationBar: const MiniPlayer(),
      body: liked.isEmpty
          ? const EmptyView(
              icon: Icons.favorite_border_rounded,
              title: 'No liked songs yet',
              message: 'Tap the heart on a track to save it.',
            )
          : ListView.builder(
              itemCount: liked.length,
              itemBuilder: (context, i) => TrackTile(
                track: liked[i],
                onTap: () => ref.read(playbackProvider.notifier).playTracks(liked, startIndex: i),
              ),
            ),
    );
  }
}
