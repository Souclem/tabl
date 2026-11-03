import 'dart:math' as math;

import '../restaurants/categories_lieu.dart';
import '../souvenirs/presentation_souvenir.dart';
import 'lieu_carte.dart';

/// Mercator, en degrés : x = longitude, y = cette valeur, croissante vers
/// le sud comme l'écran.
double mercY(double latitude) =>
    -math.log(math.tan(math.pi / 4 + latitude * math.pi / 360)) * 180 / math.pi;

/// L'inverse de [mercY].
double latitudeDepuisMercY(double y) =>
    (2 * math.atan(math.exp(-y * math.pi / 180)) - math.pi / 2) * 180 / math.pi;

/// Un restaurant de ma Constellation : une étoile, d'autant plus brillante
/// que j'y ai mangé souvent.
class EtoileCiel {
  const EtoileCiel({
    required this.cle,
    required this.nom,
    required this.x,
    required this.y,
    required this.repas,
    required this.premiere,
  });

  /// [LieuCarte.cle].
  final String cle;
  final String nom;

  /// Position, en coordonnées du ciel (voir [mercY]).
  final double x;
  final double y;
  final int repas;

  /// Mon premier repas ici.
  final DateTime premiere;

  /// Dorée à partir de trois repas.
  bool get doree => repas >= 3;
}

/// Une ville de ma Constellation : de loin une étoile, de près ses
/// restaurants.
class VilleCiel {
  const VilleCiel({
    required this.nom,
    required this.debut,
    required this.etoiles,
    required this.cx,
    required this.cy,
    required this.rayon,
    required this.repas,
    required this.entree,
    required this.etiquette,
  });

  final String nom;

  /// Mon premier repas dans cette ville.
  final DateTime debut;
  final List<EtoileCiel> etoiles;

  /// Le centre des restaurants, et la distance (au 80e centile) qui les
  /// contient presque tous : c'est elle qui dit quand la ville s'ouvre.
  final double cx;
  final double cy;
  final double rayon;
  final int repas;

  /// L'indice, dans [etoiles], du premier restaurant connu ici : les
  /// liens entre villes y arrivent.
  final int entree;

  /// « 24 tables ».
  final String etiquette;
}

/// Un lien entre deux étoiles (indices), orienté de la plus ancienne
/// ([de]) vers l'autre : ce qui y circule va dans ce sens.
class LienCiel {
  const LienCiel(this.de, this.vers);

  final int de;
  final int vers;

  @override
  bool operator ==(Object other) =>
      other is LienCiel && other.de == de && other.vers == vers;

  @override
  int get hashCode => Object.hash(de, vers);

  @override
  String toString() => '$de→$vers';
}

/// Tout le ciel, prêt à dessiner.
class CielConstellation {
  const CielConstellation({
    required this.villes,
    required this.liensDansVilles,
    required this.liensEntreVilles,
    required this.compteurs,
  });

  static const vide = CielConstellation(
    villes: [],
    liensDansVilles: [],
    liensEntreVilles: [],
    compteurs: '',
  );

  /// Dans l'ordre où je les ai découvertes.
  final List<VilleCiel> villes;

  /// Pour chaque ville, ses liens (indices dans [VilleCiel.etoiles]).
  final List<List<LienCiel>> liensDansVilles;

  /// Entre les villes (indices dans [villes]).
  final List<LienCiel> liensEntreVilles;

  /// « 298 tables · 971 repas · 55 villes ».
  final String compteurs;

  bool get estVide => villes.isEmpty;
}

/// La distance à vol d'oiseau entre deux points du ciel, en kilomètres.
double distanceCielKm(double x1, double y1, double x2, double y2) {
  final la = latitudeDepuisMercY(y1) * math.pi / 180;
  final lb = latitudeDepuisMercY(y2) * math.pi / 180;
  final dl = (x2 - x1) * math.pi / 180;
  final h =
      math.pow(math.sin((lb - la) / 2), 2) +
      math.cos(la) * math.cos(lb) * math.pow(math.sin(dl / 2), 2);
  return 12742 * math.asin(math.sqrt(h));
}

/// Ma Constellation : mes restaurants, regroupés par ville, et ses liens :
/// le maillage « Dense » (voir [liensDenses]), entre les villes comme dans
/// chacune. Chaque lien va du lieu découvert en premier vers l'autre.
CielConstellation cielConstellation(Iterable<LieuCarte> miens) {
  final parVille = <String, List<LieuCarte>>{};
  final noms = <String, String>{};
  final sansVille = <LieuCarte>[];
  for (final l in miens) {
    final nom = l.ville.trim();
    if (nom.isEmpty) {
      sansVille.add(l);
      continue;
    }
    final cle = normaliserPourRecherche(nom);
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => nom);
  }
  _rattacherSansVille(sansVille, parVille, noms);
  if (parVille.isEmpty) return CielConstellation.vide;

  final villes = [
    for (final MapEntry(key: cle, value: lieux) in parVille.entries)
      _ville(noms[cle]!, lieux),
  ]..sort((a, b) => a.debut.compareTo(b.debut));

  final tables = villes.fold(0, (n, v) => n + v.etoiles.length);
  final repas = villes.fold(0, (n, v) => n + v.repas);
  return CielConstellation(
    villes: villes,
    liensDansVilles: [
      for (final v in villes)
        _orienter(
          liensDenses([for (final e in v.etoiles) (e.x, e.y)]),
          (i) => v.etoiles[i].premiere,
        ),
    ],
    liensEntreVilles: _orienter(
      liensDenses([for (final v in villes) (v.cx, v.cy)]),
      (i) => villes[i].debut,
    ),
    compteurs:
        '${pluriel(tables, 'table')} · $repas repas · '
        '${pluriel(villes.length, 'ville')}',
  );
}

