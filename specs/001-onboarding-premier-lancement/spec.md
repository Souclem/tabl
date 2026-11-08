# Feature Specification: Parcours de présentation à la première ouverture

**Feature Branch**: `001-onboarding-premier-lancement`

**Created**: 2026-08-16

**Status**: Draft

**Input**: User description: "Lors de sa toute première ouverture de l'app, l'utilisateur découvre un court parcours de présentation avant d'arriver sur l'écran d'inscription. Ce parcours est composé de 5 étapes courtes (Bienvenue, Profil, Feed, Réseau privé entre amis, Publication d'un souvenir), chacune avec un visuel et quelques phrases expliquant le concept. Chaque étape affiche en bas un bouton discret \"Passer\" permettant de sauter une ou plusieurs étapes à tout moment, pour que l'utilisateur ne soit jamais bloqué à lire ce qui ne l'intéresse pas. Cette présentation ne nécessite aucune connexion internet."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Découvrir l'app à la première ouverture (Priority: P1)

En tant que nouvel utilisateur, lors de ma toute première ouverture de
l'application, je découvre un court parcours de présentation en 5 étapes
(Bienvenue, Profil, Feed, Réseau privé entre amis, Publication d'un
souvenir) avant d'arriver sur l'écran d'inscription, afin de comprendre le
concept de l'app avant de créer un compte.

**Why this priority**: C'est le cœur de la fonctionnalité — sans cette
présentation initiale, les nouveaux utilisateurs arrivent directement sur
l'inscription sans aucun contexte sur ce qu'est Tabl.

**Independent Test**: Installer l'app pour la première fois sur un appareil
et vérifier que les 5 étapes s'affichent dans l'ordre, chacune avec son
visuel et son texte, avant l'écran d'inscription.

**Acceptance Scenarios**:

1. **Given** un utilisateur qui ouvre l'app pour la première fois, **When**
   l'app démarre, **Then** l'étape "Bienvenue" s'affiche avant tout écran
   d'inscription.
2. **Given** l'utilisateur est sur l'étape "Bienvenue", **When** il
   progresse dans le parcours, **Then** il voit successivement les étapes
   Profil, Feed, Réseau privé entre amis, puis Publication d'un souvenir,
   dans cet ordre.
3. **Given** l'utilisateur a terminé la 5ᵉ étape (Publication d'un
   souvenir), **When** il progresse une dernière fois, **Then** il arrive
   sur l'écran d'inscription.

---

### User Story 2 - Passer le parcours à tout moment (Priority: P2)

En tant qu'utilisateur pressé ou déjà familier du concept, je veux pouvoir
sauter une ou plusieurs étapes du parcours à tout moment via un bouton
"Passer", afin d'arriver directement à l'inscription sans être bloqué à
lire du contenu qui ne m'intéresse pas.

**Why this priority**: Essentiel pour ne pas frustrer les utilisateurs qui
ne souhaitent pas lire l'intro ; sans cette échappatoire, le parcours
deviendrait un frein à l'inscription plutôt qu'une aide. Dépend de
l'existence du parcours (US1) mais reste critique pour l'expérience dès la
première version.

**Independent Test**: Depuis n'importe quelle étape (1 à 5), appuyer sur
"Passer" et vérifier que l'utilisateur arrive immédiatement sur l'écran
d'inscription, quel que soit le nombre d'étapes restantes.

**Acceptance Scenarios**:

1. **Given** l'utilisateur est sur l'étape "Bienvenue" (1/5), **When** il
   appuie sur "Passer", **Then** il arrive directement sur l'écran
   d'inscription, sans voir les étapes 2 à 5.
2. **Given** l'utilisateur est sur l'étape "Publication d'un souvenir"
   (5/5), **When** il appuie sur "Passer", **Then** il arrive directement
   sur l'écran d'inscription.
3. **Given** l'utilisateur se trouve sur n'importe quelle étape, **When**
   il regarde l'écran, **Then** le bouton "Passer" est visible et
   accessible en bas de l'écran.

---

### User Story 3 - Ne plus revoir le parcours après la première fois (Priority: P3)

