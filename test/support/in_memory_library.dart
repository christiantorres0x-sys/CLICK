import 'package:click/core/errors/app_exception.dart';
import 'package:click/domain/entities/playlist.dart';
import 'package:click/domain/entities/track.dart';
import 'package:click/domain/repositories/library_repository.dart';

/// In-memory stand-in for the SQLite repository, so controller and widget
/// tests do not need a database.
class InMemoryLibrary implements LibraryRepository, SettingsStore {
  final Map<String, Track> _tracks = {};
  final List<String> _liked = []; // newest first
  final Map<int, _PlaylistRow> _playlists = {};
  final List<String> _history = []; // oldest first
  final Map<String, String> _settings = {};
  int _nextId = 1;

  @override
  Future<List<Track>> likedTracks() async => [for (final k in _liked) _tracks[k]!];

  @override
  Future<void> setLiked(Track track, bool liked) async {
    _liked.remove(track.key);
    if (liked) {
      _tracks[track.key] = track;
      _liked.insert(0, track.key);
    }
  }

  @override
  Future<List<Playlist>> playlists() async => [
        for (final p in _playlists.values.toList().reversed)
          Playlist(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
            updatedAt: p.createdAt,
            trackCount: p.keys.length,
          ),
      ];

  @override
  Future<Playlist> createPlaylist(String name) async {
    final clean = validatePlaylistName(name);
    final row = _PlaylistRow(_nextId++, clean, DateTime.now());
    _playlists[row.id] = row;
    return Playlist(id: row.id, name: clean, createdAt: row.createdAt, updatedAt: row.createdAt);
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    final clean = validatePlaylistName(name);
    final row = _playlists[id];
    if (row == null) throw const ValidationException('That playlist no longer exists.');
    row.name = clean;
  }

  @override
  Future<void> deletePlaylist(int id) async => _playlists.remove(id);

  @override
  Future<List<Track>> playlistTracks(int id) async =>
      [for (final k in _playlists[id]?.keys ?? <String>[]) _tracks[k]!];

  @override
  Future<void> addToPlaylist(int id, Track track) async {
    final row = _playlists[id];
    if (row == null) throw const ValidationException('That playlist no longer exists.');
    if (row.keys.contains(track.key)) return;
    _tracks[track.key] = track;
    row.keys.add(track.key);
  }

  @override
  Future<void> removeFromPlaylist(int id, String trackKey) async => _playlists[id]?.keys.remove(trackKey);

  @override
  Future<void> recordPlay(Track track) async {
    _tracks[track.key] = track;
    _history.add(track.key);
  }

  @override
  Future<List<Track>> recentlyPlayed({int limit = 20}) async {
    final seen = <String>{};
    final result = <Track>[];
    for (final k in _history.reversed) {
      if (seen.add(k)) result.add(_tracks[k]!);
      if (result.length >= limit) break;
    }
    return result;
  }

  @override
  Future<void> clearHistory() async => _history.clear();

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String value) async => _settings[key] = value;
}

class _PlaylistRow {
  _PlaylistRow(this.id, this.name, this.createdAt);

  final int id;
  String name;
  final DateTime createdAt;
  final List<String> keys = [];
}
