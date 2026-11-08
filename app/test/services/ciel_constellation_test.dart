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

/// Les villes des deux étoiles d'un lien, de la plus ancienne vers
/// l'autre, et son groupe.
String _nommer(CielConstellation c, HierarchieCiel h, LienCiel l) =>
    '${c.villes[h.etoiles[l.de].ville].nom} → '
    '${c.villes[h.etoiles[l.vers].ville].nom} @${l.groupe}';

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
    expect(hierarchieDuCiel(CielConstellation.vide).groupes, isEmpty);
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

    final h = hierarchieDuCiel(ciel);
    expect(_nommer(ciel, h, h.liens.single), 'Paris → Liège @0');
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

  test('une commune toute proche rejoint sa grande ville ; les noms sont '
      'en français', () {
    final ciel = cielConstellation([
      _lieu('Leuven', 50.879, 4.701, DateTime(2020, 1)),
      _lieu('Leuven', 50.878, 4.700, DateTime(2020, 2)),
      // À 2 km du centre de Louvain.
      _lieu('Kessel-Lo', 50.887, 4.725, DateTime(2020, 3)),
      _lieu('Antwerpen', 51.219, 4.402, DateTime(2021, 1)),
      _lieu('Liège', 50.640, 5.570, DateTime(2021, 2)),
      _lieu('Liège', 50.641, 5.571, DateTime(2021, 3)),
      // À 6,5 km : une ville à part.
      _lieu('Seraing', 50.603, 5.505, DateTime(2021, 4)),
    ]);

    expect(
      [for (final v in ciel.villes) v.nom],
      ['Louvain', 'Anvers', 'Liège', 'Seraing'],
    );
    expect(ciel.villes.first.etoiles, hasLength(3));
  });

  test(
    'les restaurants en villes, régions et pays, réunis deux à deux ; '
    'les liens de chaque niveau, entre leurs restaurants les plus proches',
    () {
      final ciel = cielConstellation([
        _lieu('Liège', 50.64, 5.57, DateTime(2020, 1)),
        _lieu('Huy', 50.52, 5.24, DateTime(2020, 6)),
        _lieu('Namur', 50.47, 4.87, DateTime(2021, 1)),
        _lieu('Paris', 48.86, 2.35, DateTime(2022, 1)),
      ]);
      EndroitCiel? endroit(double x, double y) => x < 2.5
          ? const EndroitCiel(
              pays: 'France',
              region: 'Île-de-France',
              sorte: 'Région',
            )
          : EndroitCiel(
              pays: 'Belgique',
              region: x > 5 ? 'Liège' : 'Namur',
              sorte: 'Province',
            );
      final h = hierarchieDuCiel(ciel, endroit);

      // Tout en haut, la Belgique et Paris réunies (sous le nom de la plus
      // grande) ; Paris, seule en France,
      // et Namur, seule dans sa province, n'ont pas de groupe à elles.
      expect(
        [for (final g in h.groupes) g.nom],
        [
          'Belgique',
          'Belgique',
          'Province de Liège',
          'Liège',
          'Huy',
          'Namur',
          'Paris',
        ],
      );
      expect([for (final g in h.groupes) g.parent], [-1, 0, 1, 2, 2, 1, 0]);
      expect(h.groupes[0].etiquette, '4 tables');
      expect(h.groupes[1].etiquette, '3 tables');
      expect(h.groupes[3].ville, 0);
      // Chaque restaurant dans sa ville.
      expect(
        [for (final e in h.etoiles) h.groupes[e.groupe].nom],
        ['Liège', 'Huy', 'Namur', 'Paris'],
      );
      expect(
        {for (final l in h.liens) _nommer(ciel, h, l)},
        {'Namur → Paris @0', 'Huy → Namur @1', 'Liège → Huy @2'},
      );

      // Sans la carte : rien que des villes, réunies entre elles.
      final aPlat = hierarchieDuCiel(ciel);
      expect(aPlat.groupes.where((g) => g.ville >= 0), hasLength(4));
      expect(aPlat.groupes.map((g) => g.nom), isNot(contains('Belgique')));
    },
  );

  test('deux restaurants trop proches ne font qu\'une étoile, qui se '
      'dédouble plus tard que la ville', () {
    final ciel = cielConstellation([
      _lieu('Liège', 50.6400, 5.5700, DateTime(2020, 1), nom: 'Bibo', repas: 5),
      // À 40 mètres.
      _lieu('Liège', 50.6403, 5.5704, DateTime(2020, 2), nom: 'Vin sur vin'),
      // À un kilomètre.
      _lieu('Liège', 50.6490, 5.5700, DateTime(2020, 3), nom: 'Le Phare'),
    ]);
    final h = hierarchieDuCiel(ciel);

    expect([for (final g in h.groupes) g.nom], ['Liège', 'Bibo']);
    expect(h.groupes[1].parent, 0);
    expect(h.groupes[1].etiquette, '2 tables');
    expect(h.groupes[1].ecart, lessThan(h.groupes[0].ecart / 10));
    // Le lien des deux voisins se voit quand ils se séparent.
    expect(h.liens.where((l) => l.groupe == 1), hasLength(1));
  });
}
