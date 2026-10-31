/// Repeat modes exposed by the player (SRS FR-PLAY-05).
enum RepeatMode {
  off,
  all,
  one;

  RepeatMode get next => RepeatMode.values[(index + 1) % RepeatMode.values.length];

  String get label => switch (this) {
        RepeatMode.off => 'Off',
        RepeatMode.all => 'All',
        RepeatMode.one => 'One',
      };

  static RepeatMode parse(String? value) =>
      RepeatMode.values.firstWhere((m) => m.name == value, orElse: () => RepeatMode.off);
}
