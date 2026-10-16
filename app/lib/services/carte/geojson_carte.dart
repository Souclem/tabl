import 'dart:convert';

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
            'visites': lieu.visites,
            'envie': lieu.estEnvie,
            // Visité par mon réseau ou en envie : marqueur plein ; sinon
            // petit point (un restaurant de l'annuaire).
            'reseau': lieu.duReseau,
            // Le lieu dont la feuille est ouverte : marqueur agrandi.
            if (lieu.cle == cleChoisie) 'choisi': true,
            // Bulle photo de l'ami en avant, avec « +N » autres amis.
            'photo': ?lieu.amiEnAvant?.photoUrl,
            'autres': ?lieu.amiEnAvant?.autres,
          },
        },
    ],
  });
}
