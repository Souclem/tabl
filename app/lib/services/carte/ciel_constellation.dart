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
    required this.repas,
    required this.entree,
    required this.etiquette,
  });

  final String nom;

  /// Mon premier repas dans cette ville.
  final DateTime debut;
  final List<EtoileCiel> etoiles;

  /// Le centre de ses restaurants.
  final double cx;
  final double cy;
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
  return VilleCiel(
    nom: nom,
    debut: etoiles.first.premiere,
    etoiles: etoiles,
    cx: cx,
    cy: cy,
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

/// Un groupe de mes restaurants, une étoile qui en contient d'autres : un
/// pays, une région, une ville, ou quelques étoiles trop proches pour se
/// voir séparément (« Bruxelles +2 »). De loin une seule étoile, qui se
/// dédouble quand on s'en approche.
class GroupeCiel {
  const GroupeCiel({
    required this.nom,
    required this.etiquette,
    required this.parent,
    required this.ville,
    required this.cx,
    required this.cy,
    required this.ecart,
    required this.tables,
  });

  final String nom;

  /// « 137 tables ».
  final String etiquette;

  /// Le groupe qui le contient (indice dans [HierarchieCiel.groupes],
  /// toujours avant lui), -1 tout en haut.
  final int parent;

  /// La ville qu'il est (indice dans [CielConstellation.villes]), -1 sinon.
  final int ville;

  /// Le centre de ses restaurants.
  final double cx;
  final double cy;

  /// La distance entre les deux parties qu'il réunit : il se dédouble quand
  /// elle laisse, à l'écran, la place à leurs deux étoiles.
  final double ecart;
  final int tables;
}

/// Un restaurant dans la hiérarchie : l'étoile [etoile] de la ville [ville]
/// (dans [CielConstellation.villes]), dans le groupe [groupe].
typedef EtoileHierarchie = ({int ville, int etoile, int groupe});

/// Mes restaurants en pays, régions, villes, et leurs liens.
class HierarchieCiel {
  const HierarchieCiel({
    required this.groupes,
    required this.etoiles,
    required this.liens,
  });

  /// Les parents avant leurs enfants.
  final List<GroupeCiel> groupes;

  /// Du restaurant connu le premier au plus récent.
  final List<EtoileHierarchie> etoiles;

  /// Le maillage « Dense » entre les parties de chaque pays, région, ville
  /// (et entre ce qui n'en a pas), chaque lien posé entre les deux
  /// restaurants les plus proches de ses deux parties (indices dans
  /// [etoiles]). [LienCiel.groupe] : le plus petit groupe qui contient ses
  /// deux étoiles ; le lien se voit quand il s'ouvre.
  final List<LienCiel> liens;
}

/// Une ville d'un seul restaurant ne le laisse voir que de tout près.
const _ecartSeul = 0.003;

/// Deux restaurants à la même adresse se séparent quand même, au plus près.
const _ecartMin = 0.0002;

/// Mes restaurants en pays, puis en régions, puis en villes ([endroitDe] :
/// où tombe un point du ciel ; sans lui, rien que les villes). Seuls les
/// pays et régions d'au moins deux villes font un groupe ; un pays dont
/// toutes les villes sont dans la même région n'en garde que le pays.
///
/// Dans chacun, et tout en haut, les parties se réunissent deux à deux,
/// des plus proches aux plus lointaines : deux étoiles trop proches pour
/// l'écran n'en font qu'une, qui se dédouble quand on s'approche.
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
      racine.add((sorte: _sorteVille, i: i));
      continue;
    }
    parPays
        .putIfAbsent(e.pays, () => {})
        .putIfAbsent(e.region, () => [])
        .add(i);
    sortes[(e.pays, e.region)] = e.sorte;
  }

  // Les pays et les régions.
  final noms = <String>[];
  final parties = <List<_Partie>>[];
  int nouveau(String nom) {
    noms.add(nom);
    parties.add([]);
    return noms.length - 1;
  }

  for (final MapEntry(key: pays, value: regions) in parPays.entries) {
    final toutes = [for (final r in regions.values) ...r];
    if (toutes.length < 2) {
      racine.add((sorte: _sorteVille, i: toutes.single));
      continue;
    }
    final pleines = [
      for (final r in regions.values)
        if (r.length >= 2) r,
    ];
    final avecRegions =
        !(pleines.length == 1 && pleines.single.length == toutes.length);
    final g = nouveau(pays);
    racine.add((sorte: _sorteRegion, i: g));
    for (final MapEntry(key: region, value: lesVilles) in regions.entries) {
      if (avecRegions && lesVilles.length >= 2) {
        final nom = _nomRegion(region, sortes[(pays, region)]!, [
          for (final i in lesVilles) villes[i].nom,
        ]);
        final r = nouveau(nom);
        parties[r].addAll([
          for (final i in lesVilles) (sorte: _sorteVille, i: i),
        ]);
        parties[g].add((sorte: _sorteRegion, i: r));
      } else {
        parties[g].addAll([
          for (final i in lesVilles) (sorte: _sorteVille, i: i),
        ]);
      }
    }
  }

  // Les restaurants, du plus ancien au plus récent.
  final etoiles = [
    for (var i = 0; i < villes.length; i++)
      for (var j = 0; j < villes[i].etoiles.length; j++) (i, j),
  ];
  etoiles.sort((a, b) {
    final parDate = villes[a.$1].etoiles[a.$2].premiere.compareTo(
      villes[b.$1].etoiles[b.$2].premiere,
    );
    if (parDate != 0) return parDate;
    return a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2;
  });
  final indice = {for (var k = 0; k < etoiles.length; k++) etoiles[k]: k};
  EtoileCiel etoile(int k) => villes[etoiles[k].$1].etoiles[etoiles[k].$2];

  List<_Partie> partiesDe(_Partie p) => switch (p.sorte) {
    _sorteRegion => parties[p.i],
    _sorteVille => [
      for (var j = 0; j < villes[p.i].etoiles.length; j++)
        (sorte: _sorteRestaurant, i: indice[(p.i, j)]!),
    ],
    _ => const [],
  };
  final memoire = <_Partie, List<int>>{};
  List<int> restos(_Partie p) => p.sorte == _sorteRestaurant
      ? [p.i]
      : memoire[p] ??= [for (final q in partiesDe(p)) ...restos(q)];
  (double, double) centre(_Partie p) {
    final r = restos(p);
    return (
      r.fold(0.0, (n, k) => n + etoile(k).x) / r.length,
      r.fold(0.0, (n, k) => n + etoile(k).y) / r.length,
    );
  }

  String nomDe(_Partie p) => switch (p.sorte) {
    _sorteRegion => noms[p.i],
    _sorteVille => villes[p.i].nom,
    _ => etoile(p.i).nom,
  };
  // Une réunion sans nom prend celui de sa plus grande partie.
  int importance(_Partie p) =>
      p.sorte == _sorteRestaurant ? etoile(p.i).repas : restos(p).length;

  final groupes = <GroupeCiel>[];
  final parentEtoile = List.filled(etoiles.length, -1);
  int ajouter(
    String nom,
    String etiquette,
    int parent,
    int ville,
    (double, double) c,
    double ecart,
    int tables,
  ) {
    groupes.add(
      GroupeCiel(
        nom: nom,
        etiquette: etiquette,
        parent: parent,
        ville: ville,
        cx: c.$1,
        cy: c.$2,
        ecart: math.max(_ecartMin, ecart),
        tables: tables,
      ),
    );
    return groupes.length - 1;
  }

  late void Function(List<_Partie>, int, _Partie?) deplier;
  void placer(_Partie p, int parent) {
    if (p.sorte == _sorteRestaurant) {
      parentEtoile[p.i] = parent;
      return;
    }
    final lesParties = partiesDe(p);
    if (lesParties.length > 1) {
      deplier(lesParties, parent, p);
      return;
    }
    // Une ville d'un seul restaurant.
    final g = ajouter(
      nomDe(p),
      villes[p.i].etiquette,
      parent,
      p.i,
      centre(p),
      _ecartSeul,
      1,
    );
    placer(lesParties.single, g);
  }

  deplier = (lesParties, parent, nomme) {
    if (lesParties.isEmpty) return;
    if (lesParties.length == 1) {
      placer(lesParties.single, parent);
      return;
    }
    void sortir(_Amas a, int parent, _Partie? nom) {
      if (a.feuille >= 0) {
        placer(lesParties[a.feuille], parent);
        return;
      }
      final tables = a.membres.fold(
        0,
        (n, m) => n + restos(lesParties[m]).length,
      );
      var principale = a.membres.first;
      for (final m in a.membres) {
        if (importance(lesParties[m]) > importance(lesParties[principale])) {
          principale = m;
        }
      }
      final g = ajouter(
        nom == null
            ? '${nomDe(lesParties[principale])} +${a.membres.length - 1}'
            : nomDe(nom),
        nom?.sorte == _sorteVille
            ? villes[nom!.i].etiquette
            : pluriel(tables, 'table'),
        parent,
        nom?.sorte == _sorteVille ? nom!.i : -1,
        (a.x, a.y),
        a.d,
        tables,
      );
      sortir(a.gauche!, g, null);
      sortir(a.droite!, g, null);
    }

    sortir(
      _reunir(
        [for (final p in lesParties) centre(p)],
        [for (final p in lesParties) restos(p).length],
      ),
      parent,
      nomme,
    );
  };
  deplier(racine, -1, null);

  // Les liens : le maillage de chaque niveau.
  final liens = <(int, int)>[];
  void relier(List<_Partie> lesParties) {
    for (final (a, b) in liensDenses([for (final p in lesParties) centre(p)])) {
      liens.add(
        _plusProches(restos(lesParties[a]), restos(lesParties[b]), etoile),
      );
    }
  }

  relier(racine);
  for (final p in parties) {
    relier(p);
  }
  for (var i = 0; i < villes.length; i++) {
    relier(partiesDe((sorte: _sorteVille, i: i)));
  }

  // Chaque lien se voit quand s'ouvre le plus petit groupe qui contient
  // ses deux étoiles.
  final profondeur = [for (final g in groupes) g.parent < 0 ? 0 : 0];
  for (var g = 0; g < groupes.length; g++) {
    final p = groupes[g].parent;
    profondeur[g] = p < 0 ? 0 : profondeur[p] + 1;
  }
  int commun(int a, int b) {
    while (a != b && a >= 0 && b >= 0) {
      if (profondeur[a] >= profondeur[b]) {
        a = groupes[a].parent;
      } else {
        b = groupes[b].parent;
      }
    }
    return a == b ? a : -1;
  }

  return HierarchieCiel(
    groupes: groupes,
    etoiles: [
      for (var k = 0; k < etoiles.length; k++)
        (ville: etoiles[k].$1, etoile: etoiles[k].$2, groupe: parentEtoile[k]),
    ],
    liens: [
      for (final (a, b) in liens)
        LienCiel(
          etoile(b).premiere.isBefore(etoile(a).premiere) ? b : a,
          etoile(b).premiere.isBefore(etoile(a).premiere) ? a : b,
          groupe: commun(parentEtoile[a], parentEtoile[b]),
        ),
    ],
  );
}

