import 'package:click/features/player/dock_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('portrait phone: full width at 16:9, at least 200 px tall', () {
    final size = youtubeDockSize(360, 800);
    expect(size.width, 360);
    expect(size.height, closeTo(202.5, 0.01));
    expect(size.height, greaterThanOrEqualTo(youtubeMinPlayerEdge));
  });

  test('narrow phone: raised to the 200 px minimum height, still full width', () {
    final size = youtubeDockSize(320, 640);
    expect(size.height, youtubeMinPlayerEdge);
    expect(size.width, 320);
  });

  test('landscape phone: capped so it fits, but never below the 200 px minimum', () {
    final size = youtubeDockSize(800, 360);
    expect(size.height, youtubeMinPlayerEdge);
    expect(size.width, closeTo(200 * 16 / 9, 0.01));
    expect(size.height, lessThan(360));
  });

  test('large screen: capped at 45% of the height, 16:9, centered width', () {
    final size = youtubeDockSize(1200, 1000);
    expect(size.height, 450);
    expect(size.width, 800);
  });

  test('never smaller than 200x200 and never wider than the screen', () {
    for (final (w, h) in [(320.0, 640.0), (360.0, 800.0), (412.0, 915.0), (915.0, 412.0), (1280.0, 800.0)]) {
      final size = youtubeDockSize(w, h);
      expect(size.height, greaterThanOrEqualTo(youtubeMinPlayerEdge));
      expect(size.width, greaterThanOrEqualTo(youtubeMinPlayerEdge));
      expect(size.width, lessThanOrEqualTo(w));
    }
  });
}
