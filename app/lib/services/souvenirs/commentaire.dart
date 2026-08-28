/// Un commentaire sur un souvenir.
class Commentaire {
  const Commentaire({
    required this.id,
    required this.texte,
    required this.creeLe,
    required this.auteurPseudo,
    required this.estLeMien,
  });

  final String id;
  final String texte;
  final DateTime creeLe;
  final String auteurPseudo;

  /// `true` si le compte courant en est l'auteur — permet à l'écran de
  /// n'afficher l'action "supprimer" que sur ses propres commentaires.
  final bool estLeMien;
}
