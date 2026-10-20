/// Une personne taguée comme présente lors d'un moment, déjà résolue
/// pour l'affichage (sa tête dans une bulle, son profil au tap).
class PersonnePresente {
  const PersonnePresente({
    required this.id,
    required this.pseudo,
    this.photoUrl,
    this.estMoi = false,
  });

  final String id;
  final String pseudo;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? photoUrl;

  /// `true` si c'est le compte courant (tagué par quelqu'un d'autre) :
  /// l'app dit alors « toi » plutôt que son pseudo.
  final bool estMoi;
}
