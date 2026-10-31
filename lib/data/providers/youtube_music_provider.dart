import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_provider.dart';

/// Music catalog backed by the YouTube Data API v3 (documented endpoints only,
/// SRS FR-PROV-02). Audio is never fetched by CLICK: playback goes through the
/// official YouTube embedded player (see YoutubeIframePlayer).
///
/// Quota: the default project quota allows only about 100 searches per day,
/// so searches are cached in memory and the UI submits them explicitly.
class YouTubeMusicProvider implements MusicProvider {
  YouTubeMusicProvider({
    required this.apiKey,
    http.Client? client,
    this.regionCode = 'PH',
    this.androidPackage,
    this.androidCertSha1,
    this.maxDuration = const Duration(minutes: 15),
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  static const providerName = 'YouTube';

  /// YouTube's "Music" video category.
  static const musicCategoryId = '10';
  static const termsUrl = 'https://www.youtube.com/t/terms';
  static const privacyUrl = 'https://policies.google.com/privacy';
  static const _maxCachedSearches = 30;

  final String apiKey;
  final String regionCode;

  /// Only needed if the API key is restricted to an Android app.
  final String? androidPackage;
  final String? androidCertSha1;

  /// Longer videos (mixes, full albums, live streams) are filtered out.
  final Duration maxDuration;
  final Duration timeout;

  final http.Client _client;
  final Map<String, List<Track>> _searchCache = {};

  void close() => _client.close();

  @override
  String get name => providerName;

  @override
  String get attributionText =>
      'Music from YouTube, via the YouTube Data API and the YouTube embedded player. Only music videos '
      'that YouTube allows to be embedded are shown. Availability, ads and playback are controlled by '
      'YouTube. By using CLICK you agree to the YouTube Terms of Service ($termsUrl) and the Google '
      'Privacy Policy ($privacyUrl).';

  @override
  String? get attributionUrl => termsUrl;

  @override
  bool get isSample => false;

  @override
  bool get supportsDiscovery => true;

  @override
  bool get searchIsMetered => true;

  @override
  String? get playbackNotice =>
      'Playing through the YouTube player. It must stay visible, and playback pauses when CLICK is in the background.';

  // --- catalog -------------------------------------------------------------

  @override
  Future<List<Track>> searchTracks(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final cacheKey = q.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;

    final json = await _get('search', {
      'part': 'snippet',
      'type': 'video',
      'videoCategoryId': musicCategoryId,
      'videoEmbeddable': 'true',
      'videoSyndicated': 'true',
      'regionCode': regionCode,
      'maxResults': '25',
      'q': q,
    });

    final ids = <String>[];
    for (final item in _mapList(json['items'])) {
      final id = (item['id'] is Map) ? (item['id'] as Map)['videoId'] : null;
      if (id is String) ids.add(id);
    }
    final tracks = ids.isEmpty ? <Track>[] : await _loadVideos(ids);

    if (_searchCache.length >= _maxCachedSearches) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[cacheKey] = tracks;
    return tracks;
  }

  @override
  Future<Track?> getTrackDetails(String id) async {
    final tracks = await _loadVideos([id]);
    return tracks.isEmpty ? null : tracks.first;
  }

  @override
  Future<List<TrackSection>> getFeaturedContent() async {
    List<Track> tracks;
    var region = regionCode;
    try {
      tracks = await _mostPopularMusic(region);
    } on ProviderUnavailableException {
      // Some regions have no music chart; fall back to a widely supported one.
      if (region == 'US') rethrow;
      region = 'US';
      tracks = await _mostPopularMusic(region);
    }
    if (tracks.isEmpty) return const [];
    final first = tracks.take(10).toList();
    final rest = tracks.skip(10).take(15).toList();
    return [
      TrackSection(title: 'Trending music · $region', tracks: first),
      if (rest.isNotEmpty) TrackSection(title: 'More trending', tracks: rest),
    ];
  }

  /// The video is played by the YouTube player; CLICK never touches the stream.
  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async => PlayableSource.youtube(trackId);

  // --- helpers -------------------------------------------------------------

  Future<List<Track>> _mostPopularMusic(String region) async {
    final json = await _get('videos', {
      'part': 'snippet,contentDetails,status',
      'chart': 'mostPopular',
      'videoCategoryId': musicCategoryId,
      'regionCode': region,
      'maxResults': '30',
    });
    return _tracksFromVideos(_mapList(json['items']));
  }

  /// videos.list for [ids]; keeps the order of [ids] (search relevance).
  Future<List<Track>> _loadVideos(List<String> ids) async {
    final json = await _get('videos', {
      'part': 'snippet,contentDetails,status',
      'id': ids.join(','),
      'maxResults': '50',
    });
    final byId = {for (final t in _tracksFromVideos(_mapList(json['items']))) t.providerId: t};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  List<Track> _tracksFromVideos(List<Map<String, dynamic>> items) {
    final tracks = <Track>[];
    for (final item in items) {
      final track = trackFromVideoJson(item, maxDuration: maxDuration);
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  Map<String, String> get _headers => {
        if (androidPackage != null) 'X-Android-Package': androidPackage!,
        if (androidCertSha1 != null) 'X-Android-Cert': androidCertSha1!,
      };

  Future<Map<String, dynamic>> _get(String path, Map<String, String> params) async {
    final uri = Uri.https('www.googleapis.com', '/youtube/v3/$path', {...params, 'key': apiKey});
    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const NetworkException();
    } on http.ClientException {
      throw const NetworkException();
    }

    if (response.statusCode == 200) {
      try {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is Map<String, dynamic>) return decoded;
      } on FormatException {
        // fall through to the malformed-response error
      }
      throw const MalformedResponseException();
    }
    throw _errorFor(response);
  }

  AppException _errorFor(http.Response response) {
    String? reason;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final errors = (decoded is Map && decoded['error'] is Map) ? (decoded['error'] as Map)['errors'] : null;
      if (errors is List && errors.isNotEmpty && errors.first is Map) {
        reason = (errors.first as Map)['reason']?.toString();
      }
    } catch (_) {
      // Non-JSON error body: use the status code only.
    }
    switch (reason) {
      case 'quotaExceeded':
      case 'dailyLimitExceeded':
      case 'rateLimitExceeded':
      case 'userRateLimitExceeded':
        return const RateLimitException(
          'The YouTube daily limit has been reached. Try again tomorrow (the quota resets at midnight Pacific Time).',
        );
      case 'keyInvalid':
      case 'accessNotConfigured':
      case 'ipRefererBlocked':
      case 'forbidden':
        return const ProviderConfigException();
      case 'videoChartNotFound':
      case 'notFound':
        return const ProviderUnavailableException();
    }
    if (response.statusCode == 400 && reason == 'badRequest') return const ProviderConfigException();
    if (response.statusCode == 404) return const ProviderUnavailableException();
    if (response.statusCode >= 500) return const NetworkException('YouTube is having problems. Try again later.');
    return const MalformedResponseException('YouTube returned an unexpected error. Try again later.');
  }

  static List<Map<String, dynamic>> _mapList(Object? value) {
    if (value is! List) return const [];
    return [for (final e in value) if (e is Map<String, dynamic>) e];
  }
}

/// Converts one `videos.list` item to a [Track], or null if it must not be
/// shown: not embeddable, not in the Music category, a live stream, or longer
/// than [maxDuration].
Track? trackFromVideoJson(Map<String, dynamic> item, {Duration maxDuration = const Duration(minutes: 15)}) {
  final id = item['id'];
  final snippet = item['snippet'];
  if (id is! String || snippet is! Map) return null;

  final status = item['status'];
  if (status is Map && status['embeddable'] == false) return null;
  if (status is Map && status['privacyStatus'] != null && status['privacyStatus'] != 'public') return null;

  final categoryId = snippet['categoryId'];
  if (categoryId != null && categoryId != YouTubeMusicProvider.musicCategoryId) return null;
  if (snippet['liveBroadcastContent'] != null && snippet['liveBroadcastContent'] != 'none') return null;

  final contentDetails = item['contentDetails'];
  final duration = contentDetails is Map ? parseIsoDuration('${contentDetails['duration']}') : null;
  if (duration == null || duration <= Duration.zero || duration > maxDuration) return null;

  final title = decodeHtmlEntities('${snippet['title'] ?? ''}').trim();
  if (title.isEmpty) return null;
  final channel = decodeHtmlEntities('${snippet['channelTitle'] ?? ''}').trim();

  return Track(
    providerName: YouTubeMusicProvider.providerName,
    providerId: id,
    title: title,
    artistName: cleanArtistName(channel),
    artworkUrl: _bestThumbnail(snippet['thumbnails']),
    durationMs: duration.inMilliseconds,
    attributionUrl: 'https://www.youtube.com/watch?v=$id',
  );
}

String? _bestThumbnail(Object? thumbnails) {
  if (thumbnails is! Map) return null;
  for (final key in const ['high', 'medium', 'standard', 'default']) {
    final entry = thumbnails[key];
    if (entry is Map && entry['url'] is String) return entry['url'] as String;
  }
  return null;
}

/// "Artist - Topic" auto-generated channels become just "Artist".
String cleanArtistName(String channelTitle) {
  final cleaned = channelTitle.replaceFirst(RegExp(r'\s*-\s*Topic$'), '').trim();
  return cleaned.isEmpty ? 'Unknown artist' : cleaned;
}

/// Parses an ISO 8601 duration such as PT3M24S or PT1H2M3S. Returns null if invalid.
Duration? parseIsoDuration(String value) {
  final m = RegExp(r'^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$').firstMatch(value);
  if (m == null) return null;
  int part(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  return Duration(days: part(1), hours: part(2), minutes: part(3), seconds: part(4));
}

/// The search API returns titles with HTML entities (e.g. &amp;, &#39;).
String decodeHtmlEntities(String input) {
  var out = input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'");
  out = out.replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m.group(1)!)));
  out = out.replaceAllMapped(
    RegExp(r'&#[xX]([0-9a-fA-F]+);'),
    (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
  );
  return out;
}
