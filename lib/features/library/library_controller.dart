import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';

class LibraryState {
  LibraryState({
    this.liked = const [],
    this.playlists = const [],
    this.recent = const [],
    this.revision = 0,
    this.loaded = false,
  }) : likedKeys = {for (final t in liked) t.key};

  final List<Track> liked;
  final List<Playlist> playlists;
  final List<Track> recent;
  final Set<String> likedKeys;

  /// Increments on every reload so dependent providers can refresh.
  final int revision;
  final bool loaded;

  bool isLiked(Track track) => likedKeys.contains(track.key);
}

/// Holds the user's local library (SRS 5.7). Every mutation writes to the
/// repository first, then reloads, so the UI always reflects stored data.
class LibraryNotifier extends Notifier<LibraryState> {
  bool _disposed = false;

  @override
  LibraryState build() {
    ref.onDispose(() => _disposed = true);
    // The initial load must never throw into the zone; failures keep an empty library.
    Future.microtask(() => refresh().catchError((Object _) {}));
    return LibraryState();
  }

  Future<void> refresh() async {
    final repo = ref.read(libraryRepositoryProvider);
    try {
      final liked = await repo.likedTracks();
      final playlists = await repo.playlists();
      final recent = await repo.recentlyPlayed();
      if (_disposed) return;
      state = LibraryState(
        liked: liked,
        playlists: playlists,
        recent: recent,
        revision: state.revision + 1,
        loaded: true,
      );
    } catch (_) {
      if (_disposed) return;
      state = LibraryState(
        liked: state.liked,
        playlists: state.playlists,
        recent: state.recent,
        revision: state.revision + 1,
        loaded: true,
      );
      rethrow;
    }
  }

  Future<void> toggleLike(Track track) async {
    await ref.read(libraryRepositoryProvider).setLiked(track, !state.isLiked(track));
    await refresh();
  }

  Future<Playlist> createPlaylist(String name) async {
    final playlist = await ref.read(libraryRepositoryProvider).createPlaylist(name);
    await refresh();
    return playlist;
  }

  Future<void> renamePlaylist(int id, String name) async {
    await ref.read(libraryRepositoryProvider).renamePlaylist(id, name);
    await refresh();
  }

  Future<void> deletePlaylist(int id) async {
    await ref.read(libraryRepositoryProvider).deletePlaylist(id);
    await refresh();
  }

  Future<void> addToPlaylist(int id, Track track) async {
    await ref.read(libraryRepositoryProvider).addToPlaylist(id, track);
    await refresh();
  }

  Future<void> removeFromPlaylist(int id, Track track) async {
    await ref.read(libraryRepositoryProvider).removeFromPlaylist(id, track.key);
    await refresh();
  }

  Future<void> recordPlay(Track track) async {
    try {
      await ref.read(libraryRepositoryProvider).recordPlay(track);
      await refresh();
    } catch (_) {
      // History is optional (SRS 7.1); a failure must never interrupt playback.
    }
  }

  Future<void> clearHistory() async {
    await ref.read(libraryRepositoryProvider).clearHistory();
    await refresh();
  }
}

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

/// Tracks of one playlist, refreshed whenever the library changes.
final playlistTracksProvider = FutureProvider.family<List<Track>, int>((ref, id) {
  ref.watch(libraryProvider.select((s) => s.revision));
  return ref.read(libraryRepositoryProvider).playlistTracks(id);
});
