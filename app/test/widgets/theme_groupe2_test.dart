import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _enveloppe(ThemeData theme, Widget enfant) => MaterialApp(
  theme: theme,
  home: Scaffold(body: Center(child: enfant)),
);

void main() {
  for (final (nom, theme) in [
    ('clair', TablTheme.clair()),
    ('sombre', TablTheme.sombre()),
  ]) {
    testWidgets('les composants du groupe 2 s\'affichent en $nom', (
      tester,
    ) async {
      await tester.pumpWidget(
        _enveloppe(
          theme,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TablLigneTable(
                nom: 'Les copains',
                nombreMembres: 3,
                etatTexte: 'Rien de prévu',
                actionRequise: true,
                onTap: () {},
              ),
              const TablBoutonSocial(
                libelle: 'Continuer',
                icone: Icons.apple,
                style: TablBoutonSocialStyle.clair,
              ),
              const TablBoutonTexte(libelle: 'Lien'),
              TablBarreNavigation(
                ongletActif: TablOnglet.feed,
                onSelection: (_) {},
                onPublier: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Les copains'), findsOneWidget);
    });
  }
}
