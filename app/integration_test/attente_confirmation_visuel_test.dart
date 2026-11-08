// Vérification manuelle : tentative d'inscription réelle contre Supabase —
// soit l'écran d'attente de confirmation s'affiche, soit (si la limite de
// débit e-mail est atteinte) le message d'erreur traduit s'affiche.
// Exécuté sur un vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tentative d\'inscription réelle', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

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

    final champs = find.byType(TextField);
    final suffixe = DateTime.now().millisecondsSinceEpoch;
    await tester.enterText(champs.at(0), 'testeur$suffixe');
    await tester.enterText(champs.at(1), 'testeur$suffixe@exemple.com');
    await tester.enterText(champs.at(2), 'motdepasse123');
    await tester.enterText(champs.at(3), 'motdepasse123');
    await tester.pump();
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    debugPrint('MARK:ApresSoumission');
    await Future<void>.delayed(const Duration(milliseconds: 600));

    // Si un SnackBar d'erreur est apparu, capture-le pendant qu'il est
    // encore visible ; s'il n'y en a pas (succès), rien ne se passe ici.
    await tester.pump(const Duration(milliseconds: 500));
    debugPrint('MARK:MessageErreur');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
