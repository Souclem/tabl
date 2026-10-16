import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

VisiteCarte _visite(String auteurId, String pseudo, {bool estMoi = false}) =>
    VisiteCarte(
      souvenirId: 's-$auteurId',
      auteurId: auteurId,
      auteurPseudo: pseudo,
      estMoi: estMoi,
      moment: 'soir',
      date: DateTime(2026, 10, 1),
    );

LieuCarte _lieu({List<VisiteCarte> visites = const [], bool envie = false}) =>
    LieuCarte(
      restaurantId: 'r1',
      nom: 'Como en Casa',
      ville: 'Liège',
      adresse: 'Rue Hors-Château 76',
      latitude: 50.6471,
      longitude: 5.5802,
      categories: const ['Vegan and Vegetarian Restaurant'],
      visites: visites,
      estEnvie: envie,
    );

void main() {
  test('résumé des visites : des noms, jamais un chiffre seul', () {
    expect(
      _lieu(visites: [_visite('a', 'Emma')]).resumeVisites,
      'Emma y est allé',
    );
    expect(
      _lieu(
        visites: [
          _visite('a', 'Emma'),
          _visite('b', 'Thomas'),
          _visite('c', 'Lucas'),
          _visite('d', 'Sarah'),
          _visite('a', 'Emma'),
        ],
      ).resumeVisites,
      'Emma, Thomas et 2 autres y sont allés',
    );
    expect(
      _lieu(visites: [_visite('moi', 'clem', estMoi: true)]).resumeVisites,
      'Vous y êtes allé',
    );
    expect(
      _lieu(
        visites: [_visite('moi', 'clem', estMoi: true), _visite('a', 'Emma')],
      ).resumeVisites,
      'Emma et vous y êtes allés',
    );
    expect(_lieu(envie: true).resumeVisites, 'Dans vos envies');
  });

  test('du réseau = visité ou mis en envie ; sinon simple point d\'annuaire', () {
    expect(_lieu(visites: [_visite('a', 'Emma')]).duReseau, isTrue);
    expect(_lieu(envie: true).duReseau, isTrue);
    expect(_lieu().duReseau, isFalse);
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

  test('GeoJSON : longitude puis latitude, clé et nombre de visites', () {
    final json =
        jsonDecode(geojsonLieux([_lieu(visites: [_visite('a', 'Emma')])]))
            as Map<String, dynamic>;
    final point = (json['features'] as List).single as Map<String, dynamic>;
    expect(point['geometry'], {
      'type': 'Point',
      'coordinates': [5.5802, 50.6471],
    });
    expect(point['properties'], {
      'cle': 'r1',
      'visites': 1,
      'envie': false,
      'autres': 0,
    });
  });

  test('ami en avant : le plus fidèle, et le nombre des autres', () {
    final lieu = _lieu(
      visites: [
        _visite('a', 'Emma'),
        _visite('b', 'Thomas'),
        _visite('b', 'Thomas'),
        _visite('c', 'Lucas'),
        _visite('moi', 'clem', estMoi: true),
      ],
    );
    expect(lieu.amiEnAvant?.pseudo, 'Thomas');
    expect(lieu.amiEnAvant?.autres, 2);
    expect(_lieu(visites: [_visite('moi', 'clem', estMoi: true)]).amiEnAvant, isNull);
  });
}
