/// Un utilisateur connecté.
class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.email,
    required this.pseudo,
  });

  final String id;
  final String email;
  final String pseudo;
}
