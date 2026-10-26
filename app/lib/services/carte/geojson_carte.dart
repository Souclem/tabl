import 'dart:convert';

import '../position/position_service.dart';
import '../restaurants/lieu_restaurant.dart';
import 'lieu_carte.dart';

/// Les lieux au format GeoJSON, tel que Mapbox l'attend pour une source.
/// Chaque point porte sa [LieuCarte.cle] (pour retrouver le lieu au tap)
/// et ce qui sert à son apparence.
String geojsonLieux(Iterable<LieuCarte> lieux, {String? cleChoisie}) {
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final lieu in lieux)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [lieu.longitude, lieu.latitude],
          },
          'properties': {
            'cle': lieu.cle,
            // Le chiffre de la petite bulle : les amis qui y sont allés.
            'amis': lieu.amis,
            // Le lieu dont la feuille est ouverte : marqueur agrandi.
            if (lieu.cle == cleChoisie) 'choisi': true,
          },
        },
    ],
  });
}

/// Les restaurants parmi lesquels choisir celui d'un souvenir, et les
/// endroits des photos ([reperes]) : des points à part, qu'on ne touche
/// pas.
String geojsonChoixLieux(
  Iterable<LieuRestaurant> lieux, {
  List<Coordonnees> reperes = const [],
  String? cleChoisie,
}) {
  Map<String, Object> point(double latitude, double longitude) => {
    'type': 'Point',
    'coordinates': [longitude, latitude],
  };
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      for (final repere in reperes)
        {
          'type': 'Feature',
          'geometry': point(repere.latitude, repere.longitude),
          'properties': {'repere': true},
        },
      for (final lieu in lieux)
        if (lieu.latitude != null && lieu.longitude != null)
          {
            'type': 'Feature',
            'geometry': point(lieu.latitude!, lieu.longitude!),
            'properties': {
              'cle': lieu.cle,
              if (lieu.cle == cleChoisie) 'choisi': true,
            },
          },
    ],
  });
}
