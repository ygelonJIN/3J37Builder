// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in a test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:builder_3j37/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const Builder3J37App());

    // Verify that the app launches successfully.
    expect(find.text('3J37 BUILDER'), findsOneWidget);
  });
}
