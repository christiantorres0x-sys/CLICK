import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/playlist.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/library_repository.dart';

/// SQLite-backed personal library and settings store (SRS 5.7, 7.1, 7.2).
///
/// Only provider identifiers and metadata are stored, never audio or stream
/// URLs. Upserts use update-then-insert because SQLite's UPSERT syntax is not
/// available on Android 8-10 (API 26-29).
class SqliteLibraryRepository implements LibraryRepository, SettingsStore {
  SqliteLibraryRepository._(this._db);

  final Database _db;

  static const int schemaVersion = 1;
  static const int _historyLimit = 500;

  /// Opens (and creates/migrates) the database. [path] is for tests.
  static Future<SqliteLibraryRepository> open({String? path}) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), 'click.db');
    final db = await openDatabase(
      dbPath,
      version: schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return SqliteLibraryRepository._(db);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE tracks (
        track_key TEXT PRIMARY KEY,
        provider_name TEXT NOT NULL,
        provider_id TEXT NOT NULL,
        title TEXT NOT NULL,
        artist_name TEXT NOT NULL,
        album_title TEXT,
        artwork_url TEXT,
        duration_ms INTEGER,
        attribution_url TEXT
      )''');
    batch.execute('''
      CREATE TABLE liked_tracks (
        track_key TEXT PRIMARY KEY REFERENCES tracks(track_key),
        saved_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE playlist_tracks (
        playlist_id INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
        track_key TEXT NOT NULL REFERENCES tracks(track_key),
        position INTEGER NOT NULL,
        added_at INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, track_key)
      )''');
    batch.execute('''
      CREATE TABLE playback_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        track_key TEXT NOT NULL REFERENCES tracks(track_key),
        played_at INTEGER NOT NULL
      )''');
    batch.execute('''
      CREATE TABLE settings (
        setting_key TEXT PRIMARY KEY,
        setting_value TEXT NOT NULL
      )''');
    await batch.commit(noResult: true);
  }

  /// Schema version 1 is the first release, so there is nothing to migrate yet.
  /// Add `if (oldVersion < 2) { ... }` steps here when the schema changes.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  Future<void> close() => _db.close();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  // --- helpers -------------------------------------------------------------

  Map<String, Object?> _trackRow(Track t) => {
        'track_key': t.key,
        'provider_name': t.providerName,
        'provider_id': t.providerId,
        'title': t.title,
        'artist_name': t.artistName,
        'album_title': t.albumTitle,
        'artwork_url': t.artworkUrl,
        'duration_ms': t.durationMs,
        'attribution_url': t.attributionUrl,
      };

  Track _trackFromRow(Map<String, Object?> r) => Track(
        providerName: r['provider_name']! as String,
        providerId: r['provider_id']! as String,
        title: r['title']! as String,
        artistName: r['artist_name']! as String,
        albumTitle: r['album_title'] as String?,
        artworkUrl: r['artwork_url'] as String?,
        durationMs: r['duration_ms'] as int?,
        attributionUrl: r['attribution_url'] as String?,
      );

  Future<void> _upsertTrack(DatabaseExecutor db, Track t) async {
    final row = _trackRow(t);
    final updated = await db.update('tracks', row, where: 'track_key = ?', whereArgs: [t.key]);
    if (updated == 0) await db.insert('tracks', row);
  }

  Playlist _playlistFromRow(Map<String, Object?> r) => Playlist(
        id: r['id']! as int,
        name: r['name']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at']! as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at']! as int),
        trackCount: (r['track_count'] as int?) ?? 0,
      );

  // --- liked tracks --------------------------------------------------------

  @override
  Future<List<Track>> likedTracks() async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM liked_tracks l
      JOIN tracks t ON t.track_key = l.track_key
      ORDER BY l.saved_at DESC, l.rowid DESC''');
    return rows.map(_trackFromRow).toList();
  }

  @override
  Future<void> setLiked(Track track, bool liked) async {
    await _db.transaction((txn) async {
      if (liked) {
        await _upsertTrack(txn, track);
        await txn.insert(
          'liked_tracks',
          {'track_key': track.key, 'saved_at': _now},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      } else {
        await txn.delete('liked_tracks', where: 'track_key = ?', whereArgs: [track.key]);
      }
    });
  }

  // --- playlists -----------------------------------------------------------

  @override
  Future<List<Playlist>> playlists() async {
    final rows = await _db.rawQuery('''
      SELECT p.id, p.name, p.created_at, p.updated_at,
        (SELECT COUNT(*) FROM playlist_tracks pt WHERE pt.playlist_id = p.id) AS track_count
      FROM playlists p
      ORDER BY p.updated_at DESC, p.id DESC''');
    return rows.map(_playlistFromRow).toList();
  }

  @override
  Future<Playlist> createPlaylist(String name) async {
    final clean = validatePlaylistName(name);
    final now = _now;
    final id = await _db.insert('playlists', {'name': clean, 'created_at': now, 'updated_at': now});
    return Playlist(
      id: id,
      name: clean,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    final clean = validatePlaylistName(name);
    final updated = await _db.update(
      'playlists',
      {'name': clean, 'updated_at': _now},
      where: 'id = ?',
      whereArgs: [id],
    );
    if (updated == 0) throw const ValidationException('That playlist no longer exists.');
  }

  @override
  Future<void> deletePlaylist(int id) async {
    await _db.transaction((txn) async {
      await txn.delete('playlist_tracks', where: 'playlist_id = ?', whereArgs: [id]);
      await txn.delete('playlists', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<List<Track>> playlistTracks(int id) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM playlist_tracks pt
      JOIN tracks t ON t.track_key = pt.track_key
      WHERE pt.playlist_id = ?
      ORDER BY pt.position ASC''', [id]);
    return rows.map(_trackFromRow).toList();
  }

  @override
  Future<void> addToPlaylist(int id, Track track) async {
    await _db.transaction((txn) async {
      final exists = Sqflite.firstIntValue(
              await txn.rawQuery('SELECT COUNT(*) FROM playlists WHERE id = ?', [id])) ??
          0;
      if (exists == 0) throw const ValidationException('That playlist no longer exists.');

      final already = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM playlist_tracks WHERE playlist_id = ? AND track_key = ?',
              [id, track.key])) ??
          0;
      if (already > 0) return; // adding a duplicate is a no-op

      await _upsertTrack(txn, track);
      final next = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COALESCE(MAX(position), -1) + 1 FROM playlist_tracks WHERE playlist_id = ?',
              [id])) ??
          0;
      final now = _now;
      await txn.insert('playlist_tracks', {
        'playlist_id': id,
        'track_key': track.key,
        'position': next,
        'added_at': now,
      });
      await txn.update('playlists', {'updated_at': now}, where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> removeFromPlaylist(int id, String trackKey) async {
    await _db.transaction((txn) async {
      final removed = await txn.delete(
        'playlist_tracks',
        where: 'playlist_id = ? AND track_key = ?',
        whereArgs: [id, trackKey],
      );
      if (removed > 0) {
        await txn.update('playlists', {'updated_at': _now}, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  // --- history -------------------------------------------------------------

  @override
  Future<void> recordPlay(Track track) async {
    await _db.transaction((txn) async {
      await _upsertTrack(txn, track);
      await txn.insert('playback_history', {'track_key': track.key, 'played_at': _now});
      await txn.rawDelete(
        'DELETE FROM playback_history WHERE id NOT IN '
        '(SELECT id FROM playback_history ORDER BY id DESC LIMIT $_historyLimit)',
      );
    });
  }

  @override
  Future<List<Track>> recentlyPlayed({int limit = 20}) async {
    final rows = await _db.rawQuery('''
      SELECT t.* FROM tracks t
      JOIN (SELECT track_key, MAX(id) AS last_id FROM playback_history GROUP BY track_key) h
        ON h.track_key = t.track_key
      ORDER BY h.last_id DESC
      LIMIT ?''', [limit]);
    return rows.map(_trackFromRow).toList();
  }

  /// Clears listening history and cached metadata that nothing references
  /// (tracks that are not liked and not in a playlist). FR-SET-03.
  @override
  Future<void> clearHistory() async {
    await _db.transaction((txn) async {
      await txn.delete('playback_history');
      await txn.rawDelete('''
        DELETE FROM tracks
        WHERE track_key NOT IN (SELECT track_key FROM liked_tracks)
          AND track_key NOT IN (SELECT track_key FROM playlist_tracks)''');
    });
  }

  // --- settings ------------------------------------------------------------

  @override
  Future<String?> getSetting(String key) async {
    final rows = await _db.query(
      'settings',
      columns: ['setting_value'],
      where: 'setting_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['setting_value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String value) async {
    final updated = await _db.update(
      'settings',
      {'setting_value': value},
      where: 'setting_key = ?',
      whereArgs: [key],
    );
    if (updated == 0) {
      await _db.insert('settings', {'setting_key': key, 'setting_value': value});
    }
  }
}