/// Une partie d'un groupe : un pays ou une région ([parties]), une ville,
/// un restaurant (indice dans les étoiles de la hiérarchie).
typedef _Partie = ({int sorte, int i});
const _sorteRegion = 0;
const _sorteVille = 1;
const _sorteRestaurant = 2;

/// Une région qui porte le nom d'une de ses villes : « Province de Liège ».
String _nomRegion(String region, String sorte, List<String> villes) {
  final cle = normaliserPourRecherche(region);
  if (!villes.any((v) => normaliserPourRecherche(v) == cle)) return region;
  final voyelle = 'aeiouyhàâäéèêëîïôöûüœ'.contains(region[0].toLowerCase());
  return voyelle ? "$sorte d'$region" : '$sorte de $region';
}

/// Les deux restaurants les plus proches, l'un de [a], l'autre de [b].
(int, int) _plusProches(
  List<int> a,
  List<int> b,
  EtoileCiel Function(int) etoile,
) {
  var meilleur = (a.first, b.first);
  var dmin = double.infinity;
  for (final i in a) {
    final ei = etoile(i);
    for (final j in b) {
      final ej = etoile(j);
      final d = (ei.x - ej.x) * (ei.x - ej.x) + (ei.y - ej.y) * (ei.y - ej.y);
      if (d < dmin) {
        dmin = d;
        meilleur = (i, j);
      }
    }
  }
  return meilleur;
}

