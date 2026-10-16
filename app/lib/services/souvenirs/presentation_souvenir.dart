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

/// Date d'un souvenir telle qu'affichée sur une publication ("12 mars").
String dateLisibleSouvenir(DateTime date) {
  return '${date.day} ${_moisAnnee[date.month - 1]}';
}

/// Reprend l'algorithme `proofText` du prototype : jamais un chiffre brut
/// mis en avant, toujours une phrase ("a aimé"/"ont aimé"/"avez aimé"/
/// "Personne n'a encore aimé").
String libelleReactionsSouvenir(SouvenirFeed s) {
  if (s.nombreReactions == 0) return "Personne n'a encore aimé";
  final verbe = s.jaiReagi
      ? 'avez aimé'
      : (s.nombreReactions > 1 ? 'ont aimé' : 'a aimé');
  final noms = s.premieresReactions;
  if (noms.isEmpty) return verbe;
  final reste = s.nombreReactions - noms.length;
  final tete = noms.join(', ');
  return reste > 0
      ? '$tete et $reste autre${reste > 1 ? 's' : ''} $verbe'
      : '$tete $verbe';
}
