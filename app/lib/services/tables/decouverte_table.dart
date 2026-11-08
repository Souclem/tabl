/// Une adresse "À découvrir" (megaprompt Bloc 3, règles 36-40) : connue
/// par au moins un autre membre actif de la Table, jamais visitée par
/// l'utilisateur courant. Vue strictement personnelle — deux membres
/// peuvent voir des listes différentes (règle 36).
class DecouverteTable {
  const DecouverteTable({
    required this.restaurantId,
    required this.restaurantNom,
    required this.ville,
    required this.pseudosConnaisseurs,
    required this.dejaGardeParMoi,
    this.emotionsRepresentatives = const [],
    this.quartier,
  });

  final String restaurantId;
  final String restaurantNom;
  final String ville;
  final String? quartier;

  /// Toujours des membres dont l'expérience m'est déjà légitimement
  /// visible (règle 40 — la privacy est vérifiée côté service, pas
  /// masquée en façade) : jamais de nom déduit d'une visite que je ne
  /// devrais pas connaître.
  final List<String> pseudosConnaisseurs;

  final List<String> emotionsRepresentatives;
  final bool dejaGardeParMoi;
}
