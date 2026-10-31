import '../../core/errors/app_exception.dart';
import '../entities/playlist.dart';
import '../entities/track.dart';

const int maxPlaylistNameLength = 60;

/// Trims and validates a playlist name (FR-LIB-02, FR-LIB-04).
String validatePlaylistName(String raw) {
  final name = raw.trim();
  if (name.isEmpty) {
    throw const ValidationException('Playlist name cannot be empty.');
  }
  if (name.length > maxPlaylistNameLength) {
    throw const ValidationException('Playlist name must be $maxPlaylistNameLength characters or fewer.');
  }
  return name;
}

/// Small key/value store for preferences (SRS 7.1 AppSettings).
abstract class SettingsStore {
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
}

/// Local-only personal library (SRS 5.7). Stores provider IDs plus cached
/// metadata, never audio (FR-LIB-06).
abstract class LibraryRepository {
  Future<List<Track>> likedTracks();
  Future<void> setLiked(Track track, bool liked);

  Future<List<Playlist>> playlists();
  Future<Playlist> createPlaylist(String name);
  Future<void> renamePlaylist(int id, String name);

  /// Removes the playlist and its track links only (SRS 7.2).
  Future<void> deletePlaylist(int id);

  Future<List<Track>> playlistTracks(int id);

  /// Adding a track already in the playlist is a no-op.
  Future<void> addToPlaylist(int id, Track track);
  Future<void> removeFromPlaylist(int id, String trackKey);

  Future<void> recordPlay(Track track);
  Future<List<Track>> recentlyPlayed({int limit = 20});
  Future<void> clearHistory();
}
