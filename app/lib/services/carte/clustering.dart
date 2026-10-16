import 'dart:math' as math;

import 'objet_cartographique.dart';

/// Regroupe des restaurants proches en [ClusterRestaurants] selon une
/// grille de [rayonDegres] de côté — plus le rayon est grand (zoom
/// arrière), plus les regroupements sont larges. Un restaurant seul
/// dans sa case de grille reste un [RestaurantMarqueur] individuel : la
/// règle absolue du megaprompt Bloc 1 (règle 24) est respectée par
/// construction, un objet donné n'est jamais à la fois affiché comme
/// cluster et comme enfant — c'est soit l'un, soit l'autre.
///
/// Fonction pure, indépendante de tout SDK cartographique : c'est le
/// calcul, il vit ici plutôt que dans un widget (voir "la règle
/// d'organisation" de CLAUDE.md).
List<ObjetCartographique> regrouperEnClusters(
  List<RestaurantMarqueur> restaurants, {
  required double rayonDegres,
}) {
  if (restaurants.isEmpty) return const [];
  if (rayonDegres <= 0) return restaurants;

  final parCase = <String, List<RestaurantMarqueur>>{};
  for (final r in restaurants) {
    final cle =
        '${(r.latitude / rayonDegres).floor()}:${(r.longitude / rayonDegres).floor()}';
    parCase.putIfAbsent(cle, () => []).add(r);
  }

  final resultat = <ObjetCartographique>[];
  for (final groupe in parCase.values) {
    if (groupe.length == 1) {
      resultat.add(groupe.single);
      continue;
    }

    double latMin = groupe.first.latitude;
    double latMax = groupe.first.latitude;
    double lngMin = groupe.first.longitude;
    double lngMax = groupe.first.longitude;
    double sommeLat = 0;
    double sommeLng = 0;
    for (final r in groupe) {
      latMin = math.min(latMin, r.latitude);
      latMax = math.max(latMax, r.latitude);
      lngMin = math.min(lngMin, r.longitude);
      lngMax = math.max(lngMax, r.longitude);
      sommeLat += r.latitude;
      sommeLng += r.longitude;
    }

    resultat.add(
      ClusterRestaurants(
        latitude: sommeLat / groupe.length,
        longitude: sommeLng / groupe.length,
        idsRestaurants: groupe.map((r) => r.id).toList(),
        latitudeMin: latMin,
        latitudeMax: latMax,
        longitudeMin: lngMin,
        longitudeMax: lngMax,
      ),
    );
  }
  return resultat;
}
