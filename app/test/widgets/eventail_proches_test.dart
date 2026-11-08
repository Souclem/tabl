import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CarteEventail _carte(
  String pseudo, {
  String? ressenti,
  String? photoUrl,
  VoidCallback? onPresse,
}) => CarteEventail(
  pseudo: pseudo,
  photoUrl: photoUrl,
  ressenti: ressenti,
  fois: '3 fois',
  derniereVisite: 'Il y a 2 mois',
  onPresse: onPresse,
);

Future<void> _montrer(WidgetTester tester, Widget enfant) async {
  tester.view.physicalSize = const Size(375, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: enfant,
        ),
      ),
    ),
  );
}

void main() {
  group('TablEventail', () {
    testWidgets('un proche : une seule carte, avec ses textes', (tester) async {
      var profil = 0;
      await _montrer(
        tester,
        TablEventail(
          cartes: [_carte('Sami', ressenti: '😍', onPresse: () => profil++)],
        ),
      );

      expect(find.text('Sami'), findsOneWidget);
      expect(find.text('3 fois'), findsOneWidget);
      expect(find.text('Il y a 2 mois'), findsOneWidget);
      expect(find.text('😍'), findsOneWidget);
      expect(find.text('Qui y est allé'), findsNothing);

      await tester.tap(find.text('Sami'));
      expect(profil, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('quatre proches : quatre cartes sans « +N », sans trop-plein', (
      tester,
    ) async {
      final ouverts = <String>[];
      await _montrer(
        tester,
        TablEventail(
          cartes: [
            for (final p in ['Aline', 'Bastien', 'Camille', 'Dorian'])
              _carte(p, onPresse: () => ouverts.add(p)),
          ],
        ),
      );

      for (final p in ['Aline', 'Bastien', 'Camille', 'Dorian']) {
        expect(find.text(p), findsOneWidget);
      }
      expect(find.textContaining('+'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Aline'));
      await tester.tap(find.text('Dorian'));
      expect(ouverts, ['Aline', 'Dorian']);
    });

    testWidgets('sept proches : trois cartes et « +4 » qui ouvre la liste', (
      tester,
    ) async {
      var liste = 0;
      await _montrer(
        tester,
        TablEventail(
          cartes: [
            for (final p in ['Aline', 'Bastien', 'Camille']) _carte(p),
          ],
          autres: AutresEventail(texte: '+4', onPresse: () => liste++),
        ),
      );

      expect(find.text('Camille'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      expect(find.text('Qui y est allé'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('+4'));
      expect(liste, 1);
    });

    testWidgets('« +N » se dore quand il y a beaucoup d\'autres', (
      tester,
    ) async {
      Color? couleurDuPlus() =>
          tester.widget<Text>(find.text('+10')).style?.color;

      await _montrer(
        tester,
        TablEventail(
          cartes: [_carte('Aline')],
          autres: const AutresEventail(texte: '+10', nombreux: true),
        ),
      );
      expect(couleurDuPlus(), TablTokens.primaire);

      await _montrer(
        tester,
        TablEventail(
          cartes: [_carte('Aline')],
          autres: const AutresEventail(texte: '+10'),
        ),
      );
      expect(couleurDuPlus(), TablTokens.texte);
    });

    testWidgets('sans photo : l\'initiale ; sans ressenti : pas d\'emoji', (
      tester,
    ) async {
      await _montrer(tester, TablEventail(cartes: [_carte('léa')]));

      expect(find.text('L'), findsOneWidget);
      expect(find.text('😍'), findsNothing);
    });

    testWidgets('un long pseudo ne déborde pas', (tester) async {
      await _montrer(
        tester,
        TablEventail(
          cartes: [
            for (final p in ['Maximilien-Alexandre', 'B', 'C', 'D']) _carte(p),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('aucun proche : rien', (tester) async {
      await _montrer(tester, const TablEventail(cartes: []));

      expect(tester.getSize(find.byType(TablEventail)).height, 0);
    });
  });

  group('TablBarreOnYVa', () {
    testWidgets('les deux gestes appellent leur callback', (tester) async {
      var onYVa = 0;
      var itineraire = 0;
      await _montrer(
        tester,
        TablBarreOnYVa(onYVa: () => onYVa++, onItineraire: () => itineraire++),
      );

      await tester.tap(find.text('On y va ?'));
      await tester.tap(find.text('Itinéraire'));
      expect((onYVa, itineraire), (1, 1));
    });

    testWidgets('sans Table, « On y va ? » disparaît', (tester) async {
      await _montrer(tester, TablBarreOnYVa(onItineraire: () {}));

      expect(find.text('On y va ?'), findsNothing);
      expect(find.text('Itinéraire'), findsOneWidget);
    });

    testWidgets('sans lien, « Itinéraire » disparaît', (tester) async {
      await _montrer(tester, TablBarreOnYVa(onYVa: () {}));

      expect(find.text('On y va ?'), findsOneWidget);
      expect(find.text('Itinéraire'), findsNothing);
    });

    testWidgets('sans aucun geste, rien n\'est montré', (tester) async {
      await _montrer(tester, const TablBarreOnYVa());

      expect(find.byType(TablBouton), findsNothing);
      expect(find.text('Itinéraire'), findsNothing);
    });
  });

  group('TablHerosFiche (bandeau nuit)', () {
    Future<void> montrerBandeau(
      WidgetTester tester, {
      VoidCallback? onMarquePage,
      bool gardee = false,
    }) => _montrer(
      tester,
      SizedBox(
        height: 400,
        child: TablHerosFiche(
          nom: 'Atelier Lune',
          sousTitre: 'Liège · 19 rue Hors-Château',
          photoUrl: null,
          mention: 'Votre adresse · 7 fois',
          onRetour: () {},
          onMarquePage: onMarquePage,
          gardee: gardee,
        ),
      ),
    );

    testWidgets('marque-page : garder, puis retirer', (tester) async {
      var marque = 0;
      await montrerBandeau(tester, onMarquePage: () => marque++);

      expect(find.text('Atelier Lune'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      await tester.tap(find.byTooltip('Garder pour plus tard'));
      expect(marque, 1);

      await montrerBandeau(tester, onMarquePage: () => marque++, gardee: true);
      final icone = tester.widget<Icon>(find.byIcon(Icons.bookmark_rounded));
      expect(icone.color, TablTokens.primaire);
      await tester.tap(find.byTooltip('Retirer de mes envies'));
      expect(marque, 2);
    });

    testWidgets('sans callback, pas de marque-page', (tester) async {
      await montrerBandeau(tester);

      expect(find.byIcon(Icons.bookmark_border_rounded), findsNothing);
      expect(find.byIcon(Icons.bookmark_rounded), findsNothing);
    });
  });
}
