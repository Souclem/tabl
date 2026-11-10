// Vérification visuelle : titre de la feuille « Qui peut voir ce moment ? ».
// Services simulés : rien n'est écrit dans la vraie base.
import 'package:app/ecrans/feuille_audience.dart';
import 'package:app/services/services.dart';
import 'package:app/theme/tabl_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final sombre in [false, true]) {
    testWidgets('feuille audience ${sombre ? "sombre" : "claire"}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TablTheme.clair(),
          darkTheme: TablTheme.sombre(),
          themeMode: sombre ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => ouvrirFeuilleAudience(
                    context,
                    audienceInitiale: AudienceSouvenir.toutLeMonde,
                    abonnementService: _FauxAbonnements(),
                    donnees: Future.value(
                      const DonneesAudience(
                        contexte: ContexteAudience(
                          profilPrive: false,
                          abonnesIds: {},
                          membresParTable: {},
                        ),
                        relations: [],
                        tables: [],
                      ),
                    ),
                  ),
                  child: const Text('Ouvrir'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Qui peut voir ce moment ?'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      debugPrint('CAPTURE:feuille-audience-${sombre ? "sombre" : "claire"}');
      await tester.pump(const Duration(seconds: 2));
    });
  }
}

class _FauxAbonnements implements AbonnementService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
