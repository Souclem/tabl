import 'profil_public.dart';

/// Contrat du graphe social de Tabl.
///
/// Suivi asymétrique type Instagram, pas amitié mutuelle type Facebook :
/// suivre quelqu'un crée une demande (l'app est privée), l'autre accepte
/// ou refuse. `A` peut suivre `B` sans que `B` suive `A`.
abstract interface class AbonnementService {
  /// Cherche des profils par pseudo (jamais soi-même), avec la relation
  /// déjà résolue pour chacun.
  Future<List<ProfilPublic>> rechercher(String requete);

  /// Envoie une demande de suivi.
  Future<void> suivre(String suiviId);

  /// Annule une demande envoyée, ou se désabonne si elle était déjà
  /// acceptée — même opération côté base : supprimer la ligne où on est
  /// le suiveur.
  Future<void> arreterDeSuivre(String suiviId);

  /// Les demandes reçues, en attente de réponse.
  Future<List<DemandeAbonnement>> demandesRecues();

  Future<void> accepterDemande(String suiveurId);

  /// Refuse une demande reçue, ou retire un abonné déjà accepté — même
  /// opération côté base : supprimer la ligne où on est le suivi.
  Future<void> refuserDemande(String suiveurId);

  /// Nombre de demandes en attente de réponse — pour le badge sur
  /// l'entrée vers l'écran Cercle.
  Future<int> nombreDemandesEnAttente();
}
