import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _enveloppe(ThemeData theme, Widget enfant) => MaterialApp(
  theme: theme,
  home: Scaffold(body: SingleChildScrollView(child: enfant)),
);

void main() {
  for (final (nom, theme, couleurs) in [
    ('clair', TablTheme.clair(), TablCouleurs.clair),
    ('sombre', TablTheme.sombre(), TablCouleurs.sombre),
  ]) {
    testWidgets('la fiche d\'un restaurant suit l\'apparence $nom', (
      tester,
    ) async {
      await tester.pumpWidget(
        _enveloppe(
          theme,
          Column(
            children: [
              TablHerosFiche(
                nom: 'Chez Léon',
                sousTitre: 'Liège',
                photoUrl: null,
                mention: 'Votre adresse · 3 fois',
                onRetour: () {},
              ),
              TablActionsFiche(
                actions: [
                  ActionFiche(
                    icone: Icons.bookmark_border_rounded,
                    libelle: 'Garder',
                    onPresse: () {},
                  ),
                ],
              ),
              const TablMonHistoireFiche(fois: 0, depuis: null, detail: ''),
              const TablCeQuiRessort(
                impressions: [(libelle: 'Convivial', fois: 2)],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final titre = tester.widget<Text>(find.text('Chez Léon'));
      expect(titre.style?.color, couleurs.texte);
      final histoire = tester.widget<Text>(
        find.text('Pas encore dans votre histoire.'),
      );
      expect(histoire.style?.color, couleurs.texte.withValues(alpha: 0.7));
    });
  }
}
