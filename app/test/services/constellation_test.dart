import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

LieuCarte _mien(
  String nom,
  String ville,
  int fois,
  DateTime premiere, {
  double latitude = 50.64,
  double longitude = 5.57,
}) => LieuCarte(
  restaurantId: nom,
  nom: nom,
  ville: ville,
  latitude: latitude,
  longitude: longitude,
  visiteParMoi: true,
  mesVisites: fois,
  maPremiereVisite: premiere,
  maDerniereVisite: premiere,
);

void main() {
  final miens = [
    _mien(
      'Osteria',
      'Milan',
      2,
      DateTime(2025, 7, 1),
      latitude: 45.46,
      longitude: 9.19,
    ),
    _mien('Comptoir', 'Liège', 6, DateTime(2024, 1, 1)),
    _mien('Coupe Gorge', 'Liège', 3, DateTime(2024, 5, 1)),
  ];

  test('mes villes, dans l\'ordre où je les ai découvertes', () {
    final villes = villesConstellation(miens);
    expect([for (final v in villes) v.nom], ['Liège', 'Milan']);
    expect(villes.first.tables, 2);
    expect(villes.first.repas, 9);
    expect(compteursConstellation(miens), (repas: 11, villes: 2));
    expect(tablesEtRepas(2, 9), '2 tables · 9 repas');
  });

  test('le GeoJSON : le fil, les villes, les étoiles', () {
    final json =
        jsonDecode(geojsonConstellation(miens, cleChoisie: 'Comptoir'))
            as Map<String, dynamic>;
    final features = (json['features'] as List).cast<Map<String, dynamic>>();
    String type(Map<String, dynamic> f) =>
        (f['properties'] as Map)['type'] as String;

    final sillage = features.firstWhere((f) => type(f) == 'sillage');
    // De Liège (découverte en premier) à Milan.
    expect((sillage['geometry'] as Map)['coordinates'], [
      [5.57, 50.64],
      [9.19, 45.46],
    ]);
    final liege = features.firstWhere((f) => type(f) == 'ville');
    expect((liege['properties'] as Map)['etiquette'], 'LIÈGE\n2 tables');
    final etoiles = features.where((f) => type(f) == 'etoile').toList();
    expect(etoiles, hasLength(3));
    final comptoir = etoiles.firstWhere(
      (f) => (f['properties'] as Map)['cle'] == 'Comptoir',
    );
    expect((comptoir['properties'] as Map)['fois'], 6);
    expect((comptoir['properties'] as Map)['choisi'], isTrue);
  });

  test('mes adresses d\'une ville, la plus fréquentée d\'abord', () {
    expect(
      [for (final l in lieuxDeLaVille(miens, 'liège')) l.nom],
      ['Comptoir', 'Coupe Gorge'],
    );
    expect(repasEtDerniere(miens[1]), '6 repas · janvier 2024');
  });
}
