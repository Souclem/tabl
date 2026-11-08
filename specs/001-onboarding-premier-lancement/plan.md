# Implementation Plan: Parcours de présentation à la première ouverture

**Branch**: `001-onboarding-premier-lancement` | **Date**: 2026-08-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-onboarding-premier-lancement/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Ajouter un parcours de présentation en 5 étapes statiques (Bienvenue,
Profil, Feed, Réseau privé entre amis, Publication d'un souvenir), affiché
uniquement lors de la toute première ouverture de l'app, avant l'écran
d'inscription. Chaque étape est un composant `tabl_ui` pur (visuel, titre,
texte, bouton "Passer" en callback) ; un nouvel écran dans `app/` orchestre
la progression entre étapes et navigue vers `EcranInscription` à la fin ou
dès un appui sur "Passer". Un indicateur booléen local, exposé par un
nouveau service dans `tabl_core` (persisté via `shared_preferences`),
évite que le parcours ne réapparaisse aux ouvertures suivantes. Aucun appel
réseau n'est nécessaire à aucun moment (Principe VI de la constitution).

## Technical Context

**Language/Version**: Dart (SDK `^3.12.2`), Flutter stable

**Primary Dependencies**: `flutter` (SDK), `tabl_ui` (composant d'étape
pur), `tabl_core` (`EtatOnboarding`, interface + implémentation
`shared_preferences`) ; `shared_preferences` est déjà présent
transitivement via `supabase_flutter` mais doit être déclaré explicitement
dans `packages/tabl_core/pubspec.yaml` (jamais dans `app/` ni `tabl_ui` —
c'est de la donnée, Principe I)

**Storage**: Stockage clé-valeur local à l'appareil (`shared_preferences`)
— un seul booléen (`aDejaVuOnboarding`) ; aucune donnée envoyée à Supabase

**Testing**: `flutter_test` — tests widget pour chaque étape/écran
`tabl_ui`, test unitaire de `EtatOnboarding` avec `shared_preferences`
mocké (`SharedPreferences.setMockInitialValues`), test de l'écran
d'orchestration `app/`, plus le garde-fou existant
`mur_ui_metier_test.dart`

**Target Platform**: iOS + Android (application mobile Flutter)

**Project Type**: Mobile app — monorepo Flutter à 3 zones (`app/`,
`packages/tabl_ui/`, `packages/tabl_core/`)

**Performance Goals**: Transitions entre étapes fluides (pas de jank
perceptible, ~60 fps), aucun temps de chargement réseau puisque tout le
contenu est local

**Constraints**: Fonctionnement 100% hors-ligne obligatoire (FR-007,
Principe VI) ; aucune nouvelle dépendance dans `tabl_ui` (Principe I, le
mur `tabl_ui` → `flutter` uniquement doit rester intact)

**Scale/Scope**: 5 écrans de contenu statique + 1 indicateur local
persisté ; aucune nouvelle table Supabase, aucune migration SQL

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principe | Évaluation |
|---|---|
| I. Séparation UI / Métier | PASS — les 5 écrans d'étape (visuel + texte + callback "Passer"/"Suivant") vivent dans `tabl_ui`, sans logique de navigation ni lecture d'état ; la persistance de l'état d'onboarding vit dans `tabl_core` derrière une interface (`EtatOnboarding`, même modèle que `AuthService`/`AuthServiceSupabase`) ; l'orchestration (progression entre étapes, appel à `EtatOnboarding`, navigation vers l'inscription) vit dans `app/`, seul endroit qui connaît les deux. |
| II. Composants UI purs | PASS — chaque étape reçoit titre/texte/asset déjà prêts à l'affichage via son constructeur et expose ses actions ("Passer", progression) en callbacks ; aucune règle métier, aucune lecture d'état, aucune valeur en dur dans `tabl_ui` — tout vient de `TablTokens`. |
| III. Logique métier hors de Postgres | PASS (non applicable) — aucune interaction Postgres/Supabase dans cette fonctionnalité ; le seul état persisté est local à l'appareil. |
| IV. Français pour le code | PASS — noms prévus en français (`EcranOnboarding`, `EtapeOnboarding`, `EtatOnboarding`, `EtatOnboardingPreferences`, `aDejaVuOnboarding`, `marquerOnboardingVu`). |
| V. Secrets jamais commités | PASS (non applicable) — aucun secret impliqué. |
| VI. Comportement réseau explicite | PASS — la spec déclare explicitement le fonctionnement hors-ligne (FR-007, SC-005) avant l'implémentation. |

