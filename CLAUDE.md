# Tabl

Application mobile sociale de restauration. Flutter (iOS + Android) + Supabase.

## Structure

```
tabl/
├── app/                  # l'application : navigation + branchement données ↔ UI
├── packages/
│   ├── tabl_ui/          # design system : thème, tokens, composants purs
│   └── tabl_core/        # métier : modèles, règles, accès aux données
└── supabase/             # migrations SQL (tables + policies RLS)   [à venir]
```

## La règle d'architecture principale

`tabl_ui` ne dépend que de `flutter`. Il ne peut **pas** importer `tabl_core` :
le compilateur le refuse, faute de dépendance déclarée. C'est volontaire — ça
permet à quelqu'un de retoucher le design sans pouvoir toucher au
fonctionnement. Voir `packages/tabl_ui/CLAUDE.md`.

Le sens des dépendances :

```
app  ──>  tabl_ui      (affiche)
 └───>  tabl_core      (récupère les données, applique les règles)

tabl_ui  ──X──>  tabl_core     interdit, et impossible
tabl_core ──X──> tabl_ui       interdit : le métier ignore l'écran
```

`app/` est le seul endroit où les deux se rencontrent.

## Où va quoi

| Besoin | Emplacement |
|---|---|
| Couleur, espacement, typo | `tabl_ui/lib/src/theme/tokens.dart` |
| Apparence d'un composant | `tabl_ui/lib/src/components/` |
| Modèle de données, règle métier | `tabl_core/lib/src/` |
| Accès aux données | `tabl_core/lib/src/repositories/` |
| Écran, navigation, câblage | `app/lib/` |
| Qui a le droit de voir quoi | policies RLS, dans `supabase/migrations/` |

Pas de logique métier en trigger Postgres ni en PL/pgSQL : Postgres sert aux
données et au RLS, la logique vit dans du code applicatif.

## Commandes

```
cd app && flutter run          # lancer l'app
flutter analyze                # analyse statique (à la racine : tout le dépôt)
flutter test                   # tests (dans app/ ou dans chaque package)
```

## Conventions

- Noms de classes, variables et commentaires **en français**.
- Les secrets (clés API, URL Supabase) ne sont jamais commités — voir `.gitignore`.
- Le SDK Flutter est installé hors OneDrive, dans `C:\Users\lonne\dev\flutter`.
