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
}
