import '../entities/track.dart';

/// What the player needs to start audio. Never persisted (SRS 7.2).
class PlayableSource {
  const PlayableSource.stream(this.uri)
      : isSimulated = false,
        youtubeVideoId = null;

  /// Used only by the labeled sample provider: there is no audio to stream.
  const PlayableSource.simulated()
      : uri = null,
        isSimulated = true,
        youtubeVideoId = null;

  /// Played through the official YouTube embedded player (never extracted audio).
  const PlayableSource.youtube(String videoId)
      : uri = null,
        isSimulated = false,
        youtubeVideoId = videoId;

  final Uri? uri;
  final bool isSimulated;
  final String? youtubeVideoId;
}

/// Provider abstraction (SRS 9.3, FR-PROV-01). UI code talks to this interface,
/// never to a concrete service.
abstract class MusicProvider {
  String get name;

  /// Text shown in Settings and wherever attribution is required (FR-SET-02).
  String get attributionText;

  String? get attributionUrl;

  /// True for the built-in sample catalog, which has no real audio.
  bool get isSample;

  bool get supportsDiscovery;

  /// True when each search spends a scarce quota (e.g. YouTube). Search then
  /// runs only when the user submits, not while typing.
  bool get searchIsMetered;

  /// Short note shown on Now Playing about how playback works, or null.
  String? get playbackNotice;

  Future<List<Track>> searchTracks(String query);

  /// Returns null when the provider no longer offers the track.
  Future<Track?> getTrackDetails(String id);

  Future<List<TrackSection>> getFeaturedContent();

  /// Throws [ProviderUnavailableException] when no authorized source exists.
  Future<PlayableSource> resolvePlayableSource(String trackId);
}