/// Des points réunis deux à deux, les plus proches d'abord : un arbre dont
/// chaque nœud garde la distance entre ses deux branches.
class _Amas {
  _Amas.feuille(this.feuille, this.x, this.y, this.poids)
    : gauche = null,
      droite = null,
      d = 0,
      membres = [feuille];

  _Amas.reunion(_Amas a, _Amas b)
    : feuille = -1,
      gauche = a,
      droite = b,
      poids = a.poids + b.poids,
      x = (a.x * a.poids + b.x * b.poids) / (a.poids + b.poids),
      y = (a.y * a.poids + b.y * b.poids) / (a.poids + b.poids),
      d = math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)),
      membres = [...a.membres, ...b.membres];

  final int feuille;
  final _Amas? gauche;
  final _Amas? droite;
  final int poids;
  final double x;
  final double y;
  final double d;
  final List<int> membres;
}

_Amas _reunir(List<(double, double)> points, List<int> poids) {
  final amas = [
    for (var i = 0; i < points.length; i++)
      _Amas.feuille(i, points[i].$1, points[i].$2, math.max(1, poids[i])),
  ];
  while (amas.length > 1) {
    var (a, b) = (0, 1);
    var dmin = double.infinity;
    for (var i = 0; i < amas.length; i++) {
      for (var j = i + 1; j < amas.length; j++) {
        final dx = amas[i].x - amas[j].x, dy = amas[i].y - amas[j].y;
        final d = dx * dx + dy * dy;
        if (d < dmin) {
          dmin = d;
          (a, b) = (i, j);
        }
      }
    }
    amas[a] = _Amas.reunion(amas[a], amas[b]);
    amas.removeAt(b);
  }
  return amas.single;
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
