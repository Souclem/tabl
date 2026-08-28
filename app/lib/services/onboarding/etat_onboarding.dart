/// Contrat de persistance pour le parcours de présentation.
///
/// L'application dépend de cette interface, jamais d'une implémentation
/// concrète — même principe que [AuthService]. L'indicateur est local à
/// l'appareil, pas lié à un compte : le parcours se déroule avant toute
/// inscription.
abstract interface class EtatOnboarding {
  /// `true` si l'utilisateur a déjà atteint la fin du parcours de
  /// présentation (complété ou passé) sur cet appareil.
  ///
  /// Retourne `false` tant qu'aucune valeur n'a été écrite, y compris en
  /// cas d'erreur de lecture du stockage local : l'utilisateur revoit
  /// alors le parcours plutôt que d'être bloqué.
  Future<bool> aDejaVuOnboarding();

  /// Marque le parcours comme vu. Idempotent.
  Future<void> marquerOnboardingVu();
}
