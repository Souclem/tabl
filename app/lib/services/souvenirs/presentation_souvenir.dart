import 'souvenir_feed.dart';

const List<String> _moisAnnee = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Date d'un souvenir telle qu'affichée sur une publication : "12 mars"
/// cette année, "3 novembre 2025" sinon (sans l'année, une liste du plus
/// récent au plus ancien semblerait en désordre).
String dateLisibleSouvenir(DateTime date, {DateTime? maintenant}) {
  final jour = '${date.day} ${_moisAnnee[date.month - 1]}';
  final annee = (maintenant ?? DateTime.now()).year;
  return date.year == annee ? jour : '$jour ${date.year}';
}

/// Reprend l'algorithme `proofText` du prototype : jamais un chiffre brut
/// mis en avant, toujours une phrase ("a aimé"/"ont aimé"/"avez aimé"/
/// "Personne n'a encore aimé").
String libelleReactionsSouvenir(SouvenirFeed s) {
  if (s.nombreReactions == 0) return "Personne n'a encore aimé";
  // J'ai aimé : la phrase commence par moi ("Vous et 3 autres avez
  // aimé"), jamais "Emma, Lucas et 2 autres avez aimé".
  if (s.jaiReagi) {
    final autres = s.nombreReactions - 1;
    return autres == 0
        ? 'Vous avez aimé'
        : 'Vous et $autres autre${autres > 1 ? 's' : ''} avez aimé';
  }
  final verbe = s.nombreReactions > 1 ? 'ont aimé' : 'a aimé';
  final noms = s.premieresReactions;
  if (noms.isEmpty) return verbe;
  final reste = s.nombreReactions - noms.length;
  final tete = noms.join(', ');
  return reste > 0
      ? '$tete et $reste autre${reste > 1 ? 's' : ''} $verbe'
      : '$tete $verbe';
}
