import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<TablCouleurs> _couleurs(WidgetTester tester, ThemeData theme) async {
  late TablCouleurs couleurs;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          couleurs = TablCouleurs.of(context);
          return const SizedBox();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return couleurs;
}

void main() {
  test('le réglage Apparence se traduit en mode du thème', () {
    expect(TablTheme.mode(Apparence.automatique), ThemeMode.system);
    expect(TablTheme.mode(Apparence.clair), ThemeMode.light);
    expect(TablTheme.mode(Apparence.sombre), ThemeMode.dark);
  });

  testWidgets('les couleurs suivent le thème clair ou sombre', (tester) async {
    expect(await _couleurs(tester, TablTheme.clair()), TablCouleurs.clair);
    expect(await _couleurs(tester, TablTheme.sombre()), TablCouleurs.sombre);
  });

  testWidgets('sans thème Tabl, on obtient le sombre', (tester) async {
    expect(await _couleurs(tester, ThemeData()), TablCouleurs.sombre);
  });

  testWidgets('le clair a un fond clair et un texte foncé', (tester) async {
    final c = TablCouleurs.clair;
    expect(c.fond.computeLuminance(), greaterThan(0.5));
    expect(c.texte.computeLuminance(), lessThan(0.1));
    expect(TablCouleurs.sombre.fond.computeLuminance(), lessThan(0.1));
  });
}
