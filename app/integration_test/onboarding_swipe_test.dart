// Vérification manuelle (T016/T022) : parcours des 5 étapes par swipe puis
// arrivée sur l'écran d'accueil, exécuté sur un vrai simulateur (pas de mocks).
import 'package:app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('swipe des 5 étapes puis arrivée sur l\'accueil', (
    tester,
  ) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    Future<void> marquerEtape(String titre) async {
      expect(find.text(titre), findsOneWidget);
      debugPrint('MARK:$titre');
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    await marquerEtape('Bienvenue');
    for (final titre in [
      'Profil',
      'Feed',
      'Réseau privé entre amis',
      "Publication d'un souvenir",
    ]) {
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      await marquerEtape(titre);
    }

    expect(find.text('Commencer'), findsOneWidget);
    await tester.tap(find.text('Commencer'));
    // `pump` à durée fixe : EcranAccueil a un fond qui respire en boucle,
    // une animation qui ne s'arrête jamais et ferait échouer `pumpAndSettle`.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Créer un compte avec un e-mail'), findsOneWidget);
    debugPrint('MARK:Accueil');
    await Future<void>.delayed(const Duration(milliseconds: 600));
  });
}
