import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

LieuCarte _lieu({
  int amis = 0,
  int visites = 0,
  bool moi = false,
  bool envie = false,
  String? ami,
}) => LieuCarte(
  restaurantId: 'r1',
  nom: 'Como en Casa',
  ville: 'Liège',
  adresse: 'Rue Hors-Château 76',
  latitude: 50.6471,
  longitude: 5.5802,
  categories: const ['Vegan and Vegetarian Restaurant'],
  amis: amis,
  visites: visites,
  visiteParMoi: moi,
  estEnvie: envie,
  amiPseudo: ami,
);

void main() {
  test('résumé des visites : des noms, jamais un chiffre seul', () {
    expect(
      _lieu(amis: 1, visites: 1, ami: 'Emma').resumeVisites,
      'Emma y est allé',
    );
    expect(
      _lieu(amis: 3, visites: 5, ami: 'Emma').resumeVisites,
      'Emma et 2 autres y sont allés',
    );
    expect(_lieu(visites: 1, moi: true).resumeVisites, 'Vous y êtes allé');
    expect(
      _lieu(amis: 1, visites: 2, moi: true, ami: 'Emma').resumeVisites,
      'Emma et vous y êtes allés',
    );
    expect(_lieu(envie: true).resumeVisites, 'Dans vos envies');
  });

  test('du réseau = visité ou mis en envie ; sinon simple point', () {
    expect(_lieu(visites: 1, moi: true).duReseau, isTrue);
    expect(_lieu(envie: true).duReseau, isTrue);
    expect(_lieu().duReseau, isFalse);
  });

  test('ami en avant et « +N »', () {
    final ami = _lieu(amis: 3, visites: 4, ami: 'Thomas').amiEnAvant;
    expect(ami?.pseudo, 'Thomas');
    expect(ami?.autres, 2);
    expect(_lieu(visites: 1, moi: true).amiEnAvant, isNull);
  });

  test('clé : l\'identifiant Tabl, ou celui de l\'annuaire', () {
    expect(_lieu().cle, 'r1');
    const annuaire = LieuCarte(
      fsqPlaceId: 'abc',
      nom: 'X',
      ville: 'Liège',
      latitude: 0,
      longitude: 0,
    );
    expect(annuaire.cle, 'fsq:abc');
  });

  test('copie : entrée dans Tabl, envie changée', () {
    const annuaire = LieuCarte(
      fsqPlaceId: 'abc',
      nom: 'X',
      ville: 'Liège',
      latitude: 0,
      longitude: 0,
    );
    final copie = annuaire.copierAvec(restaurantId: 'r9', estEnvie: true);
    expect(copie.cle, 'r9');
    expect(copie.duReseau, isTrue);
  });

  test(
    'GeoJSON : longitude puis latitude, et ce qu\'il faut pour le marqueur',
    () {
      final json =
          jsonDecode(geojsonLieux([_lieu(amis: 3, visites: 4, ami: 'Emma')]))
              as Map<String, dynamic>;
      final point = (json['features'] as List).single as Map<String, dynamic>;
      expect(point['geometry'], {
        'type': 'Point',
        'coordinates': [5.5802, 50.6471],
      });
      // La couleur de mon cercle ; sans ressenti, pas de note.
      expect(point['properties'], {'cle': 'r1', 'teinte': 'cercle'});
    },
  );

  test('GeoJSON : la couleur de la tuile, et la note pour la pastille', () {
    const lieu = LieuCarte(
      restaurantId: 'r1',
      nom: 'Bibo',
      ville: 'Liège',
      latitude: 50.6471,
      longitude: 5.5802,
      amis: 2,
      amisQuiReviennent: 1,
      ressentis: ['😍', '😍'],
    );
    final json = jsonDecode(geojsonLieux([lieu])) as Map<String, dynamic>;
    final point = (json['features'] as List).single as Map<String, dynamic>;
    expect(point['properties'], {
      'cle': 'r1',
      'teinte': 'retour',
      'etiquette': '★ 5,0',
    });
  });

  test('GeoJSON : le lieu dont la feuille est ouverte est marqué', () {
    final json =
        jsonDecode(geojsonLieux([_lieu(amis: 1)], cleChoisie: 'r1'))
            as Map<String, dynamic>;
    final point = (json['features'] as List).single as Map<String, dynamic>;
    expect((point['properties'] as Map)['choisi'], isTrue);
  });
}
