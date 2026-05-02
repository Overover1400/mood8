import 'package:flutter_test/flutter_test.dart';

import 'package:mood8/main.dart';

void main() {
  testWidgets('Mood8 home screen renders', (WidgetTester tester) async {
    await tester.pumpWidget(const Mood8App());
    await tester.pump();

    expect(find.text('Save check-in'), findsOneWidget);
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Energy'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
  });
}
