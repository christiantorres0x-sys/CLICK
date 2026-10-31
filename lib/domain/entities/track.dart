/// A playable music item and its metadata (SRS 1.3, 7.1).
///
/// Stores stable provider identifiers only. Stream URLs are never part of a
/// Track and are never persisted (SRS 7.2).
class Track {
  const Track({
    required this.providerName,
    required this.providerId,
    required this.title,
    required this.artistName,
    this.albumTitle,
    this.artworkUrl,
    this.durationMs,
    this.attributionUrl,
  });

  final String providerName;
  final String providerId;
  final String title;
  final String artistName;
  final String? albumTitle;
  final String? artworkUrl;
  final int? durationMs;
  final String? attributionUrl;

  /// Provider-qualified identity, avoids collisions between catalogs (SRS 7.2).
  String get key => '$providerName:$providerId';

  Duration? get duration => durationMs == null ? null : Duration(milliseconds: durationMs!);

  Map<String, Object?> toJson() => {
        'providerName': providerName,
        'providerId': providerId,
        'title': title,
        'artistName': artistName,
        'albumTitle': albumTitle,
        'artworkUrl': artworkUrl,
        'durationMs': durationMs,
        'attributionUrl': attributionUrl,
      };

  factory Track.fromJson(Map<String, Object?> json) => Track(
        providerName: json['providerName']! as String,
        providerId: json['providerId']! as String,
        title: json['title']! as String,
        artistName: json['artistName']! as String,
        albumTitle: json['albumTitle'] as String?,
        artworkUrl: json['artworkUrl'] as String?,
        durationMs: json['durationMs'] as int?,
        attributionUrl: json['attributionUrl'] as String?,
      );

  @override
  bool operator ==(Object other) => other is Track && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A titled group of tracks for the Home screen.
class TrackSection {
  const TrackSection({required this.title, required this.tracks});
  final String title;
  final List<Track> tracks;
}
