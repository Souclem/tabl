import 'dart:convert';

import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

List<VignetteEventail> _vignettes(int n) => [
  for (var i = 0; i < n; i++)
    VignetteEventail(
      id: 'p$i',
      image: MemoryImage(_pixel),
      libelle: 'Photo ${i + 1}',
    ),
];

const _textes = TextesVisionneusePhotos(
  retour: 'Retour',
  supprimer: 'Supprimer…',
  etat: 'Dans ce brouillon · privée',
  ok: 'OK',
  titreConfirmation: 'Supprimer cette photo ?',
  detailConfirmation: 'Elle reste 30 jours dans la corbeille.',
  confirmer: 'Supprimer',
  annuler: 'Annuler',
);

void main() {
  group('EventailPhotosCamera', () {
    late List<String> ouvertes;
    late List<String> supprimees;
    var importations = 0;
    var fermetures = 0;

    Future<void> afficher(
      WidgetTester tester, {
      int photos = 3,
      String? indice,
    }) async {
      ouvertes = [];
      supprimees = [];
      importations = 0;
      fermetures = 0;
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: EventailPhotosCamera(
                    vignettes: _vignettes(photos),
                    ancre: const Offset(100, 500),
                    bas: 60,
                    libelleImporter: 'Importer',
                    libelleSupprimer: 'Retirer la photo',
                    libelleCorbeille: 'Supprimer',
                    indice: indice,
                    onOuvrir: ouvertes.add,
                    onSupprimer: (id) async => supprimees.add(id),
                    onImporter: () => importations++,
                    onFermer: () => fermetures++,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    Finder tuile(String id) => find.byKey(ValueKey(id));

    testWidgets('déploie les photos puis « Importer »', (tester) async {
      await afficher(tester, photos: 3);

      expect(tuile('p0'), findsOneWidget);
      expect(tuile('p1'), findsOneWidget);
      expect(tuile('p2'), findsOneWidget);
      expect(find.text('Importer'), findsOneWidget);
    });

    testWidgets('toucher « Importer » appelle onImporter', (tester) async {
      await afficher(tester);

      await tester.tap(find.text('Importer'));
      await tester.pump();

      expect(importations, 1);
    });

    testWidgets('toucher une photo l\'ouvre', (tester) async {
      await afficher(tester);

      await tester.tapAt(tester.getCenter(tuile('p1')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(ouvertes, ['p1']);
      expect(supprimees, isEmpty);
    });

    testWidgets('toucher à côté des photos ferme l\'éventail', (tester) async {
      await afficher(tester);

      await tester.tapAt(const Offset(600, 100));
      await tester.pump();

      expect(fermetures, 1);
    });

    testWidgets('le × retire la photo', (tester) async {
      await afficher(tester);

      await tester.tap(
        find.descendant(
          of: tuile('p1'),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(supprimees, ['p1']);
      expect(ouvertes, isEmpty);
    });

    testWidgets('appui long puis glisser vers la corbeille supprime', (
      tester,
    ) async {
      await afficher(tester);
      final geste = await tester.startGesture(tester.getCenter(tuile('p0')));

      await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
      // La corbeille est en bas à droite : (800 - 22 - 34, 600 - 210 - 34).
      await geste.moveTo(const Offset(744, 356));
      await tester.pump(const Duration(milliseconds: 50));
      await geste.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(supprimees, ['p0']);
      expect(ouvertes, isEmpty);
    });

    testWidgets('lâcher ailleurs que sur la corbeille ne supprime rien', (
      tester,
    ) async {
      await afficher(tester);
      final geste = await tester.startGesture(tester.getCenter(tuile('p0')));

      await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
      await geste.moveTo(const Offset(400, 300));
      await tester.pump(const Duration(milliseconds: 50));
      await geste.up();
      await tester.pump(const Duration(seconds: 1));

      expect(supprimees, isEmpty);
      expect(ouvertes, isEmpty);
      expect(tuile('p0'), findsOneWidget);
    });

    testWidgets('un appui plus court que 280 ms ne soulève pas', (
      tester,
    ) async {
      await afficher(tester);
      final geste = await tester.startGesture(tester.getCenter(tuile('p0')));

      await tester.pump(const Duration(milliseconds: 100));
      await geste.moveTo(const Offset(744, 356));
      await tester.pump(const Duration(milliseconds: 50));
      await geste.up();
      await tester.pump(const Duration(seconds: 1));

      expect(supprimees, isEmpty);
    });

    testWidgets('l\'indice s\'efface tout seul', (tester) async {
      await afficher(tester, indice: 'Touchez × ou glissez');

      expect(find.text('Touchez × ou glissez'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));

      final opacite = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('Touchez × ou glissez'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacite.opacity, 0);
    });
  });

  group('VisionneusePhotosCamera', () {
    late List<String> supprimees;
    var fermetures = 0;

    Future<void> afficher(WidgetTester tester, {int index = 0}) async {
      supprimees = [];
      fermetures = 0;
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: VisionneusePhotosCamera(
                    vignettes: _vignettes(3),
                    indexInitial: index,
                    textes: _textes,
                    onFermer: () => fermetures++,
                    onSupprimer: (id) async => supprimees.add(id),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('affiche la position et feuillette en glissant', (
      tester,
    ) async {
      await afficher(tester);
      expect(find.text('1 / 3'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('s\'ouvre sur la photo demandée', (tester) async {
      await afficher(tester, index: 2);

      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('la flèche et « OK » ferment', (tester) async {
      await afficher(tester);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pump();

      expect(fermetures, 2);
    });

    testWidgets('« Supprimer… » demande confirmation avant de supprimer', (
      tester,
    ) async {
      await afficher(tester, index: 1);

      await tester.tap(find.text('Supprimer…'));
      await tester.pump();
      expect(find.text('Supprimer cette photo ?'), findsOneWidget);
      expect(supprimees, isEmpty);

      await tester.tap(find.text('Supprimer'));
      await tester.pump();

      expect(supprimees, ['p1']);
      expect(find.text('Supprimer cette photo ?'), findsNothing);
    });

    testWidgets('« Annuler » ne supprime rien', (tester) async {
      await afficher(tester);

      await tester.tap(find.text('Supprimer…'));
      await tester.pump();
      await tester.tap(find.text('Annuler'));
      await tester.pump();

      expect(supprimees, isEmpty);
      expect(find.text('Supprimer cette photo ?'), findsNothing);
    });
  });
}
