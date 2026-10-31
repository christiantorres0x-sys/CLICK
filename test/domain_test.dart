import 'package:click/core/errors/app_exception.dart';
import 'package:click/core/utils/format.dart';
import 'package:click/data/providers/sample_music_provider.dart';
import 'package:click/domain/entities/repeat_mode.dart';
import 'package:click/domain/entities/track.dart';
import 'package:click/domain/repositories/library_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validatePlaylistName (FR-LIB-02, FR-LIB-04)', () {
    test('trims whitespace', () => expect(validatePlaylistName('  Road trip  '), 'Road trip'));

    test('rejects empty and blank names', () {
      expect(() => validatePlaylistName(''), throwsA(isA<ValidationException>()));
      expect(() => validatePlaylistName('   '), throwsA(isA<ValidationException>()));
    });

    test('rejects names over the length limit', () {
      expect(
        () => validatePlaylistName('x' * (maxPlaylistNameLength + 1)),
        throwsA(isA<ValidationException>()),
      );
      expect(validatePlaylistName('x' * maxPlaylistNameLength).length, maxPlaylistNameLength);
    });
  });

  group('Track', () {
    test('key is provider-qualified so catalogs cannot collide (SRS 7.2)', () {
      const a = Track(providerName: 'A', providerId: '1', title: 't', artistName: 'x');
      const b = Track(providerName: 'B', providerId: '1', title: 't', artistName: 'x');
      expect(a.key, isNot(b.key));
      expect(a == b, isFalse);
    });

    test('JSON round trip keeps all fields and never contains a stream URL', () {
      final original = SampleMusicProvider.catalog.first;
      final json = original.toJson();
      expect(json.keys, isNot(contains('streamUrl')));
      final copy = Track.fromJson(json);
      expect(copy, original);
      expect(copy.title, original.title);
      expect(copy.durationMs, original.durationMs);
    });
  });

  test('formatDuration', () {
    expect(formatDuration(const Duration(seconds: 5)), '0:05');
    expect(formatDuration(const Duration(minutes: 3, seconds: 24)), '3:24');
    expect(formatDuration(const Duration(seconds: -4)), '0:00');
  });

  test('RepeatMode cycles off -> all -> one -> off and parses safely', () {
    expect(RepeatMode.off.next, RepeatMode.all);
    expect(RepeatMode.all.next, RepeatMode.one);
    expect(RepeatMode.one.next, RepeatMode.off);
    expect(RepeatMode.parse('one'), RepeatMode.one);
    expect(RepeatMode.parse('garbage'), RepeatMode.off);
    expect(RepeatMode.parse(null), RepeatMode.off);
  });

  group('SampleMusicProvider (FR-PROV-01)', () {
    final provider = SampleMusicProvider(latency: Duration.zero);

    test('search matches title, artist and album, case-insensitively', () async {
      expect((await provider.searchTracks('glass')).map((t) => t.title), ['Glass Orbit']);
      expect(await provider.searchTracks('VELVET HARBOR'), hasLength(4));
      expect(await provider.searchTracks('daybreak maps'), hasLength(4)); // album + title match
    });

    test('empty and unmatched queries return no results', () async {
      expect(await provider.searchTracks('   '), isEmpty);
      expect(await provider.searchTracks('zzzz-no-match'), isEmpty);
    });

    test('details return null for unknown ids', () async {
      expect(await provider.getTrackDetails('sample-001'), isNotNull);
      expect(await provider.getTrackDetails('missing'), isNull);
    });

    test('unknown tracks are unavailable; known tracks resolve a simulated source', () async {
      expect(
        () => provider.resolvePlayableSource('missing'),
        throwsA(isA<ProviderUnavailableException>()),
      );
      final source = await provider.resolvePlayableSource('sample-001');
      expect(source.isSimulated, isTrue);
    });

    test('is labeled as a sample and discloses it', () {
      expect(provider.isSample, isTrue);
      expect(provider.attributionText, contains('fictional'));
    });

    test('featured content has titled, non-empty sections', () async {
      final sections = await provider.getFeaturedContent();
      expect(sections, isNotEmpty);
      for (final s in sections) {
        expect(s.title, isNotEmpty);
        expect(s.tracks, isNotEmpty);
      }
    });
  });
}
