// Vérification manuelle : connexion et inscription sont des écrans de même
// niveau (bascule sans empiler), chacun avec un bouton retour vers
// l'accueil ; connexion propose aussi Apple/Google. Exécuté sur un vrai
// simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'accueil → connexion → inscription → connexion → retour direct à '
    'l\'accueil',
    (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      for (var i = 0; i < 4; i++) {
        await tester.fling(
          find.byType(PageView),
          const Offset(-400, 0),
          1000,
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Commencer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      // Accueil → Connexion.
      await tester.tap(find.text('Se connecter  →'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bon retour'), findsOneWidget);
      expect(find.text('Continuer avec Apple'), findsOneWidget);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      debugPrint('MARK:Connexion');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Connexion → Inscription : bascule (remplace), pas d'empilement.
      await tester.ensureVisible(find.text("S'inscrire"));
      await tester.tap(find.text("S'inscrire"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Créer un compte'), findsOneWidget);
      expect(find.text('Bon retour'), findsNothing);
      debugPrint('MARK:Inscription');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Inscription → Connexion à nouveau, toujours par bascule.
      await tester.ensureVisible(find.text('Se connecter'));
      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Bon retour'), findsOneWidget);
      expect(find.text('Créer un compte'), findsNothing);
      debugPrint('MARK:ConnexionDeNouveau');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Bouton retour circulaire → doit ramener directement à l'accueil,
      // pas à l'inscription (ils sont au même niveau, pas empilés).
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
      debugPrint('MARK:RetourAccueil');
      await Future<void>.delayed(const Duration(milliseconds: 600));
    },
  );
}
