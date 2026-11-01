import 'dart:math';

/// YouTube requires an embedded viewport of at least 200x200 px.
const double youtubeMinPlayerEdge = 200;

/// Gap between the compact player and the screen edge.
const double youtubeDockMargin = 8;

/// Height of the drag grip above the player (outside the 200x200 video area).
const double youtubeDockHandleHeight = 28;

/// Space reserved below the player for the mini-player and navigation bar
/// (M3 NavigationBar 80 + mini-player ~76 + breathing room).
const double youtubeDockBottomReserve = 172;

/// Size of the compact YouTube player: exactly the 200x200 px minimum, or the
/// available width on a screen narrower than that. It is a small floating
/// square that can be dragged around; it is never made smaller.
({double width, double height}) youtubeDockSize(double screenWidth, double screenHeight) {
  final edge = max(youtubeMinPlayerEdge, min(youtubeMinPlayerEdge, screenWidth - 2 * youtubeDockMargin));
  return (width: edge, height: edge);
}
