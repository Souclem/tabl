# Tabl

Application mobile sociale de restauration. Flutter (iOS + Android) + Supabase.

Un seul package Flutter (`app/`), organisé par dossiers. Pas de séparation
imposée par le compilateur entre design et métier — la discipline vient de la
convention, pas d'une frontière physique (voir "La règle d'organisation"
ci-dessous pour le pourquoi).

## Structure

```
tabl/
├── app/
│   └── lib/
│       ├── ecrans/       # les écrans ("page-vue")
│       ├── widgets/      # composants visuels purs, réutilisables
│       ├── theme/        # tokens (couleurs, espacements, typo) + thème
│       ├── services/     # métier : auth, validation, accès aux données
│       ├── navigation/   # transitions, câblage entre écrans
│       └── main.dart
├── supabase/
│   ├── migrations/       # SQL : tables + policies RLS
│   └── functions/        # fonctions Edge (TypeScript) : liens vers l'extérieur
└── scripts/              # outils hors app (données de démo, Apps Script…)
```

## La règle d'organisation

`widgets/` ne décide rien : un composant reçoit ses données déjà prêtes à
l'affichage par le constructeur (ex. `dateLisible: 'il y a 2 h'`, jamais un
`DateTime` brut à formater) et ses actions repartent par des callbacks
(`VoidCallback onTapAuteur`). Le calcul, le formatage, la règle métier vivent
dans `services/`. Cette séparation n'est plus imposée par le compilateur
(un seul package désormais) — elle tient par convention. Les écrans
(`ecrans/`) sont le seul endroit où les deux se rencontrent.

## Où va quoi

| Besoin | Emplacement |
|---|---|
| Couleur, espacement, typo | `app/lib/theme/tokens.dart` |
| Apparence d'un composant | `app/lib/widgets/` |
| Modèle de données, règle métier | `app/lib/services/` |
| Accès aux données | `app/lib/services/` |
| Écran, navigation, câblage | `app/lib/ecrans/`, `app/lib/navigation/` |
| Qui a le droit de voir quoi | policies RLS, dans `supabase/migrations/` |
| Envoi vers un service extérieur (Google Sheet…) | `supabase/functions/` |

Pas de logique métier en trigger Postgres ni en PL/pgSQL : Postgres sert aux
données et au RLS, la logique vit dans du code applicatif.

## Commandes

```
cd app && flutter run --dart-define-from-file=.env   # lancer l'app (token Mapbox dans app/.env, non commité)
flutter analyze                # analyse statique (à la racine : tout le dépôt)
cd app && flutter test         # tests
```

## Conventions

- Noms de classes, variables et commentaires **en français**.
- Les secrets (clés API, URL Supabase) ne sont jamais commités — voir `.gitignore`.
- SDK Flutter : sur le Mac, `~/development/flutter` ; sur le PC Windows, hors
  OneDrive, dans `C:\Users\lonne\dev\flutter`.

## Règles et décisions

Les règles nées de bugs réels, et les gestes réservés au propriétaire du
projet (base de prod, déploiements, builds TestFlight), sont obligatoires :

@docs/regles.md

Avant de toucher une fonctionnalité, lire sa section dans
`docs/decisions.md` (décisions produit, et ce qui attend une décision).

Les agents automatiques (Paperclip…) passent par le garde-fou
`.claude/hooks/garde_fou_agents.py`, qui bloque les gestes réservés.
