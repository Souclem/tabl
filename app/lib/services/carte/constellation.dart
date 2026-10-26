import 'dart:convert';
import 'dart:math' as math;

import '../restaurants/categories_lieu.dart';
import '../souvenirs/presentation_souvenir.dart';
import 'lieu_carte.dart';

/// Une ville de ma Constellation : combien de tables (restaurants) et de
/// repas j'y compte, et quand j'y suis allé la première fois.
class VilleConstellation {
  const VilleConstellation({
    required this.nom,
    required this.tables,
    required this.repas,
    required this.premiere,
    required this.zone,
  });

  final String nom;
  final int tables;
  final int repas;
  final DateTime? premiere;
  final ZoneCarte zone;

  double get latitude => (zone.sud + zone.nord) / 2;
  double get longitude => (zone.ouest + zone.est) / 2;
}

/// Mes villes, dans l'ordre où je les ai découvertes : c'est cet ordre
/// que trace le fil qui les relie (« votre histoire, table par table »).
List<VilleConstellation> villesConstellation(Iterable<LieuCarte> miens) {
  final parVille = <String, List<LieuCarte>>{};
  final noms = <String, String>{};
  for (final l in miens) {
    final nom = l.ville.trim();
    if (nom.isEmpty) continue;
    final cle = normaliserPourRecherche(nom);
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => nom);
  }
  final villes = [
    for (final MapEntry(key: cle, value: ici) in parVille.entries)
      VilleConstellation(
        nom: noms[cle]!,
        tables: ici.length,
        repas: ici.fold(0, (n, l) => n + math.max(l.mesVisites, 1)),
        premiere: ici
            .map((l) => l.maPremiereVisite)
            .whereType<DateTime>()
            .fold<DateTime?>(
              null,
              (a, b) => a == null || b.isBefore(a) ? b : a,
            ),
        zone: ZoneCarte(
          sud: ici.map((l) => l.latitude).reduce(math.min),
          ouest: ici.map((l) => l.longitude).reduce(math.min),
          nord: ici.map((l) => l.latitude).reduce(math.max),
          est: ici.map((l) => l.longitude).reduce(math.max),
        ),
      ),
  ];
  final lointain = DateTime(9999);
  villes.sort(
    (a, b) => (a.premiere ?? lointain).compareTo(b.premiere ?? lointain),
  );
  return villes;
}

/// « 35 repas » et « 5 villes ».
({int repas, int villes}) compteursConstellation(Iterable<LieuCarte> miens) {
  final villes = villesConstellation(miens);
  return (repas: villes.fold(0, (n, v) => n + v.repas), villes: villes.length);
}

/// "10 tables · 22 repas".
String tablesEtRepas(int tables, int repas) =>
    // « repas » ne prend pas de s.
    '${pluriel(tables, 'table')} · $repas repas';

/// Ma Constellation au format GeoJSON : les villes (avec leur étiquette),
/// le fil qui les relie dans l'ordre, et chaque restaurant en étoile,
/// d'autant plus grande que j'y suis allé souvent.
String geojsonConstellation(List<LieuCarte> miens, {String? cleChoisie}) {
  final villes = villesConstellation(miens);
  Map<String, Object> point(double latitude, double longitude) => {
    'type': 'Point',
    'coordinates': [longitude, latitude],
  };
  return jsonEncode({
    'type': 'FeatureCollection',
    'features': [
      if (villes.length > 1)
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final v in villes) [v.longitude, v.latitude],
            ],
          },
          'properties': {'type': 'sillage'},
        },
      for (final v in villes)
        {
          'type': 'Feature',
          'geometry': point(v.latitude, v.longitude),
          'properties': {
            'type': 'ville',
            'cle': 'ville:${v.nom}',
            'repas': v.repas,
            'etiquette':
                '${v.nom.toUpperCase()}\n${pluriel(v.tables, 'table')}',
          },
        },
      for (final l in miens)
        {
          'type': 'Feature',
          'geometry': point(l.latitude, l.longitude),
          'properties': {
            'type': 'etoile',
            'cle': l.cle,
            'fois': math.max(l.mesVisites, 1),
            if (l.cle == cleChoisie) 'choisi': true,
          },
        },
    ],
  });
}

/// "6 repas · août 2026" : combien de fois, et la dernière.
String repasEtDerniere(LieuCarte lieu) {
  final fois = math.max(lieu.mesVisites, 1);
  final d = lieu.maDerniereVisite;
  return [
    fois == 1 ? 'Une fois' : '$fois repas',
    if (d != null) '${nomDuMois(d.month)} ${d.year}',
  ].join(' · ');
}

/// Mes lieux d'une ville, du plus fréquenté au moins fréquenté.
List<LieuCarte> lieuxDeLaVille(Iterable<LieuCarte> miens, String ville) {
  final cle = normaliserPourRecherche(ville);
  return [
    for (final l in miens)
      if (normaliserPourRecherche(l.ville.trim()) == cle) l,
  ]..sort(
    (a, b) => b.mesVisites != a.mesVisites
        ? b.mesVisites.compareTo(a.mesVisites)
        : (b.maDerniereVisite ?? DateTime(0)).compareTo(
            a.maDerniereVisite ?? DateTime(0),
          ),
  );
}
