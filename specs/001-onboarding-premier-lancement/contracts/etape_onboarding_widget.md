# Contrat : `EtapeOnboarding` (tabl_ui)

Composant pur (Principe II) affichant une étape du parcours de
présentation. Vit dans
`packages/tabl_ui/lib/src/components/etape_onboarding.dart`, exporté
depuis `lib/tabl_ui.dart`. Ne dépend que de `flutter` et de
`TablTokens` — aucun import de `tabl_core`.

## Props (constructeur)

| Prop | Type | Obligatoire | Description |
|---|---|---|---|
| `titre` | `String` | oui | Titre de l'étape, déjà traduit/formaté (ex. "Bienvenue") |
| `texte` | `String` | oui | Texte explicatif court, déjà formaté, prêt à l'affichage |
| `icone` | `IconData` | oui | Visuel de l'étape — icône Material en attendant les illustrations finales du design (placeholder, voir note ci-dessous) |
| `onPasser` | `VoidCallback` | oui | Appelé quand l'utilisateur appuie sur le bouton "Passer" |
| `libellePasser` | `String` | non (défaut `'Passer'`) | Permet de garder le composant sans texte en dur si besoin de variante |

> **Note — placeholder visuel** : en l'absence d'illustrations finales
> livrées par le design, `icone` (une `IconData` Material) tient lieu de
> visuel pour cette V1. Zéro fichier binaire à produire, zéro nouvelle
> dépendance dans `tabl_ui`. Remplacer par de vraies illustrations plus
> tard ne touchera que ce composant (Principe I) — si ce remplacement
> nécessite un type différent (ex. chemin d'asset image), ce contrat
> devra être mis à jour en conséquence.

Le composant NE reçoit PAS et NE lit PAS : l'index de l'étape courante,
l'état d'onboarding persisté, ou une logique de navigation — tout ceci
reste dans `app/`.

## Comportement attendu

- Affiche `icone`, `titre`, `texte` selon les tokens du thème
  (`TablTokens`) — aucune couleur, espacement ou typo codés en dur.
- Le bouton "Passer" est toujours visible en bas de l'écran (FR-003) et
  appelle `onPasser` sans paramètre : c'est à l'appelant (`app/`) de
  décider ce que "passer" signifie (navigation directe vers
  l'inscription), le composant ne connaît pas cette destination.
- Le composant ne décide jamais lui-même de naviguer, de persister un
  état, ou de calculer quelle est la "prochaine" étape.

## Consommateur

`app/lib/ecrans/ecran_onboarding.dart` instancie ce composant 5 fois
(une par étape de la liste statique `EtapeOnboardingDonnees`, voir
`data-model.md`), lui fournit `onPasser` (navigation directe + appel à
`EtatOnboarding.marquerOnboardingVu()`), et gère séparément la
progression entre étapes (ex. `PageView`).

## Testabilité

Test widget dans `packages/tabl_ui/test/components/etape_onboarding_test.dart` :
vérifie l'affichage de `titre`/`texte`/`icone`, la présence du bouton
"Passer", et que `onPasser` est bien invoqué au tap — sans aucune
dépendance à `tabl_core` ni à un vrai `Navigator`.
