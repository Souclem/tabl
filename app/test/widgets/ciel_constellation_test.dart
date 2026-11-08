import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

void main() {
  Future<void> taille(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('une seule adresse : on touche sa ville, puis elle', (
    tester,
  ) async {
    await taille(tester);
    final touchees = <String>[];
    var vides = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          etoiles: const [
            EtoileDuCiel(
              cle: 'r1',
              nom: 'Bibo',
              detail: '3 repas',
              x: 5.57,
              y: -65.6,
              poids: 3,
              groupe: 0,
            ),
          ],
          groupes: const [
            GroupeDuCiel(
              nom: 'Liège',
              etiquette: '1 table',
              parent: -1,
              cx: 5.57,
              cy: -65.6,
              ecart: 0.003,
              poids: 1,
            ),
          ],
          anime: false,
          onTapEtoile: touchees.add,
          onTapVide: () => vides++,
        ),
      ),
    );
    // Au centre (décalé par les marges du haut et du bas) : sa ville, de
    // loin ; on s'en approche, sans rien choisir.
    const centre = Offset(200, 420);
    await tester.tapAt(centre);
    await tester.pump();
    expect(vides, 1);
    expect(touchees, isEmpty);

    await tester.pump();
    await tester.tapAt(centre);
    await tester.pump();
    expect(touchees, ['r1']);

    await tester.tapAt(const Offset(60, 700));
    await tester.pump();
    expect(vides, 2);
  });

  testWidgets('un pays fermé : le toucher s\'en approche, jusqu\'à voir '
      'son restaurant', (tester) async {
    await taille(tester);
    final touchees = <String>[];
    var vides = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          etoiles: const [
            EtoileDuCiel(
              cle: 'r1',
              nom: 'Bibo',
              detail: '3 repas',
              x: 5.57,
              y: -65.6,
              poids: 3,
              groupe: 1,
            ),
            EtoileDuCiel(
              cle: 'r2',
              nom: 'Sushi',
              detail: '1 repas',
              x: 139.7,
              y: -38.2,
              poids: 1,
              groupe: 2,
            ),
          ],
          groupes: const [
            GroupeDuCiel(
              nom: 'Belgique',
              etiquette: '1 table',
              parent: -1,
              cx: 5.57,
              cy: -65.6,
              ecart: 0.7,
              poids: 1,
            ),
            GroupeDuCiel(
              nom: 'Liège',
              etiquette: '1 table',
              parent: 0,
              cx: 5.57,
              cy: -65.6,
              ecart: 0.003,
              poids: 1,
            ),
            GroupeDuCiel(
              nom: 'Tokyo',
              etiquette: '1 table',
              parent: -1,
              cx: 139.7,
              cy: -38.2,
              ecart: 0.003,
              poids: 1,
            ),
          ],
          liens: const [(de: 0, vers: 1, groupe: -1)],
          anime: false,
          onTapEtoile: touchees.add,
          onTapVide: () => vides++,
        ),
      ),
    );
    // Le monde entier : la Belgique, tout à gauche.
    await tester.tapAt(const Offset(28, 385));
    await tester.pump();
    expect(vides, 1);
    expect(touchees, isEmpty);

    await tester.pump();
    await tester.tapAt(const Offset(200, 420));
    await tester.pump();
    expect(touchees, ['r1']);
  });

  testWidgets('un ciel vide se dessine sans rien casser', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          etoiles: const [],
          anime: false,
          onTapEtoile: (_) {},
          onTapVide: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
