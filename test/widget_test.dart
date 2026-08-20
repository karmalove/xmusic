import 'package:flutter_test/flutter_test.dart';
import 'package:xmusic/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const XmusicApp());
    expect(find.text('发现'), findsOneWidget);
  });
}
