---

description: "Task list template for feature implementation"
---

# Tasks: Parcours de présentation à la première ouverture

**Input**: Design documents from `/specs/001-onboarding-premier-lancement/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md (tous présents)

**Tests**: Incluses — la stack technique (`plan.md`) et le workflow de vérification de la constitution
(`flutter analyze` + `flutter test` obligatoires) demandent des tests unitaires/widget pour cette fonctionnalité.

**Organization**: Tâches groupées par user story (US1/US2/US3, voir `spec.md`) pour une implémentation et
une validation indépendantes de chacune.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Peut s'exécuter en parallèle (fichiers différents, aucune dépendance non résolue)
- **[Story]**: User story concernée (US1, US2, US3)
- Chemins de fichiers exacts inclus dans chaque description

## Note d'implémentation — visuel des étapes

`contracts/etape_onboarding_widget.md` décrit une prop `asset` (chemin d'image). En l'absence
d'illustrations finales livrées par le design, l'implémentation utilise une prop `icone` (`IconData`,
icône Material) comme visuel placeholder : zéro fichier binaire à produire, zéro nouvelle dépendance,
et le remplacement par de vraies illustrations plus tard ne touchera que `tabl_ui` (cohérent avec le
Principe I). Le contrat reste sinon inchangé (titre, texte, `onPasser` en callback).

## Phase 1: Setup

**Purpose**: Préparer les dépendances nécessaires avant le travail sur les fondations

- [X] T001 Déclarer explicitement `shared_preferences` dans `packages/tabl_core/pubspec.yaml` (déjà présent transitivement via `supabase_flutter`, voir `research.md` §1), puis lancer `flutter pub get` dans `packages/tabl_core/`
- [X] T002 [P] Créer les dossiers vides nécessaires : `packages/tabl_core/lib/src/onboarding/`, `packages/tabl_core/test/onboarding/`, `packages/tabl_ui/test/components/` (si absent), `app/test/ecrans/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Interface de persistance et composant d'étape, requis par les trois user stories

**⚠️ CRITICAL**: Aucune user story ne peut commencer avant la fin de cette phase

