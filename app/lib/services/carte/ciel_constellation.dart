import 'dart:math' as math;

import '../restaurants/categories_lieu.dart';
import '../souvenirs/presentation_souvenir.dart';
import 'lieu_carte.dart';
import 'noms_villes.dart';

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
  const LienCiel(this.de, this.vers, {this.groupe = -1});

  final int de;
  final int vers;

  /// Entre deux villes : le groupe (indice dans [HierarchieCiel.groupes])
  /// dont il relie deux parties, -1 entre ce qui n'a pas de groupe.
  final int groupe;

  @override
  bool operator ==(Object other) =>
      other is LienCiel &&
      other.de == de &&
      other.vers == vers &&
      other.groupe == groupe;

  @override
  int get hashCode => Object.hash(de, vers, groupe);

  @override
  String toString() => '$de→$vers';
}

/// Tout le ciel, prêt à dessiner.
class CielConstellation {
  const CielConstellation({
    required this.villes,
    required this.liensDansVilles,
    required this.compteurs,
  });

  static const vide = CielConstellation(
    villes: [],
    liensDansVilles: [],
    compteurs: '',
  );

  /// Dans l'ordre où je les ai découvertes.
  final List<VilleCiel> villes;

  /// Pour chaque ville, ses liens (indices dans [VilleCiel.etoiles]). Entre
  /// les villes : voir [hierarchieDuCiel].
  final List<List<LienCiel>> liensDansVilles;

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

/// Ma Constellation : mes restaurants, regroupés par ville (en français,
/// une commune toute proche avec sa grande ville), et les liens de chaque
/// ville : le maillage « Dense » (voir [liensDenses]), chaque lien du lieu
/// découvert en premier vers l'autre.
CielConstellation cielConstellation(Iterable<LieuCarte> miens) {
  final parVille = <String, List<LieuCarte>>{};
  final noms = <String, String>{};
  final sansVille = <LieuCarte>[];
  for (final l in miens) {
    final nom = nomFrancaisVille(l.ville.trim());
    if (nom.isEmpty) {
      sansVille.add(l);
      continue;
    }
    final cle = normaliserPourRecherche(nom);
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => nom);
  }
  _fusionnerCommunes(parVille);
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
    compteurs:
        '${pluriel(tables, 'table')} · $repas repas · '
        '${pluriel(villes.length, 'ville')}',
  );
}

/// Plus près que ça d'une ville qui a plus de restaurants, une commune la
/// rejoint : Kessel-Lo est à Louvain, Ixelles à Bruxelles.
const _communeKm = 6.0;

({double x, double y}) _centre(List<LieuCarte> lieux) => (
  x: lieux.fold(0.0, (n, l) => n + l.longitude) / lieux.length,
  y: lieux.fold(0.0, (n, l) => n + mercY(l.latitude)) / lieux.length,
);

