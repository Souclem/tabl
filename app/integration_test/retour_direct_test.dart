// Reproduction : trajet direct accueil → connexion → retour, et accueil →
// inscription → retour, sans passer par l'autre formulaire. Exécuté sur un
// vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accueil → connexion → retour direct (sans détour)', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    await tester.tap(find.text('Se connecter  →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Bon retour'), findsOneWidget);
    debugPrint('MARK:Connexion');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:RetourDepuisConnexion');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Ré-ouvrir puis fermer une deuxième fois, pour voir si un état
    // laissé par le premier aller-retour casse le second.
    await tester.tap(find.text('Créer un compte avec un e-mail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Créer un compte'), findsOneWidget);
    debugPrint('MARK:Inscription');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:RetourDepuisInscription');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
