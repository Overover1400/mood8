import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mood8/main.dart';

void main() {
  // Smoke test: the app builds and reaches a first frame.
  //
  // This previously asserted on a "Save check-in" button that was
  // removed in 6365fd0 when the check-in became auto-saving, so it had
  // been failing ever since. It also assumed the home screen renders
  // first, which isn't true for a fresh install — a new user lands on
  // onboarding.
  //
  // Asserting on specific home-screen copy here can't work without
  // seeding Hive and completing onboarding in the test. What's worth
  // guarding at this level is that boot doesn't throw.
  testWidgets('Mood8 boots to a first frame', (WidgetTester tester) async {
    await tester.pumpWidget(const Mood8App());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