Aucune violation : la section Complexity Tracking reste vide.

## Project Structure

### Documentation (this feature)

```text
specs/001-onboarding-premier-lancement/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
app/lib/
├── main.dart                        # MODIFIÉ : TablApp choisit l'écran initial
│                                     #   (EcranOnboarding ou EcranConnexion) selon
│                                     #   EtatOnboarding, au lieu de EcranConnexion en dur
└── ecrans/
    ├── ecran_onboarding.dart        # NOUVEAU : orchestre les 5 étapes tabl_ui,
    │                                 #   gère la progression, appelle EtatOnboarding,
    │                                 #   navigue vers EcranInscription
    ├── ecran_connexion.dart         # inchangé
    └── ecran_inscription.dart       # inchangé

app/test/ecrans/
└── ecran_onboarding_test.dart       # NOUVEAU : test de l'orchestration (progression,
                                      #   Passer, navigation, appel à EtatOnboarding)

packages/tabl_ui/lib/src/components/
└── etape_onboarding.dart            # NOUVEAU : composant pur (titre, texte, asset
                                      #   en paramètres ; onPasser/onSuivant en callbacks)
packages/tabl_ui/lib/tabl_ui.dart    # MODIFIÉ : export du nouveau composant

packages/tabl_ui/test/components/
└── etape_onboarding_test.dart       # NOUVEAU : tests widget du composant

packages/tabl_core/lib/src/onboarding/
├── etat_onboarding.dart             # NOUVEAU : interface (aDejaVuOnboarding(),
                                      #   marquerOnboardingVu())
└── etat_onboarding_preferences.dart # NOUVEAU : implémentation shared_preferences
packages/tabl_core/lib/tabl_core.dart # MODIFIÉ : export du nouveau service
packages/tabl_core/pubspec.yaml       # MODIFIÉ : déclaration explicite de
                                      #   shared_preferences (déjà présent
                                      #   transitivement via supabase_flutter)

packages/tabl_core/test/onboarding/
└── etat_onboarding_preferences_test.dart  # NOUVEAU : shared_preferences mocké
```

**Structure Decision**: Monorepo Flutter existant à 3 zones — pas de
nouvelle zone ni de nouveau package. Le contenu visuel des 5 étapes vit
dans `tabl_ui` (un seul composant réutilisable `EtapeOnboarding`,
paramétré par étape, plutôt que 5 classes quasi identiques — voir
`research.md`), l'état persisté vit dans `tabl_core` sous
`src/onboarding/` en suivant exactement le modèle `src/auth/`
(`AuthService` / `AuthServiceSupabase`), et l'orchestration (nouvel écran
+ décision de l'écran initial dans `main.dart`) vit dans `app/`.

## Constitution Check (post-Phase 1)

*Re-check after Phase 1 design (`data-model.md`, `contracts/`, `quickstart.md`).*

Aucun changement par rapport à l'évaluation initiale : le design détaillé
en `data-model.md` et `contracts/` respecte le découpage `tabl_ui` /
`tabl_core` / `app` prévu — toujours PASS sur les 6 principes, aucune
nouvelle dépendance introduite dans `tabl_ui`, aucune interaction
Postgres, tout le stockage reste local. Aucune entrée requise en
Complexity Tracking.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Aucune violation identifiée — section sans objet pour cette fonctionnalité.
