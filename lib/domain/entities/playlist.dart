class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.trackCount = 0,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int trackCount;
}
