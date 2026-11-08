import 'package:app/theme/tokens.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _enveloppe(ThemeData theme, Widget enfant) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: enfant)),
);

Color? _couleurDuTexte(WidgetTester tester, String texte) =>
    tester.widget<Text>(find.text(texte)).style?.color;

void main() {
  for (final (nom, theme, couleurs) in [
    ('clair', TablTheme.clair(), TablCouleurs.clair),
    ('sombre', TablTheme.sombre(), TablCouleurs.sombre),
  ]) {
    testWidgets('l\'aperçu d\'un lieu suit l\'apparence $nom', (tester) async {
      await tester.pumpWidget(
        _enveloppe(
          theme,
          TablApercuLieu(
            nom: 'Chez Léon',
            detail: 'Italien · Hors-Château',
            photoUrl: null,
            visages: const [],
            quiLaConnait: 'Emma la connaît',
            onFermer: () {},
            onVoirFiche: () {},
            enregistre: false,
            onEnregistrer: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_couleurDuTexte(tester, 'Chez Léon'), couleurs.texte);
      expect(_couleurDuTexte(tester, 'Emma la connaît'), couleurs.texte);
      expect(
        _couleurDuTexte(tester, 'Italien · Hors-Château'),
        couleurs.texteDoux,
      );
    });

    testWidgets('la feuille et le menu de tri suivent l\'apparence $nom', (
      tester,
    ) async {
      await tester.pumpWidget(
        _enveloppe(
          theme,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 400,
                child: TablFeuilleCarnet(
                  lignes: const [],
                  libelleVoir: 'Voir 12 adresses',
                  compte: '12 adresses',
                  onVoir: () {},
                  onFermer: () {},
                ),
              ),
              TablMenuTri(
                options: const [
                  (libelle: 'Récents', description: 'Les plus récents'),
                ],
                choisi: 0,
                onChoisir: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(_couleurDuTexte(tester, 'Filtres'), couleurs.texte);
      expect(_couleurDuTexte(tester, '12 adresses'), couleurs.texteDoux);
    });
  }
}