void _fusionnerCommunes(Map<String, List<LieuCarte>> parVille) {
  int repas(String cle) =>
      parVille[cle]!.fold(0, (n, l) => n + math.max(1, l.mesVisites));
  // Les plus grandes d'abord : ce sont elles qui accueillent.
  final cles = parVille.keys.toList()
    ..sort((a, b) {
      final parTaille = parVille[b]!.length.compareTo(parVille[a]!.length);
      if (parTaille != 0) return parTaille;
      final parRepas = repas(b).compareTo(repas(a));
      return parRepas != 0 ? parRepas : a.compareTo(b);
    });
  final gardees = <(String, ({double x, double y}))>[];
  for (final cle in cles) {
    final c = _centre(parVille[cle]!);
    String? proche;
    var dmin = _communeKm;
    for (final (autre, ca) in gardees) {
      final d = distanceCielKm(c.x, c.y, ca.x, ca.y);
      if (d < dmin) {
        dmin = d;
        proche = autre;
      }
    }
    if (proche == null) {
      gardees.add((cle, c));
    } else {
      parVille[proche]!.addAll(parVille.remove(cle)!);
    }
  }
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
      cle: _centre(lieux),
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

/// Où tombe un point du ciel : son pays et sa région (« Belgique »,
/// « Liège », « Province »).
class EndroitCiel {
  const EndroitCiel({
    required this.pays,
    required this.region,
    required this.sorte,
  });

  final String pays;
  final String region;

  /// « Province », « Région », « État »… : pour nommer une région qui porte
  /// le nom d'une de ses villes (« Province de Liège »).
  final String sorte;
}

/// Un groupe de mes villes : un pays, ou une région d'un pays. De loin une
/// seule étoile, qui s'ouvre sur ce qu'il contient.
class GroupeCiel {
  const GroupeCiel({
    required this.nom,
    required this.etiquette,
    required this.parent,
    required this.villes,
    required this.cx,
    required this.cy,
    required this.ecart,
    required this.tables,
  });

  final String nom;

  /// « 137 tables ».
  final String etiquette;

  /// Le groupe qui le contient (indice dans [HierarchieCiel.groupes],
  /// toujours avant lui), -1 pour un pays.
  final int parent;

  /// Ses villes à lui, hors de ses sous-groupes (indices dans
  /// [CielConstellation.villes]).
  final List<int> villes;

  /// Le centre de toutes ses villes.
  final double cx;
  final double cy;

  /// L'écart habituel entre ce qu'il contient (la médiane des distances au
  /// plus proche voisin) : il ne s'ouvre que quand cet écart a la place de
  /// se voir à l'écran.
  final double ecart;
  final int tables;
}

/// Mes villes regroupées en pays et en régions, et leurs liens.
class HierarchieCiel {
  const HierarchieCiel({required this.groupes, required this.liens});

  /// Les parents avant leurs enfants.
  final List<GroupeCiel> groupes;

  /// Entre les villes : le maillage « Dense » entre les parties de chaque
  /// groupe (et entre ce qui n'a pas de groupe), chaque lien posé entre les
  /// deux villes les plus proches de ses deux parties. De loin, un lien
  /// part donc de l'étoile du pays ; de près, de la ville la plus proche.
  final List<LienCiel> liens;
}

/// Mes villes en pays, puis en régions ([endroitDe] : où tombe un point du
/// ciel ; sans lui, aucun groupe). Seuls les pays et régions d'au moins
/// deux villes font un groupe ; un pays dont toutes les villes sont dans
/// la même région n'en garde que le pays.
HierarchieCiel hierarchieDuCiel(
  CielConstellation ciel, [
  EndroitCiel? Function(double x, double y)? endroitDe,
]) {
  final villes = ciel.villes;
  final parPays = <String, Map<String, List<int>>>{};
  final sortes = <(String, String), String>{};
  final racine = <_Partie>[];
  for (var i = 0; i < villes.length; i++) {
    final v = villes[i];
    final entree = v.etoiles[v.entree];
    final e = endroitDe == null
        ? null
        : endroitDe(v.cx, v.cy) ?? endroitDe(entree.x, entree.y);
    if (e == null) {
      racine.add((groupe: false, i: i));
      continue;
    }
    parPays
        .putIfAbsent(e.pays, () => {})
        .putIfAbsent(e.region, () => [])
        .add(i);
    sortes[(e.pays, e.region)] = e.sorte;
  }

  final noms = <String>[];
  final parents = <int>[];
  final parties = <List<_Partie>>[];
  int nouveau(String nom, int parent) {
    noms.add(nom);
    parents.add(parent);
    parties.add([]);
    return noms.length - 1;
  }

  for (final MapEntry(key: pays, value: regions) in parPays.entries) {
    final toutes = [for (final r in regions.values) ...r];
    if (toutes.length < 2) {
      racine.add((groupe: false, i: toutes.single));
      continue;
    }
    final pleines = [
      for (final r in regions.values)
        if (r.length >= 2) r,
    ];
    final avecRegions =
        !(pleines.length == 1 && pleines.single.length == toutes.length);
    final g = nouveau(pays, -1);
    racine.add((groupe: true, i: g));
    for (final MapEntry(key: region, value: lesVilles) in regions.entries) {
      if (avecRegions && lesVilles.length >= 2) {
        final nom = _nomRegion(region, sortes[(pays, region)]!, [
          for (final i in lesVilles) villes[i].nom,
        ]);
        final r = nouveau(nom, g);
        parties[r].addAll([for (final i in lesVilles) (groupe: false, i: i)]);
        parties[g].add((groupe: true, i: r));
      } else {
        parties[g].addAll([for (final i in lesVilles) (groupe: false, i: i)]);
      }
    }
  }

  List<int> feuilles(_Partie p) =>
      p.groupe ? [for (final q in parties[p.i]) ...feuilles(q)] : [p.i];
  final centres = [
    for (var g = 0; g < noms.length; g++)
      _centreDesVilles(feuilles((groupe: true, i: g)), villes),
  ];
  (double, double) centre(_Partie p) =>
      p.groupe ? centres[p.i] : (villes[p.i].cx, villes[p.i].cy);

  final liens = <LienCiel>[];
  void relier(List<_Partie> lesParties, int groupe) {
    for (final (a, b) in liensDenses([for (final p in lesParties) centre(p)])) {
      final (va, vb) = _plusProches(
        feuilles(lesParties[a]),
        feuilles(lesParties[b]),
        villes,
      );
      liens.add(
        villes[vb].debut.isBefore(villes[va].debut)
            ? LienCiel(vb, va, groupe: groupe)
            : LienCiel(va, vb, groupe: groupe),
      );
    }
  }

  relier(racine, -1);
  for (var g = 0; g < noms.length; g++) {
    relier(parties[g], g);
  }

  return HierarchieCiel(
    groupes: [
      for (var g = 0; g < noms.length; g++)
        GroupeCiel(
          nom: noms[g],
          etiquette: pluriel(
            feuilles((
              groupe: true,
              i: g,
            )).fold(0, (n, i) => n + villes[i].etoiles.length),
            'table',
          ),
          parent: parents[g],
          villes: [
            for (final p in parties[g])
              if (!p.groupe) p.i,
          ],
          cx: centres[g].$1,
          cy: centres[g].$2,
          ecart: _ecart([for (final p in parties[g]) centre(p)]),
          tables: feuilles((
            groupe: true,
            i: g,
          )).fold(0, (n, i) => n + villes[i].etoiles.length),
        ),
    ],
    liens: liens,
  );
}

/// Une partie d'un groupe : une ville, ou un sous-groupe.
typedef _Partie = ({bool groupe, int i});

/// Une région qui porte le nom d'une de ses villes : « Province de Liège ».
String _nomRegion(String region, String sorte, List<String> villes) {
  final cle = normaliserPourRecherche(region);
  if (!villes.any((v) => normaliserPourRecherche(v) == cle)) return region;
  final voyelle = 'aeiouyhàâäéèêëîïôöûüœ'.contains(region[0].toLowerCase());
  return voyelle ? "$sorte d'$region" : '$sorte de $region';
}

(double, double) _centreDesVilles(
  List<int> lesVilles,
  List<VilleCiel> villes,
) => (
  lesVilles.fold(0.0, (n, i) => n + villes[i].cx) / lesVilles.length,
  lesVilles.fold(0.0, (n, i) => n + villes[i].cy) / lesVilles.length,
);

/// Les deux villes les plus proches, l'une de [a], l'autre de [b].
(int, int) _plusProches(List<int> a, List<int> b, List<VilleCiel> villes) {
  var meilleur = (a.first, b.first);
  var dmin = double.infinity;
  for (final i in a) {
    for (final j in b) {
      final d =
          math.pow(villes[i].cx - villes[j].cx, 2) +
          math.pow(villes[i].cy - villes[j].cy, 2);
      if (d < dmin) {
        dmin = d.toDouble();
        meilleur = (i, j);
      }
    }
  }
  return meilleur;
}

/// La médiane des distances de chaque point à son plus proche voisin.
double _ecart(List<(double, double)> points) {
  final distances = [
    for (var i = 0; i < points.length; i++)
      [
        for (var j = 0; j < points.length; j++)
          if (j != i)
            math.sqrt(
              math.pow(points[i].$1 - points[j].$1, 2) +
                  math.pow(points[i].$2 - points[j].$2, 2),
            ),
      ].fold(double.infinity, math.min),
  ]..sort();
  if (distances.isEmpty || distances.first.isInfinite) return 0.05;
  return math.max(0.01, distances[distances.length ~/ 2]);
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
