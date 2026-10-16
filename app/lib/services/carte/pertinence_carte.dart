import 'dart:math';

import '../souvenirs/emotion.dart';
import 'lieu_carte.dart';

/// Nombre maximal de marqueurs affichés à la fois : au-delà, la carte
/// devient illisible sur un téléphone.
const nombreMaxMarqueurs = 60;

/// Écart minimal entre deux marqueurs, en fraction de la largeur visible :
/// en dessous, ils se chevaucheraient — seul le plus pertinent reste.
/// Calibré sur la taille d'une bulle photo (~50 pt sur un écran de
/// ~400 pt de large).
const _ecartRelatif = 1 / 7;

/// La pertinence d'un lieu pour moi : d'abord le nombre d'amis différents
/// qui y sont allés, puis le nombre de visites, puis les coups de cœur.
/// Un lieu de l'annuaire (personne n'y est allé) vaut 0.
double pertinence(LieuCarte lieu) {
  final amis = {
    for (final v in lieu.visites)
      if (!v.estMoi) v.auteurId,
  }.length;
  final coupsDeCoeur = lieu.visites
      .where((v) => v.emotion == Emotion.coupDeCoeur)
      .length;
  return amis * 100.0 + lieu.visites.length * 10.0 + coupsDeCoeur;
}

/// Les lieux à afficher dans [zone], parmi [candidats] (déjà filtrés) :
/// toutes les envies, puis les plus pertinents, sans chevauchement et
/// sans dépasser [limite]. Toujours la même règle, quel que soit le zoom.
List<LieuCarte> lieuxAAfficher(
  Iterable<LieuCarte> candidats,
  ZoneCarte zone, {
  int limite = nombreMaxMarqueurs,
}) {
  final dansZone = [
    for (final l in candidats)
      if (l.latitude >= zone.sud &&
          l.latitude <= zone.nord &&
          l.longitude >= zone.ouest &&
          l.longitude <= zone.est)
        l,
  ];
  final envies = [for (final l in dansZone) if (l.estEnvie) l];
  final autres = [for (final l in dansZone) if (!l.estEnvie) l]
    ..sort((a, b) {
      final ecart = pertinence(b).compareTo(pertinence(a));
      // À pertinence égale, un ordre stable : la carte ne "clignote" pas
      // d'un déplacement à l'autre.
      return ecart != 0 ? ecart : a.cle.compareTo(b.cle);
    });

  // Distances comparées en degrés, la longitude ramenée à l'échelle de
  // la latitude au centre de la zone.
  final echelleLongitude = cos((zone.sud + zone.nord) / 2 * pi / 180);
  final ecartMin = (zone.est - zone.ouest) * echelleLongitude * _ecartRelatif;
  bool tropProche(LieuCarte a, LieuCarte b) {
    final dLat = a.latitude - b.latitude;
    final dLng = (a.longitude - b.longitude) * echelleLongitude;
    return dLat * dLat + dLng * dLng < ecartMin * ecartMin;
  }

  final retenus = [...envies];
  for (final lieu in autres) {
    if (retenus.length >= limite + envies.length) break;
    if (retenus.any((r) => tropProche(r, lieu))) continue;
    retenus.add(lieu);
  }
  return retenus;
}
