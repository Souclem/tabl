/// Où en est la relation de suivi entre le compte courant et un autre
/// profil.
enum StatutAbonnement {
  /// Aucune relation : ni suivi, ni demande dans un sens ou l'autre.
  aucun,

  /// On a envoyé une demande, en attente de réponse.
  demandeEnvoyee,

  /// L'autre nous a envoyé une demande, en attente de notre réponse.
  demandeRecue,

  /// Demande acceptée : on suit ce profil.
  abonne,
}

/// Un profil trouvé par recherche, avec la relation déjà résolue — sert à
/// savoir quel bouton afficher (« Suivre », « Demande envoyée »...) sans
/// requête supplémentaire.
class ProfilPublic {
  const ProfilPublic({
    required this.id,
    required this.pseudo,
    required this.statut,
    this.photoUrl,
    this.meSuit = false,
  });

  final String id;
  final String pseudo;

  /// Où j'en suis avec cette personne, dans mon sens.
  final StatutAbonnement statut;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? photoUrl;

  /// Elle me suit déjà (relation acceptée) : « Suivre en retour »
  /// plutôt que « Suivre ».
  final bool meSuit;

  ProfilPublic copierAvec({StatutAbonnement? statut}) => ProfilPublic(
    id: id,
    pseudo: pseudo,
    statut: statut ?? this.statut,
    photoUrl: photoUrl,
    meSuit: meSuit,
  );
}

/// Le profil d'une autre personne, tel qu'on le visite.
class ProfilVisite {
  const ProfilVisite({
    required this.id,
    required this.pseudo,
    required this.estPrive,
    required this.statut,
    this.photoUrl,
    this.meSuit = false,
  });

  final String id;
  final String pseudo;
  final String? photoUrl;
  final bool estPrive;

  /// Où j'en suis avec cette personne, dans mon sens : je ne la suis pas
  /// ([StatutAbonnement.aucun]), j'ai demandé, ou je la suis.
  final StatutAbonnement statut;

  /// Elle me suit déjà (relation acceptée) : « Suivre en retour ».
  final bool meSuit;

  /// Comme Instagram : un profil privé ne montre ses publications qu'à
  /// ses abonnés acceptés ; aux autres, seulement l'en-tête. Le filtrage
  /// publication par publication ("Qui peut voir ?") reste fait par la
  /// base (RLS).
  bool get publicationsVisibles =>
      !estPrive || statut == StatutAbonnement.abonne;

  ProfilVisite copierAvec({StatutAbonnement? statut}) => ProfilVisite(
    id: id,
    pseudo: pseudo,
    photoUrl: photoUrl,
    estPrive: estPrive,
    statut: statut ?? this.statut,
    meSuit: meSuit,
  );
}

/// Une demande de suivi reçue, en attente de réponse.
class DemandeAbonnement {
  const DemandeAbonnement({
    required this.suiveurId,
    required this.pseudo,
    this.photoUrl,
  });

  final String suiveurId;
  final String pseudo;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? photoUrl;
}

/// Les chiffres d'un profil : ses moments publiés, ses abonnés (qui le
/// suivent) et ses abonnements (qu'il suit).
typedef CompteursProfil = ({int moments, int abonnes, int abonnements});
