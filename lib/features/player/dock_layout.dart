import 'dart:math';

/// YouTube requires an embedded viewport of at least 200x200 px.
const double youtubeMinPlayerEdge = 200;

/// Size of the pinned YouTube player for a screen of [screenWidth] x [screenHeight].
///
/// * Portrait: full width at 16:9.
/// * Narrow phones, where 16:9 would be shorter than 200 px: height is raised to
///   200 px and the player keeps the full width (slightly less wide than 16:9).
/// * Landscape: the player would otherwise be taller than the screen, so its
///   height is capped at 45% of the screen, but never below 200 px.
///
/// The width never exceeds the screen width.
({double width, double height}) youtubeDockSize(double screenWidth, double screenHeight) {
  final cap = max(youtubeMinPlayerEdge, screenHeight * 0.45);
  final height = min(max(screenWidth * 9 / 16, youtubeMinPlayerEdge), cap);
  final width = min(screenWidth, height * 16 / 9);
  return (width: width, height: height);
}
