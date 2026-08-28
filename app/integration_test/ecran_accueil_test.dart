// Vérification manuelle : écran d'accueil (fond, boutons, ouverture du
// formulaire e-mail), exécuté sur un vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accueil affiché après Passer, puis ouverture du formulaire '
      'e-mail au tap', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Traverser l'onboarding jusqu'à "Commencer" pour atteindre l'accueil.
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    // `pump` à durée fixe : le fond de l'accueil respire en boucle, une
    // animation qui ne s'arrête jamais et ferait échouer `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Continuer avec Apple'), findsOneWidget);
    expect(find.text('Continuer avec Google'), findsOneWidget);
    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:AccueilEtabli');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Déclenche l'ouverture du formulaire e-mail : capture en plein milieu
    // de la transition, pour voir l'animation, puis une fois posée.
    await tester.tap(find.text('Créer un compte avec un e-mail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    debugPrint('MARK:TransitionFormulaire');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Créer un compte'), findsOneWidget);
    debugPrint('MARK:FormulaireOuvert');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