- [X] T003 [P] Créer l'interface `EtatOnboarding` dans `packages/tabl_core/lib/src/onboarding/etat_onboarding.dart` (`Future<bool> aDejaVuOnboarding()`, `Future<void> marquerOnboardingVu()`) conformément à `contracts/etat_onboarding.md`
- [X] T004 [P] Implémenter `EtatOnboardingPreferences` dans `packages/tabl_core/lib/src/onboarding/etat_onboarding_preferences.dart` (utilise `shared_preferences`, clé `'onboarding_vu'` ; `aDejaVuOnboarding()` retourne `false` si absente ou en cas d'erreur de lecture)
- [X] T005 Exporter `EtatOnboarding` et `EtatOnboardingPreferences` depuis `packages/tabl_core/lib/tabl_core.dart` (dépend de T003, T004)
- [X] T006 [P] Test unitaire dans `packages/tabl_core/test/onboarding/etat_onboarding_preferences_test.dart` avec `SharedPreferences.setMockInitialValues({})` : valeur par défaut `false`, `marquerOnboardingVu()` puis `aDejaVuOnboarding()` retourne `true`, appels multiples idempotents
- [X] T007 [P] Créer le composant pur `EtapeOnboarding` dans `packages/tabl_ui/lib/src/components/etape_onboarding.dart` (props `titre: String`, `texte: String`, `icone: IconData`, `onPasser: VoidCallback`, `libellePasser: String` par défaut `'Passer'` ; uniquement `TablTokens` pour couleurs/espacements/typo — voir note d'implémentation ci-dessus)
- [X] T008 Exporter `EtapeOnboarding` depuis `packages/tabl_ui/lib/tabl_ui.dart` (dépend de T007)
- [X] T009 [P] Test widget dans `packages/tabl_ui/test/components/etape_onboarding_test.dart` : affichage de `titre`/`texte`, bouton "Passer" visible, `onPasser` invoqué au tap

**Checkpoint**: `EtatOnboarding` et `EtapeOnboarding` disponibles et testés — les user stories peuvent démarrer

---

## Phase 3: User Story 1 - Découvrir l'app à la première ouverture (Priority: P1) 🎯 MVP

**Goal**: À la toute première ouverture, l'app affiche les 5 étapes dans l'ordre (Bienvenue, Profil,
Feed, Réseau privé entre amis, Publication d'un souvenir) puis amène sur `EcranInscription`.

**Independent Test**: Avec un `EtatOnboarding` en mémoire dont `aDejaVuOnboarding()` retourne `false`,
lancer l'app, vérifier que `EcranOnboarding` s'affiche en premier, progresser étape par étape jusqu'à la
5e, et vérifier l'arrivée sur `EcranInscription`.

### Implementation for User Story 1

- [X] T010 [US1] Définir la liste statique des 5 étapes (ordre, titre, texte, `IconData`) en constante privée dans `app/lib/ecrans/ecran_onboarding.dart`, dans l'ordre Bienvenue → Profil → Feed → Réseau privé entre amis → Publication d'un souvenir (voir `data-model.md`)
- [X] T011 [US1] Implémenter `EcranOnboarding` dans `app/lib/ecrans/ecran_onboarding.dart` : `PageView` (ou index d'état) instanciant `EtapeOnboarding` pour chacune des 5 étapes, navigation avant entre étapes ; à l'issue de la 5e étape (ou via `onPasser`, requis par le composant — voir Phase 4), `Navigator.of(context).pushReplacement` vers `EcranInscription` et appel à `EtatOnboarding.marquerOnboardingVu()` ; reçoit `authService` et `etatOnboarding` en paramètres du constructeur (dépend de T007, T003)
- [X] T012 [US1] Modifier `TablApp` dans `app/lib/main.dart` : construire `EtatOnboardingPreferences()` à côté de `AuthServiceSupabase`, lire `aDejaVuOnboarding()` (ex. via `FutureBuilder`) pour choisir `home` entre `EcranOnboarding` (si `false`) et `EcranConnexion` (si `true`), au lieu de pointer en dur sur `EcranConnexion` (dépend de T011, T005)
- [X] T013 [US1] Test widget dans `app/test/ecrans/ecran_onboarding_test.dart` (nouveau fichier) : avec un faux `EtatOnboarding` en mémoire, vérifier l'affichage successif des 5 étapes dans l'ordre attendu et l'arrivée sur `EcranInscription` en fin de parcours (dépend de T011)
- [X] T014 [P] [US1] Test dans `app/test/main_test.dart` (nouveau fichier) : `TablApp` démarre sur `EcranOnboarding` quand `EtatOnboarding.aDejaVuOnboarding()` retourne `false` (faux `EtatOnboarding` en mémoire) (dépend de T012)

**Checkpoint**: US1 fonctionnelle et testable indépendamment — c'est le MVP.

---

## Phase 4: User Story 2 - Passer le parcours à tout moment (Priority: P2)

**Goal**: Le bouton "Passer", présent sur chaque étape depuis la Phase 2/3, amène directement à
`EcranInscription` quelle que soit l'étape courante.

**Independent Test**: Depuis l'étape 1 puis depuis l'étape 5, appuyer sur "Passer" et vérifier
l'arrivée immédiate sur `EcranInscription` dans les deux cas.

> `onPasser` est une prop obligatoire d'`EtapeOnboarding` (Phase 2) : T011 (US1) l'a déjà câblée pour
> toutes les étapes afin de compiler. Cette phase ajoute donc la validation explicite du comportement
> de saut, plutôt que du nouveau code de production.

### Implementation for User Story 2

- [X] T015 [US2] Ajouter dans `app/test/ecrans/ecran_onboarding_test.dart` : test partant de l'étape 1 (Bienvenue), tap "Passer" → arrivée sur `EcranInscription` sans passer par les étapes 2 à 5, et `EtatOnboarding.marquerOnboardingVu()` appelé ; test partant de l'étape 5, tap "Passer" → même résultat (dépend de T013)
- [X] T016 [US2] Vérification manuelle : dérouler la section "Validation manuelle — bouton 'Passer' (US2)" de `quickstart.md` sur un simulateur/émulateur — fait via `integration_test` (app réelle, pas de mocks) sur le simulateur iOS 17 (A86989FE-DA9A-4EEF-981A-055C07F16B5E) : swipe des 5 étapes confirmé à l'écran (captures), "Passer" depuis l'étape 1 → inscription immédiate (capture), "Passer"/"Commencer" depuis l'étape 5 → inscription (capture)

**Checkpoint**: US1 et US2 fonctionnelles ensemble, chacune testable indépendamment.

---

## Phase 5: User Story 3 - Ne plus revoir le parcours après la première fois (Priority: P3)

**Goal**: Une fois le parcours terminé ou passé, les ouvertures suivantes de l'app démarrent
directement sur `EcranConnexion`.

**Independent Test**: Simuler un `EtatOnboarding` en mémoire, terminer (ou passer) le parcours, vérifier
que `aDejaVuOnboarding()` retourne ensuite `true` et que relancer `TablApp` affiche `EcranConnexion`.

> La branche `true → EcranConnexion` de T012 (US1) et l'appel à `marquerOnboardingVu()` de T011/T015
> couvrent déjà le mécanisme. Cette phase valide le round-trip complet et le cas manuel réel.

### Implementation for User Story 3

- [X] T017 [P] [US3] Test dans `app/test/main_test.dart` : `TablApp` démarre sur `EcranConnexion` (pas `EcranOnboarding`) quand `EtatOnboarding.aDejaVuOnboarding()` retourne `true` (dépend de T014, même fichier — exécuter après T014) — déjà couvert par le second test de `main_test.dart` écrit avec T014
- [X] T018 [US3] Test d'intégration dans `app/test/ecrans/ecran_onboarding_test.dart` : avec un `EtatOnboarding` en mémoire, terminer le parcours (ou appuyer sur "Passer"), puis vérifier que `aDejaVuOnboarding()` retourne `true` (dépend de T015) — déjà couvert par les assertions `aDejaVuOnboarding()` des tests T013/T015 (progression normale, "Passer" étape 1, "Commencer" étape 5)
- [X] T019 [US3] Vérification manuelle : dérouler la section "Validation manuelle — non-réapparition (US3)" de `quickstart.md` (fermeture complète de l'app puis réouverture) — fait avec le vrai binaire installé en standalone (`flutter build ios --simulator` + `simctl install`, pas le runner XCUITest éphémère) sur le simulateur iOS 17 : `simctl terminate` puis `simctl launch` après un parcours marqué vu → arrivée directe sur `EcranConnexion` ("Bon retour"), confirmé par capture d'écran

**Checkpoint**: Les trois user stories fonctionnent indépendamment et ensemble.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Vérifications finales couvrant l'ensemble de la fonctionnalité

- [X] T020 Exécuter `flutter analyze` à la racine du dépôt et corriger tout avertissement — 0 issue
- [X] T021 Exécuter `flutter test` dans `packages/tabl_core/`, `packages/tabl_ui/` (y compris le garde-fou existant `mur_ui_metier_test.dart`) et `app/` — 3 + 4 + 5 tests, tous verts
- [ ] T022 Dérouler entièrement `quickstart.md` sur simulateur iOS 17 (A86989FE-DA9A-4EEF-981A-055C07F16B5E) — **fait** : parcours complet US1 (5 étapes dans l'ordre, captures à chaque étape), "Passer" US2 (étape 1 et étape 5), non-réapparition US3 (vrai binaire, `simctl terminate`/`launch`), cas limite fermeture avant la fin (installation jamais marquée vue → relance redémarre bien à l'étape 1, capture à l'appui). **Restant** : scénario hors-ligne explicite (mode avion, FR-007/SC-005) non rejoué physiquement — `EcranOnboarding`/`EtapeOnboarding` ne font aucun appel réseau (relecture de code), mais aucune capture en mode avion réel ; chronométrage SC-003 non mesuré à la main (les runs `integration_test` bouclent en 8 à 16 s tout compris, ce qui n'est pas équivalent à une lecture humaine à rythme normal)
- [X] T023 [P] Relire le code ajouté : noms en français (Principe IV), aucune valeur en dur dans `tabl_ui` (Principe II), `tabl_ui` ne dépend toujours que de `flutter` (Principe I) — `packages/tabl_ui/pubspec.yaml` inchangé, `mur_ui_metier_test.dart` toujours vert

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)** : aucune dépendance
- **Foundational (Phase 2)** : dépend de Setup — bloque toutes les user stories
- **User Story 1 (Phase 3)** : dépend de Foundational — MVP, aucune dépendance aux autres stories
- **User Story 2 (Phase 4)** : dépend de Foundational **et** de T011/T013 (US1) car elle teste le
  comportement de `EcranOnboarding` déjà construit — pas indépendante au niveau du code, mais
  indépendamment vérifiable
- **User Story 3 (Phase 5)** : dépend de Foundational, T012/T014 (US1) et T015 (US2) pour les mêmes
  raisons — round-trip de persistance déjà câblé, cette phase le valide
- **Polish (Phase 6)** : dépend de toutes les phases précédentes

### Parallel Opportunities

- T002 en parallèle du reste de Setup
- T003, T004, T007 en parallèle entre eux (fichiers différents) une fois T001/T002 terminés
- T006 et T009 en parallèle (fichiers de test différents) une fois leurs dépendances respectives prêtes
- T014 en parallèle de T013 (fichiers différents, toutes deux dépendent de US1 mais pas l'une de l'autre)
- T023 en parallèle de T020/T021/T022 (relecture n'affecte pas l'exécution des commandes)

---

## Parallel Example: Phase 2 (Foundational)

```bash
# Après T001/T002, lancer en parallèle :
Task: "Créer l'interface EtatOnboarding dans packages/tabl_core/lib/src/onboarding/etat_onboarding.dart"
Task: "Implémenter EtatOnboardingPreferences dans packages/tabl_core/lib/src/onboarding/etat_onboarding_preferences.dart"
Task: "Créer le composant EtapeOnboarding dans packages/tabl_ui/lib/src/components/etape_onboarding.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 seule)

1. Compléter Phase 1 (Setup) et Phase 2 (Foundational — bloquant)
2. Compléter Phase 3 (User Story 1)
3. **S'ARRÊTER et VALIDER** : dérouler manuellement le scénario US1 de `quickstart.md`
4. Démontrer si prêt — le parcours s'affiche et mène à l'inscription, même sans bouton "Passer" testé formellement ni garantie de non-réapparition

### Incremental Delivery

1. Setup + Foundational → fondations prêtes
2. + User Story 1 → tester indépendamment → MVP démontrable
3. + User Story 2 → valider le comportement "Passer" déjà câblé → démontrable
4. + User Story 3 → valider la non-réapparition → fonctionnalité complète
5. Chaque story ajoute de la valeur/confiance sans casser la précédente

---

## Notes

- [P] = fichiers différents, aucune dépendance non résolue
- Le label [Story] trace chaque tâche vers sa user story dans `spec.md`
- US2 et US3 sont majoritairement des phases de test/validation : le code de production nécessaire a
  été construit en Phase 3 (US1) parce que `onPasser` et le choix de l'écran initial sont des exigences
  structurelles du composant/de l'écran, pas des ajouts optionnels ultérieurs — voir les encarts de
  contexte dans chaque phase
- Vérifier que les tests échouent avant l'implémentation quand c'est pertinent (T006, T009, T013 avant
  le code qu'ils couvrent, si le workflow TDD est suivi)
- Commit après chaque tâche ou groupe logique
