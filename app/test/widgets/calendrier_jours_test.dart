import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

void main() {
  testWidgets('tap sur un jour actif bascule sa sélection', (tester) async {
    DateTime? jourBascule;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TablCalendrierJours(
              mois: DateTime(2026, 9),
              joursSelectionnes: const {},
              joursDesactives: const {},
              onToggleJour: (j) => jourBascule = j,
              onMoisPrecedent: () {},
              onMoisSuivant: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('12'));
    expect(jourBascule, DateTime(2026, 9, 12));
  });

  testWidgets('un jour désactivé ne déclenche jamais onToggleJour (règle 33)', (tester) async {
    var appele = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TablCalendrierJours(
              mois: DateTime(2026, 9),
              joursSelectionnes: const {},
              joursDesactives: {DateTime(2026, 9, 5)},
              onToggleJour: (_) => appele = true,
              onMoisPrecedent: () {},
              onMoisSuivant: () {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('5'));
    expect(appele, isFalse);
  });

  testWidgets('chevron suivant appelle onMoisSuivant', (tester) async {
    var appele = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TablCalendrierJours(
              mois: DateTime(2026, 9),
              joursSelectionnes: const {},
              joursDesactives: const {},
              onToggleJour: (_) {},
              onMoisPrecedent: () {},
              onMoisSuivant: () => appele = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(appele, isTrue);
  });
}
