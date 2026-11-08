<!--
Sync Impact Report
Version change: 1.1.0 → 2.0.0 (Principe I redéfini de façon incompatible)
Modified principles:
  - I. Séparation UI / Métier → devenu "Organisation par dossiers" : la
    séparation `tabl_ui`/`tabl_core` imposée par le compilateur est retirée
    (monorepo à 3 packages fusionné en un seul package `app/`, organisé par
    dossiers `widgets/`, `theme/`, `services/`). La discipline devient une
    convention de code, plus une contrainte du compilateur.
  - II. Composants UI purs → chemin des tokens mis à jour
    (`app/lib/theme/tokens.dart` au lieu de `tabl_ui/lib/src/theme/tokens.dart`).
Added sections: none
Removed sections: none
Deferred / TODO: none
Templates requiring follow-up: specs historiques (specs/001-*) non réécrites
  rétroactivement — elles restent un instantané de l'architecture au moment
  où la fonctionnalité a été construite.
-->

# Tabl Constitution

## Core Principles

### I. Organisation par dossiers
Le dépôt est un seul package Flutter (`app/`), organisé en dossiers à sens
de dépendance unique : `widgets/` et `theme/` (visuel) ne dépendent que de
`flutter` ; `services/` (métier, accès aux données) ignore l'existence de
l'écran ; `ecrans/` est le seul endroit où les deux se rencontrent. Cette
séparation n'est plus imposée par le compilateur (elle l'était quand
`tabl_ui`/`tabl_core` étaient des packages distincts) — elle tient par
convention et relecture de code.
**Rationale** : pour un dépôt de cette taille, le coût d'une frontière
compilée (plusieurs `pubspec.yaml`, imports inter-packages) dépassait son
bénéfice. Garder l'organisation en dossiers préserve l'intention (design
retouchable sans casser le métier) sans la lourdeur du multi-package.

### II. Composants UI purs
Un composant de `app/lib/widgets/` ne décide rien : les données lui
arrivent par le constructeur déjà prêtes à l'affichage (ex.
`dateLisible: 'il y a 2 h'`, jamais un `DateTime` brut à formater), et les
actions repartent par des callbacks (`VoidCallback onTapAuteur`). Aucune
valeur codée en dur — couleur, espacement, typo — tout vient de
`TablTokens` (`app/lib/theme/tokens.dart`).
**Rationale** : le calcul, le formatage, la règle métier vivent dans
`app/lib/services/` ; le composant se contente d'afficher et de signaler,
ce qui le garde réutilisable et testable indépendamment des données
réelles.

### III. Logique métier hors de Postgres
Aucune logique métier en trigger Postgres ni en PL/pgSQL. Postgres sert aux
données et au contrôle d'accès (policies RLS dans `supabase/migrations/`) ;
la logique elle-même vit dans le code applicatif (`app/lib/services/`).
**Rationale** : garder la logique testable, lisible et versionnée avec le
reste du code, plutôt que dispersée et difficile à faire évoluer dans la
base de données.

### IV. Français pour le code
Noms de classes, variables et commentaires sont en français, dans tout le
dépôt (`app/`, `supabase/`).
**Rationale** : cohérence avec le domaine (restauration sociale, produit et
équipe francophones) et lisibilité uniforme du code source.

### V. Secrets jamais commités
Aucune clé API, URL Supabase ou autre secret n'est commité dans le dépôt ;
ils sont exclus via `.gitignore` et fournis par l'environnement local.
**Rationale** : éviter toute fuite d'identifiants dans l'historique git, quel
que soit le futur du dépôt (partage, passage en public, etc.).

### VI. Comportement réseau explicite
Chaque spec de fonctionnalité déclare si elle nécessite une connexion
internet active ou si elle doit fonctionner hors-ligne, avant que
l'implémentation ne commence.
**Rationale** : Tabl s'utilise dans des contextes de connectivité variable
(restaurants, déplacements) ; laisser ce comportement implicite mène à des
écrans qui bloquent silencieusement sans réseau. Le documenter dans la spec
force la décision au bon moment, pas en debug après coup.

## Stack technique et structure

Application mobile Flutter (iOS + Android) adossée à Supabase (Postgres +
Auth + RLS). Un seul package (`app/`), organisé en dossiers à sens de
dépendance unique :

```
app/lib/
  widgets/    → dépend uniquement de flutter (design system)
  theme/      → dépend uniquement de flutter (tokens, thème)
  services/   → métier : modèles, règles, accès aux données
  ecrans/     → dépend de widgets/, theme/ et services/ (écrans, câblage)
supabase/     → migrations SQL (tables + policies RLS)
```

Toute nouvelle fonctionnalité respecte ce découpage : le visuel dans
`widgets/`/`theme/`, le métier et l'accès aux données dans `services/`,
l'assemblage dans `ecrans/`, les droits d'accès dans les migrations
Supabase.

## Workflow de vérification

Avant de considérer un travail terminé :

```
flutter analyze     # à la racine du dépôt : couvre tout le dépôt
cd app && flutter test
```

Ces deux commandes DOIVENT passer sans erreur.

## Governance

Cette constitution prévaut sur toute autre pratique ou préférence
individuelle au sein du dépôt. Toute modification :

1. Est documentée dans ce fichier, avec mise à jour du Sync Impact Report
   en tête de fichier.
2. Suit le versionnage sémantique : MAJOR pour une suppression ou
   redéfinition incompatible d'un principe, MINOR pour l'ajout d'un principe
   ou d'une section, PATCH pour une clarification sans changement de sens.
3. Met à jour `LAST_AMENDED_DATE` à la date du changement.

La conformité se vérifie par les commandes du Workflow de vérification
ci-dessus ; toute exception (ex. dérogation temporaire à un principe) doit
être justifiée explicitement dans la description de la tâche ou de la PR
concernée.

**Version**: 2.0.0 | **Ratified**: 2026-08-16 | **Last Amended**: 2026-08-18
