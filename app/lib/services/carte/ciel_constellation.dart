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
    required this.maison,
    required this.compteurs,
  });

  static const vide = CielConstellation(
    villes: [],
    liensDansVilles: [],
    liensEntreVilles: [],
    maison: -1,
    compteurs: '',
  );

  /// Dans l'ordre où je les ai découvertes.
  final List<VilleCiel> villes;

  /// Pour chaque ville, ses liens (indices dans [VilleCiel.etoiles]).
  final List<List<LienCiel>> liensDansVilles;

  /// Entre les villes (indices dans [villes]).
  final List<LienCiel> liensEntreVilles;

  /// L'indice de la maison : la ville où je mange le plus.
  final int maison;

  /// « 298 tables · 971 repas · 55 villes ».
  final String compteurs;

  bool get estVide => villes.isEmpty;
}

/// Une sortie : moins loin que ça de la maison, on n'est pas en voyage.
const distanceSortieKm = 250.0;

/// Deux villes lointaines découvertes à moins de ce temps l'une de l'autre
/// font partie du même voyage.
const memeVoyage = Duration(days: 45);

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

/// Ma Constellation : mes restaurants, regroupés par ville, et ses liens.
///
/// · Dans une ville, l'arbre pousse avec le temps : chaque nouvelle adresse
///   se rattache à la plus proche de celles déjà connues.
/// · Entre les villes, on habite à la maison (là où l'on mange le plus) et
///   on part en voyage, un à la fois : un voyage part de la maison ; les
///   villes lointaines découvertes à moins de [memeVoyage] l'une de
///   l'autre en font partie et se suivent dans l'ordre ; puis on rentre, et
///   le voyage suivant repart de la maison. Les villes à moins de
///   [distanceSortieKm] sont des sorties, reliées directement à la maison.
CielConstellation cielConstellation(Iterable<LieuCarte> miens) {
  final parVille = <String, List<LieuCarte>>{};
  final noms = <String, String>{};
  for (final l in miens) {
    final nom = l.ville.trim();
    if (nom.isEmpty) continue;
    final cle = normaliserPourRecherche(nom);
    parVille.putIfAbsent(cle, () => []).add(l);
    noms.putIfAbsent(cle, () => nom);
  }
  if (parVille.isEmpty) return CielConstellation.vide;

  final villes = [
    for (final MapEntry(key: cle, value: lieux) in parVille.entries)
      _ville(noms[cle]!, lieux),
  ]..sort((a, b) => a.debut.compareTo(b.debut));

  var maison = 0;
  for (var i = 1; i < villes.length; i++) {
    if (villes[i].repas > villes[maison].repas) maison = i;
  }

  final tables = villes.fold(0, (n, v) => n + v.etoiles.length);
  final repas = villes.fold(0, (n, v) => n + v.repas);
  return CielConstellation(
    villes: villes,
    liensDansVilles: [for (final v in villes) arbreChronologique(v.etoiles)],
    liensEntreVilles: liensVoyages(villes, maison),
    maison: maison,
    compteurs:
        '${pluriel(tables, 'table')} · $repas repas · '
        '${pluriel(villes.length, 'ville')}',
  );
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

/// L'arbre qui pousse avec le temps : chaque étoile (dans l'ordre de
/// [EtoileCiel.premiere]) se rattache à la plus proche des précédentes.
List<LienCiel> arbreChronologique(List<EtoileCiel> etoiles) {
  final ordre = [for (var i = 0; i < etoiles.length; i++) i]
    ..sort((i, j) => etoiles[i].premiere.compareTo(etoiles[j].premiere));
  final liens = <LienCiel>[];
  for (var k = 1; k < ordre.length; k++) {
    final j = ordre[k];
    var parent = ordre[0];
    var dmin = double.infinity;
    for (var m = 0; m < k; m++) {
      final e = etoiles[ordre[m]];
      final d =
          math.pow(e.x - etoiles[j].x, 2) + math.pow(e.y - etoiles[j].y, 2);
      if (d < dmin) {
        dmin = d.toDouble();
        parent = ordre[m];
      }
    }
    liens.add(LienCiel(parent, j));
  }
  return liens;
}

/// Les voyages depuis la maison (voir [cielConstellation]). [villes] dans
/// l'ordre de découverte ; chaque lien va de la plus ancienne des deux.
List<LienCiel> liensVoyages(List<VilleCiel> villes, int maison) {
  if (maison < 0) return const [];
  final chez = villes[maison];
  final liens = <LienCiel>[];
  int? derniere;
  void relier(int a, int b) => liens.add(
    villes[a].debut.isAfter(villes[b].debut) ? LienCiel(b, a) : LienCiel(a, b),
  );
  for (var i = 0; i < villes.length; i++) {
    if (i == maison) continue;
    final v = villes[i];
    if (distanceCielKm(chez.cx, chez.cy, v.cx, v.cy) < distanceSortieKm) {
      relier(maison, i);
      continue;
    }
    final d = derniere;
    final memeVoyageQue =
        d != null && v.debut.difference(villes[d].debut) <= memeVoyage;
    relier(memeVoyageQue ? d : maison, i);
    derniere = i;
  }
  return liens;
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
