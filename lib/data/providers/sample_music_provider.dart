import '../../core/errors/app_exception.dart';
import '../../domain/entities/track.dart';
import '../../domain/repositories/music_provider.dart';

/// Built-in demo catalog. It exists only because no real provider has passed
/// the SRS Phase 0 gate yet. All tracks are fictional and there is no audio:
/// playback is simulated by the player controller.
class SampleMusicProvider implements MusicProvider {
  SampleMusicProvider({this.latency = const Duration(milliseconds: 250)});

  /// Artificial delay so loading states are visible. Tests pass Duration.zero.
  final Duration latency;

  static const providerName = 'CLICK Sample Catalog';

  static final List<Track> catalog = List.unmodifiable([
    _t(1, 'Glass Orbit', 'Northern Static', 'Paper Satellites', 204),
    _t(2, 'Low Tide Signal', 'Northern Static', 'Paper Satellites', 228),
    _t(3, 'Paper Satellites', 'Northern Static', 'Paper Satellites', 242),
    _t(4, 'Afterimage', 'Northern Static', 'Paper Satellites', 177),
    _t(5, 'Slow Ferry', 'Velvet Harbor', 'Harbor Lights', 211),
    _t(6, 'Salt & Neon', 'Velvet Harbor', 'Harbor Lights', 195),
    _t(7, 'Midnight Tide Table', 'Velvet Harbor', 'Harbor Lights', 260),
    _t(8, 'Quiet Dock', 'Velvet Harbor', 'Harbor Lights', 169),
    _t(9, 'Folded Map', 'Lumen Park', 'Daybreak Maps', 185),
    _t(10, 'First Bus Out', 'Lumen Park', 'Daybreak Maps', 219),
    _t(11, 'Daybreak Maps', 'Lumen Park', 'Daybreak Maps', 238),
    _t(12, 'Sunroom Static', 'Lumen Park', 'Daybreak Maps', 163),
  ]);

  static Track _t(int n, String title, String artist, String album, int seconds) => Track(
        providerName: providerName,
        providerId: 'sample-${n.toString().padLeft(3, '0')}',
        title: title,
        artistName: artist,
        albumTitle: album,
        durationMs: seconds * 1000,
      );

  @override
  String get name => providerName;

  @override
  String get attributionText =>
      'Built-in demo data. All tracks, artists and albums are fictional and no audio is streamed. '
      'A real music provider has not been selected yet.';

  @override
  String? get attributionUrl => null;

  @override
  bool get isSample => true;

  @override
  bool get supportsDiscovery => true;

  Future<void> _simulateLatency() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  @override
  Future<List<Track>> searchTracks(String query) async {
    await _simulateLatency();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return catalog
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artistName.toLowerCase().contains(q) ||
            (t.albumTitle ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<Track?> getTrackDetails(String id) async {
    await _simulateLatency();
    for (final t in catalog) {
      if (t.providerId == id) return t;
    }
    return null;
  }

  @override
  Future<List<TrackSection>> getFeaturedContent() async {
    await _simulateLatency();
    final byAlbum = <String, List<Track>>{};
    for (final t in catalog) {
      (byAlbum[t.albumTitle!] ??= []).add(t);
    }
    return [
      TrackSection(
        title: 'Featured tracks',
        tracks: [catalog[0], catalog[4], catalog[8], catalog[2], catalog[6], catalog[10]],
      ),
      for (final e in byAlbum.entries)
        TrackSection(title: '${e.key} · ${e.value.first.artistName}', tracks: e.value),
    ];
  }

  @override
  Future<PlayableSource> resolvePlayableSource(String trackId) async {
    await _simulateLatency();
    final exists = catalog.any((t) => t.providerId == trackId);
    if (!exists) throw const ProviderUnavailableException();
    return const PlayableSource.simulated();
  }
}
