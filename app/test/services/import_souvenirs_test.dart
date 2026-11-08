import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

/// Une photo de test : seules ses métadonnées comptent ici.
PhotoChoisie _photo(
  DateTime? prisLe, {
  double? lat,
  double? lng,
  String? empreinte,
}) => (
  octets: Uint8List(0),
  metadonnees: MetadonneesPhoto(
    prisLe: prisLe,
    latitude: lat,
    longitude: lng,
    empreinte: empreinte,
  ),
);

/// Chez Como en Casa, à Liège.
const _como = (lat: 50.64735, lng: 5.58045);

/// À Bruxelles, à 90 km.
const _bruxelles = (lat: 50.8467, lng: 4.3525);

void main() {
  test('un repas : photos proches dans le temps et au même endroit', () {
    final r = rangerEnRepas([
      _photo(DateTime(2023, 11, 3, 20, 58), lat: _como.lat, lng: _como.lng),
      _photo(DateTime(2023, 11, 3, 20, 41), lat: _como.lat, lng: _como.lng),
      _photo(DateTime(2023, 11, 3, 21, 30)),
    ]);

    expect(r.repas, hasLength(1));
    // Dans l'ordre où elles ont été prises.
    expect(
      r.repas.single.first.metadonnees.prisLe,
      DateTime(2023, 11, 3, 20, 41),
    );
    expect(
      mentionSansPosition(r.repas.single),
      '1 photo sans position, rattachée par l\'heure',
    );
  });

  test('un autre jour, ou un autre endroit le même soir : deux repas', () {
    final r = rangerEnRepas([
      _photo(DateTime(2023, 11, 3, 20, 41), lat: _como.lat, lng: _como.lng),
      _photo(
        DateTime(2023, 11, 3, 21, 10),
        lat: _bruxelles.lat,
        lng: _bruxelles.lng,
      ),
      _photo(DateTime(2023, 11, 9, 12, 30), lat: _como.lat, lng: _como.lng),
    ]);

    expect(r.repas, hasLength(3));
  });

  test('plus de trois heures d\'écart : deux repas, même au même endroit', () {
    final r = rangerEnRepas([
      _photo(DateTime(2023, 11, 3, 12, 30), lat: _como.lat, lng: _como.lng),
      _photo(DateTime(2023, 11, 3, 20, 41), lat: _como.lat, lng: _como.lng),
    ]);

    expect(r.repas, hasLength(2));
  });

  test(
    'sans date : rattachée au repas dont elle est proche, sinon écartée',
    () {
      final r = rangerEnRepas([
        _photo(DateTime(2023, 11, 3, 20, 41), lat: _como.lat, lng: _como.lng),
        _photo(null, lat: _como.lat + 0.0005, lng: _como.lng),
        _photo(null, lat: _bruxelles.lat, lng: _bruxelles.lng),
        _photo(null),
      ]);

      expect(r.repas.single, hasLength(2));
      expect(r.inexploitables, 2);
    },
  );

  test('déjà importées : écartées et comptées', () {
    final r = rangerEnRepas(
      [
        _photo(DateTime(2023, 11, 3, 20, 41), empreinte: 'a'),
        _photo(DateTime(2023, 11, 3, 20, 50), empreinte: 'b'),
      ],
      empreintes: {'a'},
    );

    expect(r.dejaImportees, 1);
    expect(r.repas.single, hasLength(1));
  });

  test('le bilan : souvenirs, restaurants distincts et période', () {
    const como = LieuRestaurant(
      nom: 'Como en Casa',
      ville: 'Liège',
      fsqPlaceId: 'c',
    );
    const bibo = LieuRestaurant(nom: 'Bibo', ville: 'Liège', fsqPlaceId: 'b');
    final bilan = bilanImport([
      (lieu: como, date: const DateSouvenir(annee: 2023, mois: 3, jour: 2)),
      (lieu: como, date: const DateSouvenir(annee: 2026, mois: 8)),
      (lieu: bibo, date: const DateSouvenir(annee: 2019, mois: 3)),
    ]);

    expect(bilan.souvenirs, 3);
    expect(bilan.restaurants, 2);
    expect(bilan.periode, 'Mars 2019 — Août 2026');
    expect(bilanImport([]).periode, isNull);
  });
}
