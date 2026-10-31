// These tests run the real SQL against an in-memory SQLite via sqflite_common_ffi.
// On Windows you may need sqlite3.dll available (see the sqflite_common_ffi docs);
// every other test file works without it.
import 'package:click/core/errors/app_exception.dart';
import 'package:click/data/local/sqlite_library_repository.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final a = SampleMusicProvider.catalog[0];
  final b = SampleMusicProvider.catalog[1];
  final c = SampleMusicProvider.catalog[2];

  late SqliteLibraryRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    repo = await SqliteLibraryRepository.open(path: inMemoryDatabasePath);
  });

  tearDown(() => repo.close());

  test('liked tracks persist metadata, newest first (FR-LIB-01, FR-LIB-05)', () async {
    await repo.setLiked(a, true);
    await repo.setLiked(b, true);
    final liked = await repo.likedTracks();
    expect(liked, [b, a]);
    expect(liked.last.title, a.title);
    expect(liked.last.durationMs, a.durationMs);
    await repo.setLiked(a, false);
    expect(await repo.likedTracks(), [b]);
  });

  test('liking twice does not duplicate', () async {
    await repo.setLiked(a, true);
    await repo.setLiked(a, true);
    expect(await repo.likedTracks(), hasLength(1));
  });

  test('playlist create, rename, delete (FR-LIB-02, FR-LIB-04)', () async {
    final p = await repo.createPlaylist('  Road trip ');
    expect(p.name, 'Road trip');
    await repo.renamePlaylist(p.id, 'Night drive');
    expect((await repo.playlists()).single.name, 'Night drive');
    await repo.deletePlaylist(p.id);
    expect(await repo.playlists(), isEmpty);
  });

  test('invalid names and missing playlists are rejected', () async {
    await expectLater(repo.createPlaylist(''), throwsA(isA<ValidationException>()));
    await expectLater(repo.renamePlaylist(999, 'x'), throwsA(isA<ValidationException>()));
    await expectLater(repo.addToPlaylist(999, a), throwsA(isA<ValidationException>()));
  });

  test('playlist tracks keep insertion order; duplicates are a no-op (FR-LIB-03)', () async {
    final p = await repo.createPlaylist('Mix');
    await repo.addToPlaylist(p.id, b);
    await repo.addToPlaylist(p.id, a);
    await repo.addToPlaylist(p.id, b);
    await repo.addToPlaylist(p.id, c);
    expect(await repo.playlistTracks(p.id), [b, a, c]);
    expect((await repo.playlists()).single.trackCount, 3);
    await repo.removeFromPlaylist(p.id, a.key);
    expect(await repo.playlistTracks(p.id), [b, c]);
  });

  test('deleting a playlist removes links but not liked tracks (SRS 7.2)', () async {
    final p = await repo.createPlaylist('Mix');
    await repo.setLiked(a, true);
    await repo.addToPlaylist(p.id, a);
    await repo.deletePlaylist(p.id);
    expect(await repo.playlists(), isEmpty);
    expect(await repo.likedTracks(), [a]);
  });

  test('recently played is distinct and most recent first', () async {
    await repo.recordPlay(a);
    await repo.recordPlay(b);
    await repo.recordPlay(a);
    expect(await repo.recentlyPlayed(), [a, b]);
    expect(await repo.recentlyPlayed(limit: 1), [a]);
  });

  test('clearHistory removes history and unreferenced metadata only (FR-SET-03)', () async {
    final p = await repo.createPlaylist('Mix');
    await repo.recordPlay(a); // referenced by a playlist below
    await repo.recordPlay(b); // referenced by nothing else
    await repo.addToPlaylist(p.id, a);
    await repo.setLiked(c, true);
    await repo.clearHistory();
    expect(await repo.recentlyPlayed(), isEmpty);
    expect(await repo.playlistTracks(p.id), [a]);
    expect(await repo.likedTracks(), [c]);
  });

  test('settings round trip and overwrite', () async {
    expect(await repo.getSetting('repeat_mode'), isNull);
    await repo.setSetting('repeat_mode', 'all');
    expect(await repo.getSetting('repeat_mode'), 'all');
    await repo.setSetting('repeat_mode', 'one');
    expect(await repo.getSetting('repeat_mode'), 'one');
  });
}
