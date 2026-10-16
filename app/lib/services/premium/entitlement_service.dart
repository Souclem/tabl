/// Ce à quoi un compte Premium donne accès, au-delà de l'offre gratuite.
///
/// Aucun système d'achat (StoreKit / Play Billing) n'existe encore dans
/// l'app : c'est un point d'extension propre, pas une implémentation
/// complète. `EntitlementServiceGratuit` répond toujours par la
/// négative — rebrancher un vrai système d'entitlements ailleurs ne
/// touchera que l'endroit où l'implémentation est choisie, comme pour
/// `AuthService`.
abstract interface class EntitlementService {
  /// Accès au réseau étendu (amis d'amis) sur la carte Explorer —
  /// toujours anonymisé même pour un compte Premium (voir
  /// `CarteService`).
  Future<bool> aReseauEtendu();
}

/// Personne n'est Premium tant qu'aucun système d'achat n'existe.
class EntitlementServiceGratuit implements EntitlementService {
  const EntitlementServiceGratuit();

  @override
  Future<bool> aReseauEtendu() async => false;
}
