# Phase 1 — Data Model: Parcours de présentation à la première ouverture

Aucune table Supabase, aucune migration SQL : les deux entités de cette
fonctionnalité sont locales à l'appareil (l'une en dur dans le code,
l'autre persistée via `shared_preferences`).

## Étape de présentation (`EtapeOnboardingDonnees`)

Configuration statique, définie en code dans `app/` (ou `tabl_core` si
elle doit être réutilisée ailleurs) — pas de source de données externe,
pas de champ modifiable par l'utilisateur.

| Champ | Type | Description | Règle de validation |
|---|---|---|---|
| `ordre` | `int` | Position dans le parcours (1 à 5) | Unique, croissant, exactement 1 à 5 sur l'ensemble des étapes |
| `titre` | `String` | Titre court de l'étape (ex. "Bienvenue") | Non vide |
| `texte` | `String` | Phrase(s) explicatives de l'étape | Non vide |
| `icone` | `IconData` | Visuel de l'étape — icône Material, placeholder en attendant les illustrations finales du design | Non nul |

> **Note — placeholder visuel** : `icone` remplace un chemin d'asset
> image pour cette V1 (aucune illustration finale livrée à ce stade) —
> voir `contracts/etape_onboarding_widget.md`.

**Relations**: aucune — liste statique de 5 valeurs, ordonnée, connue à
la compilation. Correspond aux 5 étapes de la spec : Bienvenue, Profil,
Feed, Réseau privé entre amis, Publication d'un souvenir.

**Transitions d'état**: aucune — donnée en lecture seule.

## État d'onboarding (`EtatOnboarding`)

Un indicateur unique, persisté localement à l'appareil via
`shared_preferences`, exposé par l'interface `tabl_core`
`EtatOnboarding` :

| Champ (clé de stockage) | Type | Description |
|---|---|---|
| `aDejaVuOnboarding` | `bool` | `true` dès que l'utilisateur a atteint l'écran d'inscription depuis l'onboarding (parcours complété OU passé) ; `false`/absent tant que ce n'est pas le cas |

**Relations**: aucune — indicateur global à l'appareil, non lié à un
compte utilisateur (l'onboarding précède toute inscription).

**Transitions d'état**:

```
(absent / false)  --[FR-006 : dernière étape atteinte, complétée ou via "Passer"]-->  true
true  --[désinstallation de l'app]-->  (absent / false)   # réinitialisation implicite, hors du contrôle applicatif
```

Il n'existe pas de transition retour `true → false` déclenchée par
l'application elle-même (voir Assumptions du spec : pas de bouton pour
« revoir » l'onboarding dans cette fonctionnalité).

**Interface** (`packages/tabl_core/lib/src/onboarding/etat_onboarding.dart`) :

- `Future<bool> aDejaVuOnboarding()` — lit l'indicateur ; retourne `false`
  si aucune valeur n'a encore été écrite (première ouverture réelle).
- `Future<void> marquerOnboardingVu()` — écrit `true` ; idempotent (un
  second appel n'a pas d'effet observable différent).

**Implémentation** (`etat_onboarding_preferences.dart`) : `EtatOnboardingPreferences`
utilise `SharedPreferences` avec une clé dédiée (ex.
`'onboarding_vu'`), sans dépendance à `tabl_ui` ni à `app/`.
