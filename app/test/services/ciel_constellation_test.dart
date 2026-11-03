import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

int _n = 0;

LieuCarte _lieu(
  String ville,
  double lat,
  double lon,
  DateTime premiere, {
  int repas = 1,
  String? nom,
}) => LieuCarte(
  restaurantId: 'r${_n++}',
  nom: nom ?? 'Resto $_n',
  ville: ville,
  latitude: lat,
  longitude: lon,
  visiteParMoi: true,
  mesVisites: repas,
  maPremiereVisite: premiere,
);

/// Le nom des villes d'un lien, de la plus ancienne vers l'autre.
String _nommer(CielConstellation c, LienCiel l) =>
    '${c.villes[l.de].nom} → ${c.villes[l.vers].nom}';

void main() {
  test('les villes, dans l\'ordre de découverte', () {
    final ciel = cielConstellation([
      _lieu('Paris', 48.86, 2.35, DateTime(2019, 4), repas: 2),
      _lieu('Liège', 50.64, 5.57, DateTime(2020, 1), repas: 6),
      _lieu('liege', 50.65, 5.58, DateTime(2021, 3), repas: 3),
    ]);

    expect([for (final v in ciel.villes) v.nom], ['Paris', 'Liège']);
    expect(ciel.villes[1].etoiles, hasLength(2));
    expect(ciel.villes[1].etiquette, '2 tables');
    expect(ciel.compteurs, '3 tables · 11 repas · 2 villes');
    expect(cielConstellation(const []).estVide, isTrue);
  });

  test('une adresse sans nom de ville rejoint la ville la plus proche ; '
      'loin de tout, elle est « Ailleurs »', () {
    final ciel = cielConstellation([
      _lieu('Liège', 50.64, 5.57, DateTime(2020, 1)),
      _lieu('', 50.61, 5.51, DateTime(2021, 1)),
      _lieu('', 45.5, 9.2, DateTime(2022, 1)),
    ]);

    expect([for (final v in ciel.villes) v.nom], ['Liège', 'Ailleurs']);
    expect(ciel.villes.first.etoiles, hasLength(2));
  });

  test('Dense : un maillage en triangles, sans traits démesurés', () {
    // Trois points alignés : pas de lien du premier au dernier, par-dessus
    // celui du milieu.
    expect(liensDenses(const [(0, 0), (1, 0), (2, 0)]).toSet(), {
      (0, 1),
      (1, 2),
    });
    // Un triangle : ses trois côtés.
    expect(liensDenses(const [(0, 0), (1, 0), (0.5, 0.8)]), hasLength(3));
    // Loin des autres, un point garde un lien, mais pas vers tout le monde.
    final liens = liensDenses(const [(0, 0), (1, 0), (0.5, 0.8), (40, 40)]);
    expect(liens.where((l) => l.$1 == 3 || l.$2 == 3), isNotEmpty);
    expect(liensDenses(const [(0, 0)]), isEmpty);
  });

  test('Dense : rapide, même avec des centaines d\'adresses', () {
    final h = math.Random(1);
    final points = [
      for (var i = 0; i < 400; i++) (h.nextDouble(), h.nextDouble()),
    ];
    final chrono = Stopwatch()..start();
    final liens = liensDenses(points);
    expect(chrono.elapsedMilliseconds, lessThan(1500));
    // Chaque point relié ; un maillage plan a moins de 3 n liens.
    expect({
      for (final (a, b) in liens) ...[a, b],
    }, hasLength(400));
    expect(liens.length, lessThan(3 * 400));
  });

  test('un lien va toujours de la ville découverte en premier', () {
    // On a mangé à Paris avant de s'installer à Liège.
    final ciel = cielConstellation([
      _lieu('Paris', 48.86, 2.35, DateTime(2018, 6)),
      _lieu('Liège', 50.64, 5.57, DateTime(2019, 9), repas: 9),
    ]);

    expect(_nommer(ciel, ciel.liensEntreVilles.single), 'Paris → Liège');
  });

  test('distances et projection', () {
    expect(
      distanceCielKm(5.57, mercY(50.64), 4.35, mercY(50.85)),
      closeTo(89, 2),
    );
    expect(latitudeDepuisMercY(mercY(-33.87)), closeTo(-33.87, 1e-9));
  });

  test('la fiche d\'une étoile', () {
    final ciel = cielConstellation([
      _lieu('Liège', 50.64, 5.57, DateTime(2022, 3, 8), repas: 4, nom: 'Bibo'),
    ]);
    final f = ficheEtoile(ciel.villes.single.etoiles.single, 'Liège');

    expect(f.nom, 'Bibo');
    expect(f.detail, 'Liège · 4 repas');
    expect(f.depuis, 'Première fois en mars 2022');
    expect(f.retour, isTrue);
  });
}
