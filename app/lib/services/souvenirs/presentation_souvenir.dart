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

/// "janvier" … "décembre" ([mois] de 1 à 12).
String nomDuMois(int mois) => _moisAnnee[mois - 1];

/// "8 moments", "1 adresse"… : [nombre] suivi de [mot], au pluriel au-delà
/// de 1.
String pluriel(int nombre, String mot) =>
    '$nombre $mot${nombre > 1 ? 's' : ''}';

/// "Déjeuner" ou "Dîner" pour la valeur stockée en base (`'midi'`,
/// `'soir'`), `null` pour toute autre.
String? libelleMomentRepas(String moment) => switch (moment) {
  'midi' => 'Déjeuner',
  'soir' => 'Dîner',
  _ => null,
};

/// "Arthur", "Arthur et Emma", "Arthur, Emma et Louise" ; au-delà de
/// trois : "Arthur, Emma et 2 autres".
String listeDeNoms(List<String> noms) {
  if (noms.isEmpty) return '';
  if (noms.length == 1) return noms.first;
  if (noms.length > 3) {
    return '${noms[0]}, ${noms[1]} et ${pluriel(noms.length - 2, 'autre')}';
  }
  return '${noms.sublist(0, noms.length - 1).join(', ')} et ${noms.last}';
}

/// Date d'un souvenir telle qu'affichée sur une publication : "12 mars"
/// cette année, "3 novembre 2025" sinon (sans l'année, une liste du plus
/// récent au plus ancien semblerait en désordre).
String dateLisibleSouvenir(DateTime date, {DateTime? maintenant}) {
  final jour = '${date.day} ${_moisAnnee[date.month - 1]}';
  final annee = (maintenant ?? DateTime.now()).year;
  return date.year == annee ? jour : '$jour ${date.year}';
}

/// La légende d'un moment telle qu'affichée partout dans l'app : entre
/// guillemets « », c'est la voix de son auteur. Les guillemets que
/// l'auteur aurait tapés lui-même ne sont pas doublés. `null` si vide.
String? legendeAffichee(String? legende) {
  final texte = legende?.trim().replaceAll(RegExp(r'^["«“\s]+|["»”\s]+$'), '');
  if (texte == null || texte.isEmpty) return null;
  // Espaces insécables : les guillemets ne se retrouvent jamais seuls en
  // bout de ligne.
  return '«\u00A0$texte\u00A0»';
}

/// "Aucun moment", "1 moment", "12 moments" — en-tête d'un profil.
String libelleNombreMoments(int nombre) =>
    nombre == 0 ? 'Aucun moment' : '$nombre moment${nombre > 1 ? 's' : ''}';

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
