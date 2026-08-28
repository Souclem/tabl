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
  });

  final String id;
  final String pseudo;
  final StatutAbonnement statut;
}

/// Une demande de suivi reçue, en attente de réponse.
class DemandeAbonnement {
  const DemandeAbonnement({required this.suiveurId, required this.pseudo});

  final String suiveurId;
  final String pseudo;
}
