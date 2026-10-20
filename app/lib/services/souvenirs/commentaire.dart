/// Un commentaire sur un souvenir.
class Commentaire {
  const Commentaire({
    required this.id,
    required this.texte,
    required this.creeLe,
    required this.auteurPseudo,
    required this.estLeMien,
    this.auteurPhotoUrl,
  });

  final String id;
  final String texte;
  final DateTime creeLe;
  final String auteurPseudo;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? auteurPhotoUrl;

  /// `true` si le compte courant en est l'auteur — permet à l'écran de
  /// n'afficher l'action "supprimer" que sur ses propres commentaires.
  final bool estLeMien;
}
