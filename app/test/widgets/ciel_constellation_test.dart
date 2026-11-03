import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

const _liege = VilleDuCiel(
  nom: 'Liège',
  etiquette: '1 table',
  cx: 5.57,
  cy: -65.6,
  rayon: 0.004,
  repas: 3,
  entree: 0,
  etoiles: [EtoileDuCiel(cle: 'r1', nom: 'Bibo', x: 5.57, y: -65.6, repas: 3)],
  liens: [],
);

void main() {
  testWidgets('toucher une ville l\'ouvre ; toucher son étoile la choisit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final touchees = <String>[];
    var vides = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          villes: const [_liege],
          liensEntreVilles: const [],
          anime: false,
          onTapEtoile: touchees.add,
          onTapVide: () => vides++,
        ),
      ),
    );
    // Une seule adresse : au centre (décalé par les marges du haut et du bas).
    const centre = Offset(200, 420);

    await tester.tapAt(centre);
    await tester.pump();
    // La ville, de loin : on s'en approche, sans rien choisir.
    expect(vides, 1);
    expect(touchees, isEmpty);

    await tester.pump();
    await tester.tapAt(centre);
    await tester.pump();
    expect(touchees, ['r1']);
  });

  testWidgets('un ciel vide se dessine sans rien casser', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          villes: const [],
          liensEntreVilles: const [],
          anime: false,
          onTapEtoile: (_) {},
          onTapVide: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un ciel en pays et régions se dessine', (tester) async {
    const namur = VilleDuCiel(
      nom: 'Namur',
      etiquette: '1 table',
      cx: 4.87,
      cy: -65.4,
      rayon: 0.004,
      repas: 1,
      entree: 0,
      etoiles: [
        EtoileDuCiel(cle: 'r2', nom: 'Bistro', x: 4.87, y: -65.4, repas: 1),
      ],
      liens: [],
    );
    const tokyo = VilleDuCiel(
      nom: 'Tokyo',
      etiquette: '1 table',
      cx: 139.7,
      cy: -40.6,
      rayon: 0.004,
      repas: 1,
      entree: 0,
      etoiles: [
        EtoileDuCiel(cle: 'r3', nom: 'Sushi', x: 139.7, y: -40.6, repas: 1),
      ],
      liens: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TablCielConstellation(
          villes: const [_liege, namur, tokyo],
          liensEntreVilles: const [
            (de: 0, vers: 1, groupe: 0),
            (de: 0, vers: 2, groupe: -1),
          ],
          groupes: const [
            GroupeDuCiel(
              nom: 'Belgique',
              etiquette: '2 tables',
              parent: -1,
              villes: [0, 1],
              cx: 5.2,
              cy: -65.5,
              ecart: 0.7,
              tables: 2,
            ),
          ],
          anime: false,
          onTapEtoile: (_) {},
          onTapVide: () {},
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
