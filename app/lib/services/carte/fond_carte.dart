import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ciel_constellation.dart';

/// Un tracé de la carte en coordonnées du ciel ([mercY]) : x, y, x, y…, et
/// son emprise (pour ne dessiner que ce qui se voit).
class TraceCarte {
  TraceCarte(this.points)
    : xmin = _min(points, 0),
      xmax = _max(points, 0),
      ymin = _min(points, 1),
      ymax = _max(points, 1);

  final Float64List points;
  final double xmin;
  final double xmax;
  final double ymin;
  final double ymax;

  static double _min(Float64List p, int depart) {
    var m = double.infinity;
    for (var i = depart; i < p.length; i += 2) {
      if (p[i] < m) m = p[i];
    }
    return m;
  }

  static double _max(Float64List p, int depart) {
    var m = double.negativeInfinity;
    for (var i = depart; i < p.length; i += 2) {
      if (p[i] > m) m = p[i];
    }
    return m;
  }
}

/// Des routes qui apparaissent ensemble, à partir de [zoom] (échelle des
/// cartes web : 0 le monde entier, 13 une ville).
class NiveauRoutes {
  const NiveauRoutes({
    required this.zoom,
    required this.autoroute,
    required this.traces,
  });

  final double zoom;
  final bool autoroute;
  final List<TraceCarte> traces;
}

/// Le fond de la Constellation : les terres, les frontières entre pays et
/// les grandes routes (Natural Earth, domaine public).
class FondCarte {
  const FondCarte({
    required this.terres,
    required this.frontieres,
    required this.routes,
  });

  final List<TraceCarte> terres;
  final List<TraceCarte> frontieres;
  final List<NiveauRoutes> routes;
}

/// Lit les trois fichiers de `assets/carte/`, hors du fil de l'interface.
Future<FondCarte> chargerFondCarte([AssetBundle? bundle]) async {
  final b = bundle ?? rootBundle;
  final textes = await Future.wait([
    b.loadString('assets/carte/terres.json'),
    b.loadString('assets/carte/frontieres.json'),
    b.loadString('assets/carte/routes.json'),
  ]);
  return compute(_decoder, textes);
}

FondCarte _decoder(List<String> textes) => fondCarteDepuisJson(
  terres: textes[0],
  frontieres: textes[1],
  routes: textes[2],
);

/// Terres et frontières : [lon×100, lat×100, …] par tracé. Routes :
/// [[zoom, autoroute (0/1), [tracé…]], …], chaque tracé en lon×1000,
/// lat×1000 puis en écarts successifs.
FondCarte fondCarteDepuisJson({
  required String terres,
  required String frontieres,
  required String routes,
}) {
  List<TraceCarte> traces(String json) => [
    for (final t in (jsonDecode(json) as List).cast<List>())
      TraceCarte(_versCiel([for (final v in t) (v as num) / 100])),
  ];
  return FondCarte(
    terres: traces(terres),
    frontieres: traces(frontieres),
    routes: [
      for (final niveau in (jsonDecode(routes) as List).cast<List>())
        NiveauRoutes(
          zoom: (niveau[0] as num).toDouble(),
          autoroute: niveau[1] == 1,
          traces: [
            for (final t in (niveau[2] as List).cast<List>())
              TraceCarte(_versCiel(_cumuler(t, 1000))),
          ],
        ),
    ],
  );
}

List<double> _cumuler(List t, double echelle) {
  final sortie = <double>[];
  var x = 0, y = 0;
  for (var i = 0; i < t.length; i += 2) {
    x += t[i] as int;
    y += t[i + 1] as int;
    sortie
      ..add(x / echelle)
      ..add(y / echelle);
  }
  return sortie;
}

/// Longitudes, latitudes → coordonnées du ciel. Un tracé à cheval sur la
/// ligne de changement de date reste d'un seul tenant.
Float64List _versCiel(List<double> lonLat) {
  final p = Float64List(lonLat.length);
  double? precedente;
  for (var i = 0; i < lonLat.length; i += 2) {
    var x = lonLat[i];
    final avant = precedente;
    if (avant != null) {
      while (x - avant > 180) {
        x -= 360;
      }
      while (avant - x > 180) {
        x += 360;
      }
    }
    precedente = x;
    p[i] = x;
    p[i + 1] = mercY(lonLat[i + 1]);
  }
  return p;
}
