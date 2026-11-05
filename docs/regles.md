# Règles du projet

Complète `CLAUDE.md`. Chaque règle vient d'un bug réel ou d'une décision
explicite du propriétaire du projet : elles sont obligatoires, pour un humain
comme pour un agent. Les décisions produit (ce que fait chaque écran, et
pourquoi) sont dans `docs/decisions.md`.

## Méthode

- **Une nouvelle règle générale s'applique rétroactivement** : chercher et
  corriger tout le code existant qui l'enfreint, puis l'ajouter ici.
- **Ne commiter qu'avec `flutter test` vert** (« All tests passed ») et
  `flutter analyze` propre.
- **`dart format` seulement sur les fichiers touchés**, jamais sur un dossier
  (`dart format lib`) : le dépôt n'est pas uniformément formaté.
- **Pas de code dupliqué.** Avant d'écrire un composant, regarder
  `app/lib/widgets/` ; avant un flux, chercher la pièce partagée (création
  d'un moment ou d'un souvenir → `ecrans/creation_moment.dart` ;
  commentaires → `ecrans/gestion_commentaires.dart` ; menu « ⋯ » d'une
  publication → `ecrans/actions_publications.dart`).
- **Pas de nouveau dossier ni de nouveau paquet** sans en discuter.
- **Itérer dans le code Flutter**, pas dans un prototype, sauf demande.
- **Ne pas élargir une demande en cours de route.** Les maquettes plus riches
  rangées dans `instruction/` ne sont pas la spec actuelle.

## Gestes réservés au propriétaire du projet

Jamais de sa propre initiative ; on prépare, puis on signale ce qu'il faut
lancer :

- `supabase db push`, `supabase functions deploy`, `supabase secrets set` —
  écrire la migration ou la fonction, puis écrire « à pousser : … ».
- Jamais `supabase config push` : le `config.toml` local (site_url
  127.0.0.1) écraserait la prod.
- Build TestFlight (`flutter build ipa`) et tout changement de `version:` dans
  `pubspec.yaml` : finir le code, commiter, puis dire « ça demandera un
  nouveau build ».
- Scripts qui écrivent dans la vraie base : `scripts/constellation_demo.py`,
  `donnees_demo.py`, `photos_demo.py`, `importer_annuaire.py`,
  `nettoyer_photos.*` (tous passent par `supabase_cli.py`).
- Push sur `main`.

Pour les agents automatiques (Paperclip…), ces gestes sont bloqués par
`.claude/hooks/garde_fou_agents.py`. Ne pas chercher à le contourner : écrire
dans la tâche ce qui reste à lancer.

## Base de données (Supabase)

- **Pas de logique métier en trigger ni en PL/pgSQL** (voir `CLAUDE.md`).
  Les fonctions SQL `security definer` qui servent la RLS ou une lecture
  sont permises.
- **Une nouvelle table n'est pas exposée d'office** : `grant` explicite aux
  rôles. Si une fonction Edge la lit ou l'écrit : `grant … to service_role`
  dans la même migration (oubli réel : les notifications étaient muettes).
- **Grants par colonne** sur certaines tables (`abonnements`,
  `demandes_avis`, `membres_table`…) : une nouvelle colonne que l'app modifie
  demande son `grant update (colonne)`, sinon « permission denied ».
- **Une policy ne relit jamais sa propre table**, même dans un `exists` :
  Postgres refuse alors toutes les requêtes de la table (42P17). Passer par
  une fonction `security definer` (`est_membre_table`,
  `est_commentaire_racine`). Arrivé deux fois.
- **Recréer une fonction SQL : partir de sa dernière version** et garder son
  mode de sécurité. `lieux_carte` doit rester `security definer` (sinon
  timeout, Explorer bloqué).
- **FK `on delete set null` ⇒ colonne nullable**, sinon la suppression de
  compte échoue.
- **Table de liaison : sa propre clé `id`** (+ contrainte unique). Avec une
  clé primaire faite de deux FK, PostgREST voit un plusieurs-à-plusieurs et
  les jointures `profils(…)` deviennent ambiguës (casse les apps installées).
  Côté app, toujours nommer la FK : `profils!commentaires_auteur_id_fkey`.
- **Stockage** : une policy de lecture qui suit un chemin stocké en base exige
  `(storage.foldername(name))[1]` = l'auteur de la ligne (exception `demo/`).
- **`peut_voir_souvenir()` est la source unique** de la visibilité d'un
  moment.
- **Vers l'extérieur** (Google Sheet, notifications…) : fonction Edge
  TypeScript appelée par l'app, jamais un webhook ni un trigger.
- **Tester toute policy sur PGlite avant de la donner à pousser.**
  `flutter test` ne voit jamais la RLS ni les grants (services simulés), et
  il n'y a pas de Docker local. Rejouer toutes les migrations sur PGlite
  (`@electric-sql/pglite`) avec de faux éléments Supabase : rôles
  `authenticated`/`service_role`, `auth.uid()` lisant
  `request.jwt.claim.sub`, `storage.objects` + `storage.foldername`,
  `unaccent` remplacé. Puis tester les accès permis et refusés.

## Photos

- **Tout envoi passe par `sansMetadonnees`**
  (`services/stockage/sans_metadonnees.dart`). Lire date et GPS
  (`lireMetadonnees`) avant, sur le téléphone ; jamais le contenu de l'image.
- **Buckets privés (`souvenirs`, `instants`) : toujours `liensSignes(…)`**
  (`services/stockage/liens_signes.dart`), jamais `createSignedUrl` à la main
  (liens expirés = photos vides partout).
- Une image vide sans erreur visible : les `errorBuilder` avalent l'erreur →
  `debugPrint` temporaire pour la voir.

## Textes et interface

- **Vouvoiement** partout, sauf l'onglet Bilan du profil (« tu »).
- **Vocabulaire Instagram** : abonnés, abonnements, « Tout le monde ». Jamais
  « cercle », « amis », « connexion » dans l'interface (seuls les textes
  d'accueil, d'inscription et de connexion peuvent dire « entre amis »).
- **Le modèle social est un suivi asymétrique**, jamais une amitié mutuelle.
- **Légende d'un moment toujours entre « »** via `legendeAffichee()` ; les
  widgets reçoivent le texte déjà formaté.
- **Date d'un repas passé** via `dateLisibleSouvenir(jourConnu:)` (« mars
  2023 » quand le jour est inconnu).
- **Les personnes s'affichent avec leur photo**, pas seulement leur pseudo.
- **Actions d'un moment : icônes sans libellé.**
- **Toute UI de visibilité passe par la feuille « Qui peut voir ? ».**
- **Mapbox** : une couleur dans une expression = chaîne `rgba(…)`, jamais un
  entier ARGB.
- **Explorer** : ne jamais envelopper l'écran de façon conditionnelle (ça
  recrée la carte Mapbox) ; une page posée par-dessus la carte est
  `opaque: false`.

## Tests

- `app/test/architecture/mur_ui_metier_test.dart` vérifie que `widgets/`
  n'importe jamais `services/`.
- Les services sont simulés dans les tests : RLS, grants et fonctions SQL se
  vérifient sur PGlite (voir plus haut).
