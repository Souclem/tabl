import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

void main() {
  testWidgets('affiche "Instant" et déclenche onPresse au tap', (
    tester,
  ) async {
    var appele = false;
    await tester.pumpWidget(
      MaterialApp(
        home: TablBoutonAjouterInstant(onPresse: () => appele = true),
      ),
    );

    expect(find.text('Instant'), findsOneWidget);
    await tester.tap(find.byType(TablBoutonAjouterInstant));
    expect(appele, isTrue);
  });
}