/// Plus loin que ça de toute ville, une adresse sans nom de ville est
/// « Ailleurs ».
const _rattachementKm = 30.0;

/// Les adresses sans nom de ville (fréquentes dans l'annuaire) : avec la
/// ville la plus proche, à moins de [_rattachementKm] ; sinon « Ailleurs ».
void _rattacherSansVille(
  List<LieuCarte> sansVille,
  Map<String, List<LieuCarte>> parVille,
  Map<String, String> noms,
) {
  if (sansVille.isEmpty) return;
  final centres = {
    for (final MapEntry(key: cle, value: lieux) in parVille.entries)
      cle: (
        x: lieux.fold(0.0, (n, l) => n + l.longitude) / lieux.length,
        y: lieux.fold(0.0, (n, l) => n + mercY(l.latitude)) / lieux.length,
      ),
  };
  for (final l in sansVille) {
    String? proche;
    var dmin = _rattachementKm;
    for (final MapEntry(key: cle, value: c) in centres.entries) {
      final d = distanceCielKm(l.longitude, mercY(l.latitude), c.x, c.y);
      if (d < dmin) {
        dmin = d;
        proche = cle;
      }
    }
    final cle = proche ?? '\u0000ailleurs';
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => 'Ailleurs');
  }
}

VilleCiel _ville(String nom, List<LieuCarte> lieux) {
  final etoiles = [
    for (final l in lieux)
      EtoileCiel(
        cle: l.cle,
        nom: l.nom,
        x: l.longitude,
        y: mercY(l.latitude),
        repas: math.max(1, l.mesVisites),
        premiere: l.maPremiereVisite ?? l.maDerniereVisite ?? DateTime(2000),
      ),
  ]..sort((a, b) => a.premiere.compareTo(b.premiere));
  final cx = etoiles.fold(0.0, (n, e) => n + e.x) / etoiles.length;
  final cy = etoiles.fold(0.0, (n, e) => n + e.y) / etoiles.length;
  final distances = [
    for (final e in etoiles)
      math.sqrt(math.pow(e.x - cx, 2) + math.pow(e.y - cy, 2)),
  ]..sort();
  return VilleCiel(
    nom: nom,
    debut: etoiles.first.premiere,
    etoiles: etoiles,
    cx: cx,
    cy: cy,
    rayon: math.max(0.004, distances[(distances.length * 0.8).floor()]),
    repas: etoiles.fold(0, (n, e) => n + e.repas),
    entree: 0,
    etiquette: pluriel(etoiles.length, 'table'),
  );
}

/// Chaque lien va du lieu découvert en premier ([date]) vers l'autre.
List<LienCiel> _orienter(List<(int, int)> liens, DateTime Function(int) date) =>
    [
      for (final (a, b) in liens)
        date(b).isBefore(date(a)) ? LienCiel(b, a) : LienCiel(a, b),
    ];

/// Les liens « Dense » entre des points : un maillage en triangles, jamais
/// croisé, sans ses traits démesurés.
///
/// · L'arbre des plus proches voisins : chaque point relié, le moins de
///   traits possible ;
/// · plus les liens de Gabriel : aucun autre point dans le cercle qui a le
///   lien pour diamètre ;
/// · plus ceux de la triangulation (Delaunay), sauf s'ils dépassent 1,8 fois
///   le plus long lien de l'arbre qui part de leurs deux points.
List<(int, int)> liensDenses(List<(double, double)> points) {
  final n = points.length;
  if (n < 2) return const [];
  double d2(int i, int j) {
    final dx = points[i].$1 - points[j].$1, dy = points[i].$2 - points[j].$2;
    return dx * dx + dy * dy;
  }

  final vus = <int>{};
  final liens = <(int, int)>[];
  void ajouter(int i, int j) {
    final cle = i < j ? i * n + j : j * n + i;
    if (vus.add(cle)) liens.add((i, j));
  }

  final base = _arbre(n, d2);
  for (final (i, j) in base) {
    ajouter(i, j);
  }
  // Le plus long lien de l'arbre qui part de chaque point : l'échelle locale.
  final echelle = List.filled(n, 0.0);
  for (final (i, j) in base) {
    final d = d2(i, j);
    echelle[i] = math.max(echelle[i], d);
    echelle[j] = math.max(echelle[j], d);
  }
  for (final (i, j) in _triangulation(points)) {
    final ab = d2(i, j);
    // Gabriel : personne d'autre dans le cercle de diamètre [i, j].
    final mx = (points[i].$1 + points[j].$1) / 2;
    final my = (points[i].$2 + points[j].$2) / 2;
    var gabriel = true;
    for (var k = 0; k < n && gabriel; k++) {
      if (k == i || k == j) continue;
      final dx = points[k].$1 - mx, dy = points[k].$2 - my;
      gabriel = dx * dx + dy * dy >= ab / 4;
    }
    if (gabriel || ab <= 1.8 * 1.8 * math.max(echelle[i], echelle[j])) {
      ajouter(i, j);
    }
  }
  return liens;
}

