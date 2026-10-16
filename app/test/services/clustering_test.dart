import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

RestaurantMarqueur _resto(String id, double lat, double lng) {
  return RestaurantMarqueur(
    id: id,
    nom: id,
    ville: 'Paris',
    quartier: null,
    latitude: lat,
    longitude: lng,
    taille: TailleMarqueur.small,
    procheDirectCompte: 1,
    procheDirectResume: '',
    aDeLaRecurrence: false,
    dejaVisiteParMoi: false,
    dejaGardeParMoi: false,
  );
}

void main() {
  group('regrouperEnClusters', () {
    test('une liste vide retourne une liste vide', () {
      expect(regrouperEnClusters(const [], rayonDegres: 0.01), isEmpty);
    });

    test('un restaurant seul dans sa case reste un marqueur individuel', () {
      final resultat = regrouperEnClusters(
        [_resto('a', 48.85, 2.35)],
        rayonDegres: 0.01,
      );

      expect(resultat, hasLength(1));
      expect(resultat.single, isA<RestaurantMarqueur>());
    });

    test('des restaurants proches sont regroupés en un cluster', () {
      final resultat = regrouperEnClusters(
        [
          _resto('a', 48.8500, 2.3500),
          _resto('b', 48.8501, 2.3501),
          _resto('c', 48.8502, 2.3502),
        ],
        rayonDegres: 0.01,
      );

      expect(resultat, hasLength(1));
      final cluster = resultat.single as ClusterRestaurants;
      expect(cluster.nombreRestaurants, 3);
      expect(cluster.idsRestaurants, containsAll(['a', 'b', 'c']));
    });

    test('cluster ou enfants, jamais les deux : les ids regroupés ne '
        'réapparaissent jamais comme marqueurs individuels dans le même '
        'résultat', () {
      final resultat = regrouperEnClusters(
        [
          _resto('a', 48.8500, 2.3500),
          _resto('b', 48.8501, 2.3501),
          _resto('c', 60.1, 24.9), // loin, reste seul
        ],
        rayonDegres: 0.01,
      );

      expect(resultat, hasLength(2));
      final cluster = resultat.whereType<ClusterRestaurants>().single;
      final individuel = resultat.whereType<RestaurantMarqueur>().single;
      expect(cluster.idsRestaurants, containsAll(['a', 'b']));
      expect(individuel.id, 'c');
    });

    test('des restaurants éloignés restent des marqueurs distincts', () {
      final resultat = regrouperEnClusters(
        [_resto('a', 48.85, 2.35), _resto('b', 60.1, 24.9)],
        rayonDegres: 0.01,
      );

      expect(resultat, hasLength(2));
      expect(resultat.every((o) => o is RestaurantMarqueur), isTrue);
    });
  });
}
