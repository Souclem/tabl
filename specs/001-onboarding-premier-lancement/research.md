# Phase 0 — Research: Parcours de présentation à la première ouverture

Aucun `NEEDS CLARIFICATION` ne subsistait dans le Technical Context ; les
décisions ci-dessous documentent les choix techniques nécessaires pour
passer de la spec au design (Phase 1), en cohérence avec le mur
`tabl_ui` / `tabl_core` (Principe I) et les indications de stack fournies.

## 1. Persistance de l'indicateur "onboarding déjà vu"

**Decision**: `shared_preferences`, déclaré explicitement dans
`packages/tabl_core/pubspec.yaml`, derrière une interface `EtatOnboarding`
(`aDejaVuOnboarding()`, `marquerOnboardingVu()`) implémentée par
`EtatOnboardingPreferences` — même modèle que `AuthService` /
`AuthServiceSupabase` dans `packages/tabl_core/lib/src/auth/`.

**Rationale**: Un seul booléen à retenir, par appareil, avant même qu'un
compte existe : `shared_preferences` est le stockage clé-valeur local
idiomatique de Flutter pour ce cas, et le paquet est déjà présent
transitivement via `supabase_flutter` — l'ajouter explicitement ne
gonfle pas l'arbre de dépendances. Passer par une interface (plutôt
qu'un appel direct à `SharedPreferences` depuis `app/`) garde l'accès aux
données dans `tabl_core` (Principe I) et rend le service simulable dans
les tests de l'écran d'orchestration.

**Alternatives considered**:
- Accès direct à `SharedPreferences` depuis `app/ecran_onboarding.dart` —
  rejeté : violerait le Principe I (« Accès aux données » doit vivre dans
  `tabl_core/lib/src/repositories/`-like zones, pas dans `app/`), et rendrait
  le test de l'écran dépendant du vrai plugin plutôt qu'un mock.
- `Hive` / `Isar` — rejeté : disproportionné pour un seul booléen, ajoute
  une dépendance et un besoin d'initialisation qu'aucune autre partie de
  l'app ne requiert aujourd'hui (YAGNI).
- Indicateur stocké côté Supabase (lié au compte) — rejeté : l'onboarding
  se déroule avant toute inscription, donc avant qu'un compte/une session
  n'existe ; ce serait aussi une violation implicite du Principe VI
  (fonctionnalité déclarée hors-ligne) puisque ça introduirait une
  dépendance réseau.

## 2. Structure des 5 étapes dans `tabl_ui`

**Decision**: Un seul composant pur réutilisable `EtapeOnboarding`
(titre, texte, chemin d'asset visuel, callback `onPasser`, callback de
progression), instancié 5 fois par l'écran d'orchestration avec une
liste de données statiques (une par étape : Bienvenue, Profil, Feed,
Réseau privé entre amis, Publication d'un souvenir).

**Rationale**: Les 5 étapes ne diffèrent que par leur contenu (texte,
asset), jamais par leur comportement ou leur mise en page — créer 5
classes de composants quasi identiques dupliquerait le layout sans
bénéfice, à l'encontre du principe « pas d'abstraction/duplication
prématurée » du projet. Un composant paramétré respecte aussi le
Principe II (« Composants purs ») : les données arrivent déjà prêtes par
le constructeur, aucune décision n'est prise dans le composant.

**Alternatives considered**:
- 5 widgets distincts (`EtapeBienvenue`, `EtapeProfil`, …) — rejeté :
  duplique le même layout 5 fois pour uniquement changer du texte/un
  asset, complique la maintenance si le design de l'étape évolue.
- Contenu des étapes chargé dynamiquement (JSON distant, CMS) — rejeté :
  violerait le fonctionnement hors-ligne (Principe VI, FR-007) ; le
  contenu est fixe et connu à la conception.

## 3. Navigation entre les étapes et vers l'inscription

**Decision**: `PageView` (ou état d'index simple) géré par
`EcranOnboarding` dans `app/lib/ecrans/`, avec `Navigator.of(context)`
pour remplacer l'écran par `EcranInscription` en fin de parcours ou dès
un appui sur "Passer" — même style de navigation impérative que
`_allerVersInscription()` déjà utilisé dans `ecran_connexion.dart`.

**Rationale**: L'app n'utilise aujourd'hui aucun package de routing
déclaratif (pas de `go_router`/`auto_route` dans les pubspecs) ; en
introduire un pour un seul écran supplémentaire serait disproportionné.
Rester sur `Navigator` impératif garde la fonctionnalité cohérente avec
le reste du code existant.

**Alternatives considered**:
- `go_router` — rejeté : aucune autre partie de l'app ne l'utilise,
  coût d'introduction disproportionné pour cette fonctionnalité.
- Navigator 2.0 / `Router` custom — rejeté : complexité inutile pour un
  flux linéaire à 5 étapes suivi d'une redirection.

## 4. Décision de l'écran initial dans `main.dart`

**Decision**: `TablApp` lit `EtatOnboarding.aDejaVuOnboarding()` avant
`runApp` (ou via un `FutureBuilder`/état initial asynchrone) pour choisir
`EcranOnboarding` (première ouverture) ou `EcranConnexion` (ouvertures
suivantes) comme `home`, au lieu de pointer en dur vers `EcranConnexion`
comme aujourd'hui.

**Rationale**: C'est la seule façon de satisfaire FR-001/FR-008 (le
parcours ne s'affiche qu'à la toute première ouverture) sans dupliquer
la vérification dans chaque écran. `main.dart` est déjà l'endroit où
`app/` assemble les dépendances (voir `AuthServiceSupabase` construit
dans `TablApp.build`), donc c'est l'extension naturelle du câblage
existant.

**Alternatives considered**: Vérifier l'état dans `EcranConnexion` lui-même
et rediriger vers l'onboarding si besoin — rejeté : inverserait la
logique (l'app démarrerait toujours sur la connexion puis rediriger),
plus complexe à tester et moins direct que de décider une fois dans
`main.dart`.

## 5. Assets visuels des étapes

**Decision**: Illustrations statiques embarquées dans le dépôt (assets
Flutter locaux), référencées par chemin depuis les données passées à
`EtapeOnboarding`.

**Rationale**: Seule option compatible avec le fonctionnement hors-ligne
obligatoire (FR-007, SC-005, Principe VI) — aucun appel réseau, aucun
temps de chargement dépendant de la connectivité.

**Alternatives considered**: Images hébergées à distance — rejeté,
casserait le fonctionnement hors-ligne. Animations Lottie — rejeté pour
cette V1 (dépendance supplémentaire non nécessaire pour 5 écrans
statiques courts), peut être reconsidéré plus tard sans changer le
contrat du composant (`EtapeOnboarding` reste paramétré par un chemin
d'asset).
