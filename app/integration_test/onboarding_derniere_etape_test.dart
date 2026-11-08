// Vérification manuelle : le bouton "Commencer" de la dernière étape amène
// à l'accueil, exécuté sur un vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('"Commencer" depuis l\'étape 5 amène à l\'accueil', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    for (var i = 0; i < 4; i++) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
    }

    expect(find.text("Publication d'un souvenir"), findsOneWidget);
    expect(find.text('Commencer'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    // `pump` à durée fixe : EcranAccueil a un fond qui respire en boucle,
    // une animation qui ne s'arrête jamais et ferait échouer `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:DerniereEtape');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
