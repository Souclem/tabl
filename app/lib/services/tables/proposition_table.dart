/// Une proposition dans "On y va ?" (megaprompt Bloc 3, règles 25-32).
///
/// [etatTexte] est déjà en langage humain (règle 32 : "Proposé", "À vous
/// de voter", "Passé"...) — le lifecycle backend (active/declined/...)
/// reste un détail d'implémentation du service. La disponibilité réelle
/// (dates, mini-chat) est un point de raccord Bloc 4, pas construite ici.
class PropositionTable {
  const PropositionTable({
    required this.id,
    required this.restaurantId,
    required this.restaurantNom,
    required this.ville,
    required this.proposePar,
    required this.parMoi,
    required this.etatTexte,
    required this.active,
    required this.nombreGo,
    this.monInteret,
  });

  final String id;
  final String restaurantId;
  final String restaurantNom;
  final String ville;
  final String proposePar;
  final bool parMoi;

  final String etatTexte;

  /// `false` pour un état terminal (declined/cancelled/expired) — sert à
  /// la détection de doublon (règle 30) et à ne plus proposer GO/Je passe.
  final bool active;

  final int nombreGo;

  /// `true` = GO, `false` = Je passe, `null` = pas encore répondu.
  final bool? monInteret;
}
