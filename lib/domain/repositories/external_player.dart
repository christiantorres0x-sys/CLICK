/// Port for a player that runs outside CLICK's simulated clock, such as the
/// official YouTube embedded player. The playback controller stays the single
/// owner of queue and state (SRS 9.2); this only reports what the player does.
enum ExternalPlayerState { buffering, playing, paused, ended }

sealed class ExternalPlayerEvent {
  const ExternalPlayerEvent();
}

class ExternalStateChanged extends ExternalPlayerEvent {
  const ExternalStateChanged(this.playerState);
  final ExternalPlayerState playerState;
}

class ExternalPositionChanged extends ExternalPlayerEvent {
  const ExternalPositionChanged(this.position);
  final Duration position;
}

class ExternalPlayerError extends ExternalPlayerEvent {
  const ExternalPlayerError(this.message, {this.unavailable = true});
  final String message;

  /// True when the item cannot be played at all (e.g. embedding disabled).
  final bool unavailable;
}

/// What an engine may show in the system notification / lock screen. Engines
/// that have no such surface (the YouTube player) ignore it.
class MediaInfo {
  const MediaInfo({required this.id, required this.title, required this.artist, this.album, this.artworkUrl});
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? artworkUrl;
}

abstract class ExternalPlayer {
  Stream<ExternalPlayerEvent> get events;

  /// Loads [sourceId] and starts playing it.
  Future<void> load(String sourceId, {MediaInfo? info});
  Future<void> play();
  Future<void> pause();

  /// Stops playback and releases the current item (closes the player).
  Future<void> stop();
  Future<void> seekTo(Duration position);
}
