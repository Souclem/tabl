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
    late List<List<String>> ordres;
    var importations = 0;
    var fermetures = 0;

    Future<void> afficher(
      WidgetTester tester, {
      int photos = 3,
      String? indice,
    }) async {
      ouvertes = [];
      supprimees = [];
      ordres = [];
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
                    onReordonner: (ordre) async => ordres.add(ordre),
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
      expect(ordres, isEmpty);
      expect(tuile('p0'), findsOneWidget);
    });

    testWidgets('appui long puis glisser à la place d\'une autre photo : '
        'nouvel ordre', (tester) async {
      await afficher(tester);
      final placeDeP2 = tester.getCenter(tuile('p2'));
      final geste = await tester.startGesture(tester.getCenter(tuile('p0')));

      await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
      await geste.moveTo(placeDeP2);
      await tester.pump(const Duration(milliseconds: 50));
      await geste.up();
      await tester.pump(const Duration(seconds: 1));

      expect(ordres, [
        ['p1', 'p2', 'p0'],
      ]);
      expect(supprimees, isEmpty);
      expect(ouvertes, isEmpty);
    });

    testWidgets('pendant le glissement, les autres photos s\'écartent', (
      tester,
    ) async {
      await afficher(tester);
      final placeDeP0 = tester.getCenter(tuile('p0'));
      final placeDeP1 = tester.getCenter(tuile('p1'));
      final placeDeP2 = tester.getCenter(tuile('p2'));
      final geste = await tester.startGesture(placeDeP0);

      await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
      await geste.moveTo(placeDeP2);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 300));

      // p1 et p2 ont avancé d'une place ; rien n'est encore rendu.
      expect(tester.getCenter(tuile('p1')), offsetMoreOrLessEquals(placeDeP0));
      expect(tester.getCenter(tuile('p2')), offsetMoreOrLessEquals(placeDeP1));
      expect(ordres, isEmpty);

      await geste.up();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('revenir à sa place avant de lâcher : rien ne change', (
      tester,
    ) async {
      await afficher(tester);
      final placeDeP0 = tester.getCenter(tuile('p0'));
      final geste = await tester.startGesture(placeDeP0);

      await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
      await geste.moveTo(tester.getCenter(tuile('p2')));
      await tester.pump(const Duration(milliseconds: 50));
      await geste.moveTo(placeDeP0);
      await tester.pump(const Duration(milliseconds: 50));
      await geste.up();
      await tester.pump(const Duration(seconds: 1));

      expect(ordres, isEmpty);
    });

    testWidgets('glisser tout de suite, sans appui long, déplace aussi', (
      tester,
    ) async {
      await afficher(tester);
      final placeDeP2 = tester.getCenter(tuile('p2'));
      final depart = tester.getCenter(tuile('p0'));
      final geste = await tester.startGesture(depart);

      // Le doigt part sans attendre, par petits pas, comme un vrai glissé.
      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 1; i <= 10; i++) {
        await geste.moveTo(Offset.lerp(depart, placeDeP2, i / 10)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await geste.up();
      await tester.pump(const Duration(seconds: 1));

      expect(ordres, [
        ['p1', 'p2', 'p0'],
      ]);
      expect(ouvertes, isEmpty);
    });

    testWidgets('glisser tout de suite vers la corbeille supprime', (
      tester,
    ) async {
      await afficher(tester);
      final depart = tester.getCenter(tuile('p0'));
      final geste = await tester.startGesture(depart);

      await tester.pump(const Duration(milliseconds: 16));
      for (var i = 1; i <= 10; i++) {
        await geste.moveTo(
          Offset.lerp(depart, const Offset(744, 356), i / 10)!,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      await geste.up();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(supprimees, ['p0']);
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
