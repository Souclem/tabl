import 'brouillon_local.dart';
import 'presentation_finalisation.dart';
import 'presentation_souvenir.dart';

/// Au plus trois moments en cours de création sur le téléphone : au-delà,
/// « Nouveau moment » attend qu'on en publie ou qu'on en supprime un.
const nombreMaxBrouillons = 3;

/// Les brouillons que « + » propose de reprendre, le plus récemment modifié
/// d'abord : ceux qui ont au moins une photo, sauf ceux que l'auteur a
/// demandé d'envoyer dès que possible ([enAttente] : ils partent seuls).
List<Brouillon> brouillonsAReprendre(
  List<Brouillon> brouillons, {
  Set<String> enAttente = const {},
}) => [
  for (final b in brouillons)
    if (b.photos.isNotEmpty && !enAttente.contains(b.id)) b,
]..sort((a, b) => b.modifieLe.compareTo(a.modifieLe));

/// Ceux qui dépassent la limite parmi [aReprendre] (rangés par
/// [brouillonsAReprendre]) : les plus anciens, au-delà des
/// [nombreMaxBrouillons] plus récents. Le téléphone les efface (brouillons
/// d'avant la limite).
List<Brouillon> brouillonsEnTrop(List<Brouillon> aReprendre) =>
    aReprendre.length <= nombreMaxBrouillons
    ? const []
    : aReprendre.sublist(nombreMaxBrouillons);

/// « Nouveau moment » est-il possible à côté de ces [brouillons] ?
bool peutCommencerUnMoment(List<Brouillon> brouillons) =>
    brouillons.length < nombreMaxBrouillons;

/// Sous « Nouveau moment », quand la limite est atteinte.
const libelleLimiteBrouillons =
    'Trois brouillons au maximum : publiez-en un ou supprimez-en un pour '
    'commencer un nouveau moment.';

/// Le lieu choisi, ou « Repas en cours » tant qu'il ne l'est pas.
String titreBrouillon(Brouillon brouillon) =>
    brouillon.lieu?.nom ?? 'Repas en cours';

/// « Aujourd'hui · déjeuner · 12 h 30 · 3 photos ».
String detailBrouillon(Brouillon brouillon, {DateTime? maintenant}) =>
    '${dateLisibleBrouillon(brouillon.priseLe, maintenant: maintenant)} · '
    '${pluriel(brouillon.photos.length, 'photo')}';

/// La confirmation avant d'effacer un brouillon : « Ses 3 photos seront
/// effacées de ce téléphone. »
String detailSuppressionBrouillon(Brouillon brouillon) {
  final n = brouillon.photos.length;
  return n > 1
      ? 'Ses $n photos seront effacées de ce téléphone.'
      : 'Sa photo sera effacée de ce téléphone.';
}
