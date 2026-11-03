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
  test('les villes, dans l\'ordre de découverte ; la maison est là où l\'on '
      'mange le plus', () {
    final ciel = cielConstellation([
      _lieu('Paris', 48.86, 2.35, DateTime(2019, 4), repas: 2),
      _lieu('Liège', 50.64, 5.57, DateTime(2020, 1), repas: 6),
      _lieu('liege', 50.65, 5.58, DateTime(2021, 3), repas: 3),
      _lieu('', 0, 0, DateTime(2020)),
    ]);

    expect([for (final v in ciel.villes) v.nom], ['Paris', 'Liège']);
    expect(ciel.villes[1].etoiles, hasLength(2));
    expect(ciel.villes[1].etiquette, '2 tables');
    expect(ciel.maison, 1);
    expect(ciel.compteurs, '3 tables · 11 repas · 2 villes');
    expect(cielConstellation(const []).estVide, isTrue);
  });

  test('dans une ville, chaque nouvelle adresse se rattache à la plus proche '
      'de celles déjà connues', () {
    final ciel = cielConstellation([
      _lieu('Liège', 50.640, 5.570, DateTime(2020, 1), nom: 'A'),
      _lieu('Liège', 50.640, 5.600, DateTime(2020, 2), nom: 'B'),
      _lieu('Liège', 50.641, 5.571, DateTime(2020, 3), nom: 'C'),
      _lieu('Liège', 50.640, 5.601, DateTime(2020, 4), nom: 'D'),
    ]);
    final v = ciel.villes.single;
    final noms = [
      for (final l in ciel.liensDansVilles.single)
        '${v.etoiles[l.de].nom}→${v.etoiles[l.vers].nom}',
    ];

    expect(noms, ['A→B', 'A→C', 'B→D']);
  });

  test('chaque voyage part de la maison ; ses villes se suivent ; les '
      'sorties proches y sont reliées directement', () {
    final ciel = cielConstellation([
      _lieu('Liège', 50.64, 5.57, DateTime(2019, 9), repas: 9),
      _lieu('Bruxelles', 50.85, 4.35, DateTime(2020, 2)),
      _lieu('Tokyo', 35.68, 139.65, DateTime(2023, 3, 1)),
      // Un mois après Tokyo : le même voyage.
      _lieu('Kyoto', 35.01, 135.77, DateTime(2023, 4, 1)),
      // Une sortie au milieu du voyage ne le coupe pas.
      _lieu('Namur', 50.47, 4.87, DateTime(2023, 4, 2)),
      // Six mois plus tard : un nouveau voyage, depuis la maison.
      _lieu('Séoul', 37.57, 126.98, DateTime(2023, 10, 1)),
    ]);

    expect([for (final l in ciel.liensEntreVilles) _nommer(ciel, l)], [
      'Liège → Bruxelles',
      'Liège → Tokyo',
      'Tokyo → Kyoto',
      'Liège → Namur',
      'Liège → Séoul',
    ]);
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
    expect(distanceCielKm(5.57, mercY(50.64), 4.35, mercY(50.85)), closeTo(89, 2));
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
