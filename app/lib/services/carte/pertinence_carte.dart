import 'dart:math';

import '../souvenirs/emotion.dart';
import 'lieu_carte.dart';

/// Au plus autant de bulles photo à la fois : elles sont grandes.
const nombreMaxBulles = 40;

/// Au plus autant de marqueurs en tout (bulles et simples points).
const nombreMaxMarqueurs = 400;

/// Place réservée autour d'un marqueur, en fraction de la largeur visible
/// (le rayon) — calée sur sa taille réelle à l'écran (~400 pt de large) :
/// bulle photo (~50 pt), marqueur d'un lieu de mon réseau (14 pt), petit
/// point d'un restaurant où personne n'est allé (8 pt).
const _rayonBulle = 1 / 14;
const _rayonReseau = 1 / 60;
const _rayonAnnuaire = 1 / 110;

/// À partir de ce zoom (quelques rues), plus aucun point n'est écarté :
/// tous les restaurants de la zone visible s'affichent.
const zoomToutAfficher = 15.5;

/// La pertinence d'un lieu pour moi : d'abord le nombre d'amis différents
/// qui y sont allés, puis le nombre de visites, puis les coups de cœur ;
/// mes envies passent devant. Un lieu de l'annuaire (personne n'y est
/// allé) vaut 0.
double pertinence(LieuCarte lieu) {
  final amis = {
    for (final v in lieu.visites)
      if (!v.estMoi) v.auteurId,
  }.length;
  final coupsDeCoeur = lieu.visites
      .where((v) => v.emotion == Emotion.coupDeCoeur)
      .length;
  return (lieu.estEnvie ? 100000.0 : 0) +
      amis * 100.0 +
      lieu.visites.length * 10.0 +
      coupsDeCoeur;
}

/// Les lieux à afficher dans [zone], parmi [candidats] (déjà filtrés) :
/// les plus pertinents d'abord, chacun avec la place qu'il occupe à
/// l'écran — plus on zoome, plus il y a de place, plus on en voit.
/// Toujours la même règle, quel que soit le zoom.
List<LieuCarte> lieuxAAfficher(
  Iterable<LieuCarte> candidats,
  ZoneCarte zone, {
  double zoom = 0,
  int limiteBulles = nombreMaxBulles,
  int limite = nombreMaxMarqueurs,
}) {
  final dansZone = [
    for (final l in candidats)
      if (l.latitude >= zone.sud &&
          l.latitude <= zone.nord &&
          l.longitude >= zone.ouest &&
          l.longitude <= zone.est)
        l,
  ]..sort((a, b) {
      final ecart = pertinence(b).compareTo(pertinence(a));
      // À pertinence égale, un ordre stable : la carte ne "clignote" pas
      // d'un déplacement à l'autre.
      return ecart != 0 ? ecart : a.cle.compareTo(b.cle);
    });

  // Distances comparées en degrés, la longitude ramenée à l'échelle de
  // la latitude au centre de la zone.
  final echelleLongitude = cos((zone.sud + zone.nord) / 2 * pi / 180);
  final largeur = (zone.est - zone.ouest) * echelleLongitude;
  final toutAfficher = zoom >= zoomToutAfficher;
  bool estBulle(LieuCarte l) => l.amiEnAvant?.photoUrl != null;
  double rayon(LieuCarte l) =>
      largeur *
      (estBulle(l)
          ? _rayonBulle
          : l.duReseau
          ? _rayonReseau
          : _rayonAnnuaire);
  bool chevauche(LieuCarte a, LieuCarte b) {
    // De près, seules les bulles photo s'écartent entre elles : tous les
    // simples points restent, quitte à passer sous une bulle.
    if (toutAfficher && !(estBulle(a) && estBulle(b))) return false;
    final dLat = a.latitude - b.latitude;
    final dLng = (a.longitude - b.longitude) * echelleLongitude;
    final distance = rayon(a) + rayon(b);
    return dLat * dLat + dLng * dLng < distance * distance;
  }

  final retenus = <LieuCarte>[];
  var bulles = 0;
  for (final lieu in dansZone) {
    if (retenus.length >= limite) break;
    final bulle = estBulle(lieu);
    if (bulle && bulles >= limiteBulles) continue;
    if (retenus.any((r) => chevauche(r, lieu))) continue;
    retenus.add(lieu);
    if (bulle) bulles++;
  }
  return retenus;
}
