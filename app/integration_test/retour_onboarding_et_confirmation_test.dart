// Vérification manuelle : le bouton retour de l'accueil ramène dans
// l'onboarding, et le champ "confirmer le mot de passe" est bien présent
// et validé à l'inscription. Exécuté sur un vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accueil → retour dans l\'onboarding', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:Accueil');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    // Le retour depuis l'accueil repart de la première étape, pas de la
    // dernière vue avant "Commencer" (voir CLAUDE.md / mémoire du projet).
    expect(find.text('Bienvenue'), findsOneWidget);
    debugPrint('MARK:RetourOnboarding');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Confirmation champ mot de passe sur l'inscription : re-swiper
    // jusqu'à la dernière étape, l'onboarding étant reparti du début.
    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.text('Créer un compte avec un e-mail'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Confirmer le mot de passe'), findsOneWidget);
    debugPrint('MARK:ChampConfirmation');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    final champs = find.byType(TextField);
    // Ordre du formulaire : pseudo, e-mail, mot de passe, confirmation.
    await tester.ensureVisible(champs.at(0));
    await tester.enterText(champs.at(0), 'camille');
    await tester.ensureVisible(champs.at(1));
    await tester.enterText(champs.at(1), 'camille@exemple.com');
    await tester.ensureVisible(champs.at(2));
    await tester.enterText(champs.at(2), 'motdepasse123');
    await tester.ensureVisible(champs.at(3));
    await tester.enterText(champs.at(3), 'autrechose456');
    await tester.pump();
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Les deux mots de passe ne correspondent pas.'),
      findsOneWidget,
    );
    debugPrint('MARK:ErreurConfirmation');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
