# Contrat : `EtatOnboarding` (tabl_core)

Interface d'accès aux données pour l'indicateur "onboarding déjà vu".
Vit dans `packages/tabl_core/lib/src/onboarding/etat_onboarding.dart`,
sur le même modèle que `AuthService` (`packages/tabl_core/lib/src/auth/`).
Consommée uniquement par `app/` (jamais par `tabl_ui`, Principe I).

## Interface

```dart
abstract interface class EtatOnboarding {
  /// true si l'utilisateur a déjà atteint la fin du parcours de
  /// présentation (complété ou passé) sur cet appareil.
  Future<bool> aDejaVuOnboarding();

  /// Marque le parcours comme vu. Idempotent.
  Future<void> marquerOnboardingVu();
}
```

## Comportement attendu

| Méthode | Entrée | Sortie / effet | Cas limites |
|---|---|---|---|
| `aDejaVuOnboarding()` | — | `Future<bool>` | Aucune valeur encore écrite (toute première installation) → `false`. Ne lève jamais d'exception métier : une erreur de lecture du stockage local est traitée comme `false` (l'utilisateur revoit l'onboarding plutôt que d'être bloqué). |
| `marquerOnboardingVu()` | — | `Future<void>`, écrit la valeur persistée | Appels multiples sans effet observable différent (idempotent) ; aucun appel réseau. |

## Implémentation de référence

`EtatOnboardingPreferences` (`etat_onboarding_preferences.dart`) :
implémente `EtatOnboarding` avec le plugin `shared_preferences`, clé de
stockage dédiée (ex. `'onboarding_vu'`). Ne dépend d'aucune autre partie
de `tabl_core` (pas de lien avec `AuthService`).

## Consommateurs

- `app/lib/main.dart` : appelle `aDejaVuOnboarding()` pour décider de
  l'écran initial (`EcranOnboarding` vs `EcranConnexion`).
- `app/lib/ecrans/ecran_onboarding.dart` : appelle
  `marquerOnboardingVu()` au moment où l'utilisateur atteint la fin du
  parcours (dernière étape complétée ou "Passer" pressé).

## Testabilité

Les tests de `app/` (écran d'orchestration, choix de l'écran initial)
DOIVENT utiliser une implémentation en mémoire de `EtatOnboarding` (faux
objet), jamais `EtatOnboardingPreferences` directement — même approche
que les tests existants qui simulent `AuthService`. Les tests propres à
`EtatOnboardingPreferences`, dans `packages/tabl_core/test/onboarding/`,
utilisent `SharedPreferences.setMockInitialValues({})`.
