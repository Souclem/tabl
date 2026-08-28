/// Un souvenir tel qu'affiché dans le Feed — déjà résolu et prêt à
/// afficher (l'URL de la photo est une URL signée, pas le chemin brut du
/// bucket) : l'écran n'a aucune requête à faire, juste à afficher.
class SouvenirFeed {
  const SouvenirFeed({
    required this.id,
    required this.photoUrl,
    required this.legende,
    required this.restaurantNom,
    required this.ville,
    required this.moment,
    required this.dateVisite,
    required this.auteurPseudo,
    required this.nombreReactions,
    required this.jaiReagi,
    required this.nombreCommentaires,
  });

  final String id;

  /// `null` si le souvenir n'a pas de photo, ou si l'URL n'a pas pu être
  /// résolue (fichier introuvable côté bucket).
  final String? photoUrl;

  final String? legende;
  final String restaurantNom;
  final String ville;

  /// `'midi'` ou `'soir'`, tel qu'enregistré en base.
  final String moment;

  final DateTime dateVisite;
  final String auteurPseudo;

  final int nombreReactions;

  /// `true` si le compte courant a réagi à ce souvenir.
  final bool jaiReagi;

  final int nombreCommentaires;

  /// Nouvelle instance avec certains champs remplacés — pour la mise à
  /// jour optimiste après une action (réagir, commenter), sans recharger
  /// tout le Feed.
  SouvenirFeed copierAvec({
    int? nombreReactions,
    bool? jaiReagi,
    int? nombreCommentaires,
  }) {
    return SouvenirFeed(
      id: id,
      photoUrl: photoUrl,
      legende: legende,
      restaurantNom: restaurantNom,
      ville: ville,
      moment: moment,
      dateVisite: dateVisite,
      auteurPseudo: auteurPseudo,
      nombreReactions: nombreReactions ?? this.nombreReactions,
      jaiReagi: jaiReagi ?? this.jaiReagi,
      nombreCommentaires: nombreCommentaires ?? this.nombreCommentaires,
    );
  }
}
