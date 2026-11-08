import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

void main() {
  testWidgets('non vus > 0 : "X nouvel Instant(s)"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablSignalInstants(total: 3, nonVus: 1, onPresse: () {}),
      ),
    );

    expect(find.text('1 nouvel Instant'), findsOneWidget);
  });

  testWidgets('plusieurs non vus : pluriel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablSignalInstants(total: 3, nonVus: 3, onPresse: () {}),
      ),
    );

    expect(find.text('3 nouveaux Instants'), findsOneWidget);
  });

  testWidgets('tout vu : "X Instant(s)" sans "nouveau"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablSignalInstants(total: 2, nonVus: 0, onPresse: () {}),
      ),
    );

    expect(find.text('2 Instants'), findsOneWidget);
    expect(find.textContaining('nouve'), findsNothing);
  });

  testWidgets('tap déclenche onPresse', (tester) async {
    var appele = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TablSignalInstants(
          total: 1,
          nonVus: 0,
          onPresse: () => appele = true,
        ),
      ),
    );

    await tester.tap(find.text('1 Instant'));
    expect(appele, isTrue);
  });
}
