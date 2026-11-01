import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_provider.dart';

/// Audio-only catalog backed by the Jamendo API v3 (independent artists, mostly
/// Creative Commons). Unlike YouTube, Jamendo returns a plain audio stream URL,
/// so tracks play in CLICK's own player with no video.
///
/// The `client_id` is a free developer id from the Jamendo developer portal. It
/// is supplied at build time (JAMENDO_CLIENT_ID) and never committed.
class JamendoMusicProvider implements MusicProvider {
  JamendoMusicProvider({
    required this.clientId,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
    this.pageSize = 30,
  }) : _client = client ?? http.Client();

  static const providerName = 'Jamendo';
  static const siteUrl = 'https://www.jamendo.com';
  static const _host = 'api.jamendo.com';

  final String clientId;
  final Duration timeout;
  final int pageSize;
  final http.Client _client;

  void close() => _client.close();

  @override
  String get name => providerName;

  @override
  String get attributionText =>
      'Music from Jamendo, streamed as audio only. Tracks are released by independent artists, '
      'usually under Creative Commons licenses; open a track on Jamendo ($siteUrl) to see its license '
      'and credit the artist when you reuse it. Availability is controlled by Jamendo.';

  @override
  String? get attributionUrl => siteUrl;

  @override
  bool get isSample => false;

  @override
  bool get supportsDiscovery => true;

  @override
  bool get searchIsMetered => false;

  @override
  String? get playbackNotice => null;

  // --- catalog -------------------------------------------------------------

  @override
  Future<List<Track>> searchTracks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final json = await _get('tracks', {
      'search': q,
      'limit': '$pageSize',
      'audioformat': 'mp32',
      'imagesize': '300',
    });
    return _tracksFrom(json);
  }

  @override
  Future<Track?> getTrackDetails(String id) async {
    final json = await _get('tracks', {'id': id, 'audioformat': 'mp32', 'imagesize': '300'});
    final tracks = _tracksFrom(json);
    return tracks.isEmpty ? null : tracks.first;
  }

  @override
  Future<List<TrackSection>> getFeaturedContent() async {
    final json = await _get('tracks', {
      'order': 'popularity_week',
      'limit': '$pageSize',
      'audioformat': 'mp32',
      'imagesize': '300',
    });
    final tracks = _tracksFrom(json);
    if (tracks.isEmpty) return const [];
    final first = tracks.take(10).toList();
    final rest = tracks.skip(10).toList();
    return [
      TrackSection(title: 'Popular this week · Jamendo', tracks: first),
      if (rest.isNotEmpty) TrackSection(title: 'More popular tracks', tracks: rest),
    ];
  }

  /// Looks the stream URL up at play time; it is never stored (SRS 7.2).
  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async {
    final json = await _get('tracks', {'id': trackId, 'audioformat': 'mp32'});
    final results = _mapList(json['results']);
    final audio = results.isEmpty ? null : results.first['audio'];
    final uri = audio is String && audio.isNotEmpty ? Uri.tryParse(audio) : null;
    if (uri == null || !uri.hasScheme) throw const ProviderUnavailableException();
    return PlayableSource.stream(uri);
  }

  // --- helpers -------------------------------------------------------------

  List<Track> _tracksFrom(Map<String, dynamic> json) {
    final tracks = <Track>[];
    for (final item in _mapList(json['results'])) {
      final track = trackFromJamendoJson(item);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.https(_host, '/v3.0/$path/', {'client_id': clientId, 'format': 'json', ...params});
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 429) throw const RateLimitException();
    if (response.statusCode == 401 || response.statusCode == 403) throw const ProviderConfigException(_badClientId);
    if (response.statusCode >= 500) throw const NetworkException('Jamendo is having problems. Try again later.');
    if (response.statusCode != 200) {
      throw const MalformedResponseException('Jamendo returned an unexpected error. Try again later.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException {
      throw const MalformedResponseException();
    }
    if (decoded is! Map<String, dynamic>) throw const MalformedResponseException();

    // Jamendo reports API-level failures inside a 200 response: headers.code != 0.
    final headers = decoded['headers'];
    if (headers is Map) {
      final code = headers['code'];
      final status = '${headers['status']}';
      if ((code is num && code != 0) || status == 'failed') {
        final message = '${headers['error_message'] ?? ''}'.toLowerCase();
        if (message.contains('client_id') || message.contains('client id') || message.contains('invalid')) {
          throw const ProviderConfigException(_badClientId);
        }
        if (message.contains('limit') || message.contains('too many')) throw const RateLimitException();
        throw const MalformedResponseException('Jamendo returned an unexpected error. Try again later.');
      }
    }
    return decoded;
  }

  static const _badClientId = 'Jamendo rejected CLICK\'s client id. Check JAMENDO_CLIENT_ID in secrets.json.';

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return [for (final e in value) if (e is Map<String, dynamic>) e];
  }
}

/// Converts one Jamendo track object to a [Track], or null if it has no usable
/// id or title.
Track? trackFromJamendoJson(Map<String, dynamic> item) {
  final id = '${item['id'] ?? ''}'.trim();
  final title = '${item['name'] ?? ''}'.trim();
  if (id.isEmpty || title.isEmpty) return null;

  final artist = '${item['artist_name'] ?? ''}'.trim();
  final album = '${item['album_name'] ?? ''}'.trim();
  final image = item['image'] ?? item['album_image'];
  final seconds = item['duration'] is num ? (item['duration'] as num).toInt() : int.tryParse('${item['duration']}');
  final share = item['shareurl'];

  return Track(
    providerName: JamendoMusicProvider.providerName,
    providerId: id,
    title: title,
    artistName: artist.isEmpty ? 'Unknown artist' : artist,
    albumTitle: album.isEmpty ? null : album,
    artworkUrl: image is String && image.isNotEmpty ? image : null,
    durationMs: seconds != null && seconds > 0 ? seconds * 1000 : null,
    attributionUrl: share is String && share.isNotEmpty ? share : 'https://www.jamendo.com/track/$id',
  );
}