En tant qu'utilisateur qui a déjà ouvert l'app une première fois (que
j'aie terminé ou passé le parcours), je ne veux plus revoir cette
présentation lors de mes ouvertures suivantes, afin de retrouver
directement l'app sans étape superflue.

**Why this priority**: Important pour l'expérience à long terme, mais
n'empêche pas la fonctionnalité principale de fonctionner dès la première
livraison ; peut être livré juste après US1/US2.

**Independent Test**: Terminer ou passer le parcours une première fois,
fermer complètement l'app, la rouvrir, et vérifier que le parcours ne
s'affiche plus.

**Acceptance Scenarios**:

1. **Given** l'utilisateur a terminé les 5 étapes lors de sa première
   ouverture, **When** il rouvre l'app plus tard, **Then** le parcours de
   présentation ne s'affiche plus.
2. **Given** l'utilisateur a appuyé sur "Passer" lors de sa première
   ouverture, **When** il rouvre l'app plus tard, **Then** le parcours de
   présentation ne s'affiche plus.

---

### Edge Cases

- Que se passe-t-il si l'utilisateur appuie sur "Passer" dès la première
  étape (Bienvenue) ? Il arrive directement sur l'écran d'inscription sans
  avoir vu les 4 autres étapes.
- Que se passe-t-il si l'utilisateur ferme l'app en plein milieu du
  parcours (par ex. à l'étape 3) et la rouvre ? Le parcours redémarre à
  l'étape 1 (voir Assumptions).
- Que se passe-t-il si l'utilisateur désinstalle puis réinstalle l'app ?
  Le parcours est présenté à nouveau, car l'indicateur local a été effacé
  avec la désinstallation.
- Que se passe-t-il si l'appareil est hors-ligne pendant tout le
  parcours ? Aucun impact : le parcours fonctionne entièrement sans
  réseau (FR-007).
- Que se passe-t-il si l'utilisateur appuie sur "Passer" puis ferme l'app
  avant que l'écran d'inscription ne s'affiche complètement ? À la
  réouverture, le parcours ne réapparaît pas : l'indicateur local est
  marqué dès l'appui sur "Passer", l'utilisateur arrive directement sur
  l'écran d'inscription.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Le système DOIT afficher le parcours de présentation (5
  étapes) uniquement lors de la toute première ouverture de l'application
  sur un appareil, avant l'écran d'inscription.
- **FR-002**: Chaque étape DOIT présenter un visuel et un texte court
  expliquant un concept clé de l'app, dans cet ordre : Bienvenue, Profil,
  Feed, Réseau privé entre amis, Publication d'un souvenir.
- **FR-003**: Chaque étape DOIT afficher un bouton "Passer" discret,
  visible en permanence en bas de l'écran.
- **FR-004**: Le bouton "Passer" DOIT permettre à l'utilisateur de sauter
  directement à l'écran d'inscription depuis n'importe quelle étape, sans
  devoir consulter les étapes restantes.
- **FR-005**: Le système DOIT permettre à l'utilisateur de progresser
  d'une étape à la suivante parmi les 5 étapes du parcours.
- **FR-006**: Le système DOIT amener l'utilisateur à l'écran d'inscription
  à l'issue de la dernière étape, que celle-ci ait été atteinte en
  progressant étape par étape ou en appuyant sur "Passer".
- **FR-007**: Le système DOIT fonctionner intégralement hors-ligne :
  aucun appel réseau n'est nécessaire pour afficher, faire progresser ou
  passer le parcours de présentation.
- **FR-008**: Le système NE DOIT PLUS afficher le parcours de présentation
  lors des ouvertures suivantes de l'application, que l'utilisateur l'ait
  complété ou passé.
- **FR-009**: Le système DOIT retenir localement, sur l'appareil, que le
  parcours a déjà été présenté à l'utilisateur, quelle que soit la façon
  dont il s'est terminé (complété ou passé).

### Key Entities

- **Étape de présentation** : un écran du parcours, caractérisé par son
  ordre (1 à 5), son thème (Bienvenue, Profil, Feed, Réseau privé entre
  amis, Publication d'un souvenir), un visuel et un texte explicatif
  court.
- **État d'onboarding** : indicateur local à l'appareil qui retient si le
  parcours de présentation a déjà été montré à l'utilisateur (complété ou
  passé), utilisé pour décider si le parcours doit s'afficher à
  l'ouverture de l'app.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% des nouveaux utilisateurs ouvrant l'app pour la
  première fois sur un appareil voient l'étape "Bienvenue" avant l'écran
  d'inscription.
- **SC-002**: Depuis n'importe quelle étape, un utilisateur atteint
  l'écran d'inscription en une seule action (appui sur "Passer").
- **SC-003**: Un utilisateur qui parcourt les 5 étapes une à une peut
  terminer le parcours complet en moins de 60 secondes.
- **SC-004**: Aucun utilisateur ne revoit le parcours de présentation lors
  d'une ouverture ultérieure de l'app, qu'il l'ait complété ou passé la
  première fois.
- **SC-005**: Le parcours reste entièrement utilisable, sans blocage ni
  message d'erreur, en l'absence de toute connexion internet.

## Assumptions

- Le parcours est déclenché par un indicateur local à l'appareil (et non
  lié à un compte, puisqu'aucun compte n'existe encore à ce stade) ;
  désinstaller puis réinstaller l'app réinitialise cet indicateur.
- Si l'utilisateur quitte l'app avant la fin du parcours et la rouvre
  ensuite, le parcours redémarre depuis la première étape (pas de reprise
  à l'étape où il s'était arrêté) : c'est le comportement le plus simple
  et le plus prévisible pour une présentation aussi courte.
- La navigation entre les étapes (autre que via "Passer") est laissée à
  l'appréciation du design (swipe et/ou bouton "Suivant", avec ou sans
  indicateur de progression) ; la description ne l'impose pas
  explicitement, seul le bouton "Passer" est une exigence fonctionnelle.
- Les visuels et textes des 5 étapes sont des ressources embarquées dans
  l'app (aucun contenu distant), ce qui garantit le fonctionnement
  hors-ligne demandé.
