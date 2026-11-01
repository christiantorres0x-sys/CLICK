import 'dart:math';

import 'package:click/app/theme/app_theme.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

double _luminance(Color c) {
  double channel(double v) => v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double contrast(Color a, Color b) {
  final hi = max(_luminance(a), _luminance(b));
  final lo = min(_luminance(a), _luminance(b));
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // WCAG AA for normal text is 4.5:1 (SRS Phase 7 accessibility).
  const surfaces = [ClickColors.background, ClickColors.surface, ClickColors.surfaceHigh];

  test('text and accent colors meet WCAG AA on every surface', () {
    for (final surface in surfaces) {
      for (final foreground in [
        ClickColors.textPrimary,
        ClickColors.textSecondary,
        ClickColors.accent,
        ClickColors.error,
      ]) {
        expect(contrast(foreground, surface), greaterThanOrEqualTo(4.5));
      }
    }
  });

  test('text on the accent color is readable', () {
    expect(contrast(ClickColors.onAccent, ClickColors.accent), greaterThanOrEqualTo(4.5));
  });
}
