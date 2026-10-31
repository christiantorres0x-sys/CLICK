import 'package:flutter/material.dart';

import '../../domain/entities/track.dart';

/// Square cover art. Falls back to a generated gradient when the track has no
/// artwork or the image fails to load (NFR-REL: missing artwork must not crash).
class Artwork extends StatelessWidget {
  const Artwork({super.key, required this.track, this.size, this.radius = 10});

  final Track track;

  /// Fixed edge length, or null to fill the parent's constraints.
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = track.artworkUrl;
    final placeholder = _Placeholder(seed: track.key, iconSize: (size ?? 120) * 0.45);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: size,
          height: size,
          child: url == null
              ? placeholder
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.seed, required this.iconSize});

  final String seed;
  final double iconSize;

  static int _stableHash(String s) {
    var h = 7;
    for (final unit in s.codeUnits) {
      h = (h * 31 + unit) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final hue = (_stableHash(seed) % 360).toDouble();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.55, 0.32).toColor(),
            HSLColor.fromAHSL(1, (hue + 50) % 360, 0.6, 0.20).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded, size: iconSize, color: const Color(0x99FFFFFF)),
      ),
    );
  }
}
