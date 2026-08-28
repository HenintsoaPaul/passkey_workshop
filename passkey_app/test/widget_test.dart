import 'package:flutter_test/flutter_test.dart';

import 'package:passkey_app/main.dart';

void main() {
  testWidgets('PasskeyPage renders username field and action buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Passkey POC'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Register Passkey'), findsOneWidget);
    expect(find.text('Login with Passkey'), findsOneWidget);
  });
}
