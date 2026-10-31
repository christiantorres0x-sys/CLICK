import 'dart:convert';

import 'package:click/core/errors/app_exception.dart';
import 'package:click/data/providers/youtube_music_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> video(
  String id, {
  String title = 'Song',
  String channel = 'Artist',
  String duration = 'PT3M24S',
  bool embeddable = true,
  String category = '10',
  String live = 'none',
  String privacy = 'public',
}) =>
    {
      'id': id,
      'snippet': {
        'title': title,
        'channelTitle': channel,
        'categoryId': category,
        'liveBroadcastContent': live,
        'thumbnails': {
          'default': {'url': 'https://img/$id/default.jpg'},
          'high': {'url': 'https://img/$id/high.jpg'},
        },
      },
      'contentDetails': {'duration': duration},
      'status': {'embeddable': embeddable, 'privacyStatus': privacy},
    };

http.Response jsonResponse(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

http.Response apiError(int status, String reason) => jsonResponse({
      'error': {
        'code': status,
        'errors': [
          {'reason': reason}
        ],
      },
    }, status);

void main() {
  group('helpers', () {
    test('parseIsoDuration', () {
      expect(parseIsoDuration('PT3M24S'), const Duration(minutes: 3, seconds: 24));
      expect(parseIsoDuration('PT1H2M3S'), const Duration(hours: 1, minutes: 2, seconds: 3));
      expect(parseIsoDuration('PT45S'), const Duration(seconds: 45));
      expect(parseIsoDuration('P0D'), Duration.zero);
      expect(parseIsoDuration('nonsense'), isNull);
    });

    test('decodeHtmlEntities', () {
      expect(decodeHtmlEntities('Rock &amp; Roll &#39;n&#x27; &quot;Blues&quot;'), 'Rock & Roll \'n\' "Blues"');
    });

    test('cleanArtistName strips "- Topic"', () {
      expect(cleanArtistName('Daft Punk - Topic'), 'Daft Punk');
      expect(cleanArtistName('Some Artist'), 'Some Artist');
      expect(cleanArtistName(''), 'Unknown artist');
    });
  });

  group('trackFromVideoJson (music-only filtering)', () {
    test('maps a normal music video', () {
      final t = trackFromVideoJson(video('abc', title: 'Hello &amp; Goodbye', channel: 'Band - Topic'))!;
      expect(t.providerName, 'YouTube');
      expect(t.providerId, 'abc');
      expect(t.title, 'Hello & Goodbye');
      expect(t.artistName, 'Band');
      expect(t.durationMs, 204000);
      expect(t.artworkUrl, 'https://img/abc/high.jpg');
      expect(t.attributionUrl, 'https://www.youtube.com/watch?v=abc');
    });

    test('rejects non-embeddable, non-music, live, private, too long and zero-length videos', () {
      expect(trackFromVideoJson(video('a', embeddable: false)), isNull);
      expect(trackFromVideoJson(video('a', category: '20')), isNull);
      expect(trackFromVideoJson(video('a', live: 'live')), isNull);
      expect(trackFromVideoJson(video('a', privacy: 'private')), isNull);
      expect(trackFromVideoJson(video('a', duration: 'PT1H30M')), isNull);
      expect(trackFromVideoJson(video('a', duration: 'P0D')), isNull);
    });
  });

  group('YouTubeMusicProvider', () {
    test('search asks the API for embeddable Music-category videos and keeps relevance order', () async {
      final requests = <Uri>[];
      final client = MockClient((request) async {
        requests.add(request.url);
        if (request.url.path.endsWith('/search')) {
          return jsonResponse({
            'items': [
              {'id': {'videoId': 'b'}},
              {'id': {'videoId': 'a'}},
              {'id': {'videoId': 'x'}}, // dropped later: not returned by videos.list
            ],
          });
        }
        return jsonResponse({
          'items': [video('a', title: 'A'), video('b', title: 'B'), video('c', title: 'C', embeddable: false)],
        });
      });
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: client);

      final tracks = await provider.searchTracks('  lo fi ');
      expect(tracks.map((t) => t.title), ['B', 'A']);

      final search = requests.firstWhere((u) => u.path.endsWith('/search'));
      expect(search.host, 'www.googleapis.com');
      expect(search.queryParameters['videoCategoryId'], '10');
      expect(search.queryParameters['type'], 'video');
      expect(search.queryParameters['videoEmbeddable'], 'true');
      expect(search.queryParameters['q'], 'lo fi');
      expect(search.queryParameters['key'], 'KEY');

      final details = requests.firstWhere((u) => u.path.endsWith('/videos'));
      expect(details.queryParameters['id'], 'b,a,x');
    });

    test('repeating a search is served from the in-memory cache (saves quota)', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/search')) {
          return jsonResponse({
            'items': [
              {'id': {'videoId': 'a'}}
            ],
          });
        }
        return jsonResponse({
          'items': [video('a')],
        });
      });
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: client);
      await provider.searchTracks('Lo Fi');
      final callsAfterFirst = calls;
      await provider.searchTracks('lo fi');
      expect(calls, callsAfterFirst);
    });

    test('a blank query makes no request', () async {
      final client = MockClient((request) async => fail('no request expected'));
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: client);
      expect(await provider.searchTracks('   '), isEmpty);
    });

    test('quota errors become RateLimitException; key errors become ProviderConfigException', () async {
      var provider = YouTubeMusicProvider(
        apiKey: 'KEY',
        client: MockClient((_) async => apiError(403, 'quotaExceeded')),
      );
      await expectLater(provider.searchTracks('x'), throwsA(isA<RateLimitException>()));

      provider = YouTubeMusicProvider(
        apiKey: 'KEY',
        client: MockClient((_) async => apiError(400, 'keyInvalid')),
      );
      await expectLater(provider.searchTracks('x'), throwsA(isA<ProviderConfigException>()));
    });

    test('network failures and bad bodies map to typed errors', () async {
      var provider = YouTubeMusicProvider(
        apiKey: 'KEY',
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      await expectLater(provider.searchTracks('x'), throwsA(isA<NetworkException>()));

      provider = YouTubeMusicProvider(
        apiKey: 'KEY',
        client: MockClient((_) async => http.Response('not json', 200)),
      );
      await expectLater(provider.searchTracks('x'), throwsA(isA<MalformedResponseException>()));
    });

    test('featured content uses the Music chart and falls back to US when the region has none', () async {
      final regions = <String>[];
      final client = MockClient((request) async {
        final region = request.url.queryParameters['regionCode']!;
        regions.add(region);
        expect(request.url.queryParameters['chart'], 'mostPopular');
        expect(request.url.queryParameters['videoCategoryId'], '10');
        if (region == 'PH') return apiError(404, 'videoChartNotFound');
        return jsonResponse({
          'items': [for (var i = 0; i < 12; i++) video('v$i', title: 'Hit $i')],
        });
      });
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: client, regionCode: 'PH');

      final sections = await provider.getFeaturedContent();
      expect(regions, ['PH', 'US']);
      expect(sections.first.title, contains('US'));
      expect(sections.first.tracks, hasLength(10));
      expect(sections.last.tracks, hasLength(2));
    });

    test('getTrackDetails returns null for unavailable videos', () async {
      final provider = YouTubeMusicProvider(
        apiKey: 'KEY',
        client: MockClient((_) async => jsonResponse({'items': []})),
      );
      expect(await provider.getTrackDetails('gone'), isNull);
    });

    test('playback goes through the YouTube player, never a stream URL', () async {
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: MockClient((_) async => jsonResponse({})));
      final source = await provider.resolvePlayableSource('abc123');
      expect(source.youtubeVideoId, 'abc123');
      expect(source.uri, isNull);
      expect(source.isSimulated, isFalse);
    });

    test('Android restriction headers are sent only when configured', () async {
      final seen = <Map<String, String>>[];
      final client = MockClient((request) async {
        seen.add(request.headers);
        return jsonResponse({'items': []});
      });
      await YouTubeMusicProvider(apiKey: 'KEY', client: client).getTrackDetails('a');
      await YouTubeMusicProvider(
        apiKey: 'KEY',
        client: client,
        androidPackage: 'com.example.click',
        androidCertSha1: 'ABCDEF',
      ).getTrackDetails('a');
      expect(seen.first.containsKey('X-Android-Package'), isFalse);
      expect(seen.last['X-Android-Package'], 'com.example.click');
      expect(seen.last['X-Android-Cert'], 'ABCDEF');
    });

    test('discloses YouTube terms and is metered', () {
      final provider = YouTubeMusicProvider(apiKey: 'KEY', client: MockClient((_) async => jsonResponse({})));
      expect(provider.attributionText, contains('YouTube Terms of Service'));
      expect(provider.attributionUrl, YouTubeMusicProvider.termsUrl);
      expect(provider.searchIsMetered, isTrue);
      expect(provider.isSample, isFalse);
    });
  });
}
