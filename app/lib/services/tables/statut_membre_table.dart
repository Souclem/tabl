/// Statut d'un membre au sein d'une Table (megaprompt Bloc 3, règle 49).
///
/// Seul [actif] compte pour le nombre de membres, les votes, la
/// découverte et l'organisation — [enAttente] n'est pas un membre actif.
enum StatutMembreTable {
  enAttente('en_attente'),
  actif('active'),
  parti('parti'),
  retire('retire');

  const StatutMembreTable(this.valeur);

  /// Valeur stockée telle quelle en base (colonne `membres_table.statut`).
  final String valeur;

  static StatutMembreTable depuisValeur(String valeur) {
    return StatutMembreTable.values.firstWhere((s) => s.valeur == valeur);
  }
}
