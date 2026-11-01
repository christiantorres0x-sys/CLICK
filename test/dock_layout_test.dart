import 'package:click/features/player/dock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the compact player is a 200x200 square on every phone size', () {
    for (final (w, h) in [(320.0, 640.0), (360.0, 800.0), (412.0, 915.0), (915.0, 412.0), (1280.0, 800.0)]) {
      final size = youtubeDockSize(w, h);
      expect(size.width, youtubeMinPlayerEdge);
      expect(size.height, youtubeMinPlayerEdge);
    }
  });

  test('it never drops below YouTube\'s 200x200 minimum, even on a very narrow screen', () {
    final size = youtubeDockSize(210, 500);
    expect(size.width, greaterThanOrEqualTo(youtubeMinPlayerEdge));
    expect(size.height, greaterThanOrEqualTo(youtubeMinPlayerEdge));
  });
}
