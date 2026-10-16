import 'statut_membre_table.dart';

/// Un membre d'une Table, tel qu'affiché dans la liste des membres.
///
/// Réutilise le graphe social existant (voir `AbonnementService`) — pas de
/// système d'amis parallèle (règle 55) : [profilId]/[pseudo] viennent de
/// `profils`, la relation à la Table vient de `membres_table`.
class MembreTable {
  const MembreTable({
    required this.profilId,
    required this.pseudo,
    required this.statut,
    required this.estAdmin,
  });

  final String profilId;
  final String pseudo;
  final StatutMembreTable statut;
  final bool estAdmin;
}
