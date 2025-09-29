
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptx_app/main.dart';

void main() {
  testWidgets('CryptX smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CryptXApp());

    // Wait for LoginScreen to load (optional)
    await tester.pumpAndSettle();

    // Check that a widget from LoginScreen exists
    expect(find.text('Login'), findsOneWidget);
  });
}
