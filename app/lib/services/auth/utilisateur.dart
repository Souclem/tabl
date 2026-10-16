/// Un utilisateur connecté.
class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.email,
    required this.pseudo,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String pseudo;

  /// Adresse de la photo de profil, `null` s'il n'y en a pas.
  final String? photoUrl;
}
