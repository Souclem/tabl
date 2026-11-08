/// Quelqu'un qui a aimé un moment, prêt à afficher : son nom dans
/// « Emma et 3 autres ont aimé », et sa tête à côté.
class PersonneQuiAime {
  const PersonneQuiAime({
    required this.pseudo,
    this.photoUrl,
    this.suivie = false,
  });

  final String pseudo;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? photoUrl;

  /// Je la suis : elle passe devant les autres.
  final bool suivie;
}

/// Combien de personnes sont nommées sous un moment.
const nombreMaxPersonnesNommees = 3;

/// Les personnes nommées sous un moment, parmi [recentes] (toutes celles
/// qui l'ont aimé, la plus récente d'abord) : celles que je suis passent
/// devant — on les connaît —, puis les autres ; jamais moi, que la phrase
/// dit déjà (« Vous et 3 autres »).
List<PersonneQuiAime> personnesNommees(
  List<({String id, String pseudo, String? photoUrl})> recentes, {
  required Set<String> suivis,
  required String monId,
}) {
  final autres = [
    for (final r in recentes)
      if (r.id != monId) r,
  ];
  PersonneQuiAime personne(({String id, String pseudo, String? photoUrl}) r) =>
      PersonneQuiAime(
        pseudo: r.pseudo,
        photoUrl: r.photoUrl,
        suivie: suivis.contains(r.id),
      );
  return [
    for (final r in autres)
      if (suivis.contains(r.id)) personne(r),
    for (final r in autres)
      if (!suivis.contains(r.id)) personne(r),
  ].take(nombreMaxPersonnesNommees).toList();
}
