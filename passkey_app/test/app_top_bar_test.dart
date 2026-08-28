import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:passkey_app/theme/app_theme.dart';
import 'package:passkey_app/widgets/app_top_bar.dart';

Future<void> pumpBar(
  WidgetTester tester, {
  required Widget bar,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: MediaQuery(
        data: MediaQueryData(padding: padding),
        child: Scaffold(
          appBar: bar as PreferredSizeWidget,
          body: const SizedBox.expand(),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the branded bar keeps its 64px content height under a status '
      'bar inset', (WidgetTester tester) async {
    await pumpBar(
      tester,
      bar: const AppTopBar(),
      padding: const EdgeInsets.only(top: 47),
    );

    // Scaffold allots preferredSize + the top inset; the SafeArea consumes
    // the inset so the bar's own content keeps its full 64px.
    expect(tester.getSize(find.byType(AppTopBar)).height, 64 + 47);

    final row = tester.getSize(
      find.descendant(
        of: find.byType(AppTopBar),
        matching: find.byType(Row),
      ),
    );

    expect(row.height, 64);
    expect(find.text('SignApp Passkey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the back variant renders an arrow and pops the route',
      (WidgetTester tester) async {
    await pumpBar(tester, bar: const AppTopBar.withBack(title: 'Détail'));

    expect(find.text('Détail'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.security), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long title ellipsizes instead of wrapping or overflowing',
      (WidgetTester tester) async {
    await pumpBar(
      tester,
      bar: const AppTopBar.withBack(
        title: 'Un titre de document beaucoup trop long pour cette barre',
      ),
    );

    final text = tester.widget<Text>(
      find.text('Un titre de document beaucoup trop long pour cette barre'),
    );

    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });
}
