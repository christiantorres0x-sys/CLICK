import 'package:click/core/errors/app_exception.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/entities/track.dart';
import 'package:click/features/library/library_controller.dart';
import 'package:click/features/search/search_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_container.dart';

class _RateLimitedProvider extends SampleMusicProvider {
  _RateLimitedProvider() : super(latency: Duration.zero);

  @override
  Future<List<Track>> searchTracks(String query) async => throw const RateLimitException();
}

class _BrokenProvider extends SampleMusicProvider {
  _BrokenProvider() : super(latency: Duration.zero);

  @override
  Future<List<Track>> searchTracks(String query) async => throw StateError('boom');
}

void main() {
  group('search (FR-SEARCH-01, 02, 06)', () {
    test('success returns results through the provider', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.listen(searchProvider, (_, __) {});
      await c.read(searchProvider.notifier).search('static');
      final s = c.read(searchProvider);
      expect(s.status, SearchStatus.success);
      expect(s.results.map((t) => t.title), containsAll(['Glass Orbit', 'Sunroom Static']));
    });

    test('no results is a success with an empty list', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.listen(searchProvider, (_, __) {});
      await c.read(searchProvider.notifier).search('qqqqq');
      expect(c.read(searchProvider).status, SearchStatus.success);
      expect(c.read(searchProvider).results, isEmpty);
    });

    test('a blank query resets to idle', () async {
      final c = makeContainer();
      addTearDown(c.dispose);
      c.listen(searchProvider, (_, __) {});
      await c.read(searchProvider.notifier).search('glass');
      c.read(searchProvider.notifier).onQueryChanged('   ');
      expect(c.read(searchProvider).status, SearchStatus.idle);
    });

    test('rate limit errors show their user message', () async {
      final c = makeContainer(provider: _RateLimitedProvider());
      addTearDown(c.dispose);
      c.listen(searchProvider, (_, __) {});
      await c.read(searchProvider.notifier).search('glass');
      final s = c.read(searchProvider);
      expect(s.status, SearchStatus.error);
      expect(s.errorMessage, const RateLimitException().userMessage);
    });

    test('unexpected errors become a generic message, not a crash', () async {
      final c = makeContainer(provider: _BrokenProvider());
      addTearDown(c.dispose);
      c.listen(searchProvider, (_, __) {});
      await c.read(searchProvider.notifier).search('glass');
      expect(c.read(searchProvider).status, SearchStatus.error);
      expect(c.read(searchProvider).errorMessage, isNotEmpty);
    });
  });

  group('library (FR-LIB-01..05)', () {
    final a = SampleMusicProvider.catalog[0];
    final b = SampleMusicProvider.catalog[1];

    late ProviderContainer c;
    LibraryNotifier lib() => c.read(libraryProvider.notifier);
    LibraryState state() => c.read(libraryProvider);

    setUp(() async {
      c = makeContainer();
      c.listen(libraryProvider, (_, __) {});
      await pumpEventQueue(); // let the initial load finish
    });
    tearDown(() => c.dispose());

    test('like and unlike a track', () async {
      await lib().toggleLike(a);
      expect(state().isLiked(a), isTrue);
      expect(state().liked, [a]);
      await lib().toggleLike(a);
      expect(state().isLiked(a), isFalse);
      expect(state().liked, isEmpty);
    });

    test('create, rename and delete a playlist', () async {
      final p = await lib().createPlaylist('  Focus ');
      expect(state().playlists.single.name, 'Focus');
      await lib().renamePlaylist(p.id, 'Deep focus');
      expect(state().playlists.single.name, 'Deep focus');
      await lib().deletePlaylist(p.id);
      expect(state().playlists, isEmpty);
    });

    test('invalid playlist names are rejected', () async {
      await expectLater(lib().createPlaylist('   '), throwsA(isA<ValidationException>()));
      expect(state().playlists, isEmpty);
    });

    test('add and remove tracks; duplicates are ignored', () async {
      final p = await lib().createPlaylist('Mix');
      await lib().addToPlaylist(p.id, a);
      await lib().addToPlaylist(p.id, a);
      await lib().addToPlaylist(p.id, b);
      expect(state().playlists.single.trackCount, 2);
      expect(await c.read(playlistTracksProvider(p.id).future), [a, b]);
      await lib().removeFromPlaylist(p.id, a);
      expect(await c.read(playlistTracksProvider(p.id).future), [b]);
    });

    test('deleting a playlist does not remove liked tracks', () async {
      final p = await lib().createPlaylist('Mix');
      await lib().toggleLike(a);
      await lib().addToPlaylist(p.id, a);
      await lib().deletePlaylist(p.id);
      expect(state().isLiked(a), isTrue);
    });

    test('recently played and clearHistory', () async {
      await lib().recordPlay(a);
      await lib().recordPlay(b);
      expect(state().recent, [b, a]);
      await lib().clearHistory();
      expect(state().recent, isEmpty);
    });
  });
}
