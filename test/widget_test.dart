import 'package:click/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_container.dart';

void main() {
  testWidgets('shell shows Home, navigates tabs, and plays a track (FR-UI-02..04)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ClickApp()),
    );
    await tester.pumpAndSettle();

    // Home with the sample-catalog label and discovery content.
    expect(find.text('CLICK'), findsOneWidget);
    expect(find.textContaining('built-in sample catalog'), findsOneWidget);
    expect(find.text('Featured tracks'), findsOneWidget);

    // No mini-player before anything is playing.
    expect(find.byTooltip('Next track'), findsNothing);

    // Start a track from Home: the mini-player appears.
    await tester.tap(find.text('Glass Orbit').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byTooltip('Next track'), findsOneWidget);

    // Switching tabs keeps the playback session.
    await tester.tap(find.text('Library'));
    // pumpAndSettle would never finish: playback ticks keep scheduling frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Liked Songs'), findsOneWidget);
    expect(find.byTooltip('Next track'), findsOneWidget);

    // Dispose the tree so the simulated-playback timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
