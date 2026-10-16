import 'profil_public.dart';

/// Contrat du graphe social de Tabl.
///
/// Suivi asymétrique type Instagram, pas amitié mutuelle type Facebook :
/// `A` peut suivre `B` sans que `B` suive `A`. Vers un profil privé (le
/// réglage par défaut), suivre crée une demande que l'autre accepte ou
/// refuse ; vers un profil public, l'abonnement est immédiat.
abstract interface class AbonnementService {
  /// Cherche des profils par pseudo (jamais soi-même), avec la relation
  /// déjà résolue pour chacun.
  Future<List<ProfilPublic>> rechercher(String requete);

  /// Le profil d'une autre personne, avec où j'en suis avec elle.
  Future<ProfilVisite> profil(String id);

  /// Suit [suiviId] : abonnement immédiat si son profil est public
  /// ([StatutAbonnement.abonne]), demande en attente sinon
  /// ([StatutAbonnement.demandeEnvoyee]).
  Future<StatutAbonnement> suivre(String suiviId);

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
  /// l'entrée vers l'écran Abonnés.
  Future<int> nombreDemandesEnAttente();

  /// Mes abonnés et mes abonnements (relations acceptées, dans un sens
  /// ou l'autre), sans doublon. Sert à proposer qui taguer comme présent
  /// et qui choisir dans "Qui peut voir ?".
  Future<List<ProfilPublic>> mesRelations();

  /// Mes abonnés (ceux qui me suivent) et mes abonnements (ceux que je
  /// suis), relations acceptées seulement. Le statut de chaque profil
  /// dit où j'en suis avec lui ("Suivre en retour" possible pour un
  /// abonné que je ne suis pas).
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements();

  /// Identifiants de mes abonnés acceptés (ceux qui me suivent) — c'est
  /// "Tout le monde" quand mon profil est privé.
  Future<Set<String>> mesAbonnesIds();

  /// `true` si mon profil est privé (réglage par défaut).
  Future<bool> monProfilEstPrive();

  /// Rend mon profil privé ou public. Passer en public accepte toutes
  /// les demandes en attente, comme Instagram : elles n'ont plus de
  /// raison d'attendre.
  Future<void> definirProfilPrive(bool prive);
}
