import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('les visages ouvrent « Qui y est allé », le reste la fiche', (
    tester,
  ) async {
    var fiche = 0;
    var visages = 0;
    var envie = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: TablTuileLieu(
              nom: 'Atelier Lune',
              genre: GenreTuile.vous,
              visages: const [(pseudo: 'Sami', photoUrl: null)],
              autres: '+4',
              etVous: true,
              enGras: '50 m',
              detail: 'Japonais',
              note: '4,0',
              onPresse: () => fiche++,
              onVisages: () => visages++,
              onEnvie: () => envie++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Atelier Lune'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);
    expect(find.text('et vous'), findsOneWidget);
    expect(find.text('4,0'), findsOneWidget);
    expect(find.textContaining('Japonais'), findsOneWidget);

    await tester.tap(find.text('+4'));
    await tester.tap(find.text('Atelier Lune'));
    await tester.tap(find.byTooltip('Garder pour plus tard'));
    expect((fiche, visages, envie), (1, 1, 1));
  });
}
