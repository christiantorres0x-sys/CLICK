import 'dart:convert';

import 'package:click/core/errors/app_exception.dart';
import 'package:click/data/providers/jamendo_music_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> jTrack(String id, {String name = 'Song', String audio = 'https://stream.example/a.mp3'}) => {
      'id': id,
      'name': name,
      'artist_name': 'Artist',
      'album_name': 'Album',
      'duration': 215,
      'image': 'https://img.example/$id.jpg',
      'audio': audio,
      'shareurl': 'https://www.jamendo.com/track/$id',
    };

http.Response ok(List<Map<String, dynamic>> results, {int code = 0, String message = ''}) => http.Response(
      jsonEncode({
        'headers': {'status': code == 0 ? 'success' : 'failed', 'code': code, 'error_message': message},
        'results': results,
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  JamendoMusicProvider make(MockClientHandler handler) =>
      JamendoMusicProvider(clientId: 'test-id', client: MockClient(handler));

  test('trackFromJamendoJson maps fields and converts seconds to milliseconds', () {
    final t = trackFromJamendoJson(jTrack('7'))!;
    expect(t.providerName, 'Jamendo');
    expect(t.providerId, '7');
    expect(t.title, 'Song');
    expect(t.artistName, 'Artist');
    expect(t.albumTitle, 'Album');
    expect(t.durationMs, 215000);
    expect(t.artworkUrl, 'https://img.example/7.jpg');
    expect(t.attributionUrl, 'https://www.jamendo.com/track/7');
  });

  test('tracks without an id or title are dropped', () {
    expect(trackFromJamendoJson({'id': '', 'name': 'x'}), isNull);
    expect(trackFromJamendoJson({'id': '1', 'name': ' '}), isNull);
  });

  test('search sends the client id and query and returns tracks', () async {
    late Uri seen;
    final p = make((req) async {
      seen = req.url;
      return ok([jTrack('1'), jTrack('2')]);
    });
    final tracks = await p.searchTracks('  lofi ');
    expect(tracks.map((t) => t.providerId), ['1', '2']);
    expect(seen.host, 'api.jamendo.com');
    expect(seen.path, '/v3.0/tracks/');
    expect(seen.queryParameters['client_id'], 'test-id');
    expect(seen.queryParameters['search'], 'lofi');
    expect(seen.queryParameters['format'], 'json');
  });

  test('an empty query makes no request', () async {
    final p = make((req) async => fail('no request expected'));
    expect(await p.searchTracks('   '), isEmpty);
  });

  test('featured content is split into sections', () async {
    final p = make((req) async => ok([for (var i = 0; i < 14; i++) jTrack('$i')]));
    final sections = await p.getFeaturedContent();
    expect(sections.length, 2);
    expect(sections.first.tracks.length, 10);
    expect(sections.last.tracks.length, 4);
  });

  test('resolvePlayableSource returns the audio stream URL', () async {
    final p = make((req) async => ok([jTrack('9', audio: 'https://stream.example/9.mp3')]));
    final source = await p.resolvePlayableSource('9');
    expect(source.uri, Uri.parse('https://stream.example/9.mp3'));
    expect(source.youtubeVideoId, isNull);
    expect(source.isSimulated, isFalse);
  });

  test('a stream URL from search results is used once, then a retry asks Jamendo again', () async {
    var requests = 0;
    final p = make((req) async {
      requests++;
      return ok([jTrack('5', audio: 'https://stream.example/5-$requests.mp3')]);
    });
    await p.searchTracks('x'); // request 1, remembers the URL
    final first = await p.resolvePlayableSource('5'); // no request
    expect(first.uri, Uri.parse('https://stream.example/5-1.mp3'));
    expect(requests, 1);
    final retry = await p.resolvePlayableSource('5'); // fresh request
    expect(requests, 2);
    expect(retry.uri, Uri.parse('https://stream.example/5-2.mp3'));
  });

  test('a track with no stream URL is unavailable', () async {
    final p = make((req) async => ok([jTrack('9', audio: '')]));
    expect(p.resolvePlayableSource('9'), throwsA(isA<ProviderUnavailableException>()));
    final none = make((req) async => ok([]));
    expect(none.resolvePlayableSource('9'), throwsA(isA<ProviderUnavailableException>()));
  });

  test('errors are mapped to typed exceptions', () async {
    expect(make((r) async => http.Response('', 429)).searchTracks('a'), throwsA(isA<RateLimitException>()));
    expect(make((r) async => http.Response('', 503)).searchTracks('a'), throwsA(isA<NetworkException>()));
    expect(make((r) async => http.Response('not json', 200)).searchTracks('a'),
        throwsA(isA<MalformedResponseException>()));
    expect(make((r) async => ok([], code: 5, message: 'Invalid client_id')).searchTracks('a'),
        throwsA(isA<ProviderConfigException>()));
    expect(make((r) async => throw http.ClientException('offline')).searchTracks('a'),
        throwsA(isA<NetworkException>()));
  });
}