/// L'arbre des plus proches voisins (Prim).
List<(int, int)> _arbre(int n, double Function(int, int) d2) {
  final dans = List.filled(n, false)..[0] = true;
  final meilleure = List.filled(n, double.infinity);
  final parent = List.filled(n, 0);
  for (var j = 1; j < n; j++) {
    meilleure[j] = d2(0, j);
  }
  final liens = <(int, int)>[];
  for (var fois = 1; fois < n; fois++) {
    var j = -1;
    for (var k = 0; k < n; k++) {
      if (!dans[k] && (j < 0 || meilleure[k] < meilleure[j])) j = k;
    }
    dans[j] = true;
    liens.add((parent[j], j));
    for (var k = 0; k < n; k++) {
      if (dans[k]) continue;
      final d = d2(j, k);
      if (d < meilleure[k]) {
        meilleure[k] = d;
        parent[k] = j;
      }
    }
  }
  return liens;
}

/// Les arêtes de la triangulation de Delaunay (Bowyer-Watson).
List<(int, int)> _triangulation(List<(double, double)> points) {
  final n = points.length;
  if (n < 3) return n == 2 ? const [(0, 1)] : const [];
  // Deux adresses au même endroit : un soupçon d'écart pour les séparer.
  final p = [
    for (var i = 0; i < n; i++)
      (points[i].$1 + i * 1e-9, points[i].$2 + (i % 7) * 1e-9),
  ];
  var xmin = double.infinity, xmax = -double.infinity;
  var ymin = double.infinity, ymax = -double.infinity;
  for (final (x, y) in p) {
    xmin = math.min(xmin, x);
    xmax = math.max(xmax, x);
    ymin = math.min(ymin, y);
    ymax = math.max(ymax, y);
  }
  final d = math.max(math.max(xmax - xmin, ymax - ymin), 1e-6) * 20;
  final cx = (xmin + xmax) / 2, cy = (ymin + ymax) / 2;
  // Un grand triangle qui contient tout, retiré à la fin.
  p
    ..add((cx - d, cy - d))
    ..add((cx + d, cy - d))
    ..add((cx, cy + d));
  final triangles = <_Triangle>[_Triangle(n, n + 1, n + 2, p)];
  for (var i = 0; i < n; i++) {
    final (x, y) = p[i];
    final mauvais = triangles.where((t) => t.contient(x, y)).toList();
    final bords = <(int, int), int>{};
    for (final t in mauvais) {
      for (final (a, b) in t.cotes) {
        final cle = a < b ? (a, b) : (b, a);
        bords[cle] = (bords[cle] ?? 0) + 1;
      }
    }
    triangles.removeWhere(mauvais.contains);
    for (final MapEntry(key: (a, b), value: fois) in bords.entries) {
      if (fois == 1) triangles.add(_Triangle(a, b, i, p));
    }
  }
  final aretes = <(int, int)>{};
  for (final t in triangles) {
    for (final (a, b) in t.cotes) {
      if (a < n && b < n) aretes.add(a < b ? (a, b) : (b, a));
    }
  }
  return aretes.toList();
}

class _Triangle {
  _Triangle(this.a, this.b, this.c, List<(double, double)> p) {
    final (ax, ay) = p[a];
    final (bx, by) = p[b];
    final (cx, cy) = p[c];
    final d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by));
    final a2 = ax * ax + ay * ay,
        b2 = bx * bx + by * by,
        c2 = cx * cx + cy * cy;
    ux = (a2 * (by - cy) + b2 * (cy - ay) + c2 * (ay - by)) / d;
    uy = (a2 * (cx - bx) + b2 * (ax - cx) + c2 * (bx - ax)) / d;
    r2 = (ax - ux) * (ax - ux) + (ay - uy) * (ay - uy);
  }

  final int a;
  final int b;
  final int c;
  late final double ux;
  late final double uy;
  late final double r2;

  List<(int, int)> get cotes => [(a, b), (b, c), (c, a)];

  bool contient(double x, double y) =>
      (x - ux) * (x - ux) + (y - uy) * (y - uy) < r2;
}

/// Ce que dit la fiche d'une étoile qu'on touche.
({String nom, String detail, String depuis, bool retour}) ficheEtoile(
  EtoileCiel etoile,
  String ville,
) => (
  nom: etoile.nom,
  detail: '$ville · ${etoile.repas} repas',
  depuis:
      'Première fois en ${nomDuMois(etoile.premiere.month)} '
      '${etoile.premiere.year}',
  retour: etoile.doree,
);
