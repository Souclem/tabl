# Décisions produit

Ce que fait chaque partie de l'app, et pourquoi. Ces choix ont été faits par le
propriétaire du projet : avant de toucher une fonctionnalité, lire sa section,
et ne pas revenir sur une décision sans la lui soumettre. Les règles de code
sont dans `docs/regles.md`.

## En attente d'une décision du propriétaire

- **Inscription par e-mail** : la confirmation est exigée, mais l'envoi du
  mail échoue (SMTP par défaut de Supabase). Le compte n'est alors jamais
  créé, et la connexion qui suit répond « mot de passe incorrect ». Deux
  issues : couper « Confirm email » dans le dashboard (recommandé pour la
  bêta) ou un SMTP perso avec un domaine. Le code gère déjà les messages
  d'erreur (`messageErreurAuth`).
- **Constellation** : globe 3D essayé dans un prototype seulement ; plan des
  villes (rues, eau, parcs) pas fait ; performance sur un vrai iPhone avec
  beaucoup de restos jamais mesurée.
- **Explorer** : étapes 3 (fiche « Éventail ») et 4 (« Où explorer ») de la
  maquette pas encore faites (voir plus bas).
- **Deep linking** (retour dans l'app depuis un e-mail) : pas fait.
- Catégories Foursquare : traduites côté app par `libelleCategorie`
  (table de la taxonomie « Dining and Drinking » + adjectif de cuisine pour
  « X Restaurant »). Une catégorie inconnue reste en anglais : compléter la
  table au besoin.

## Social

- **Suivi asymétrique façon Instagram** (`abonnements` : `suiveur_id` →
  `suivi_id`, statut `en_attente`/`accepte`), jamais d'amitié mutuelle.
- **Profil privé par défaut.** Privé : « Tout le monde » = abonnés acceptés.
  Public : tous les utilisateurs, abonnement sans accord. Passer de privé à
  public accepte les demandes en attente.
- **Suggestions d'amis** : raisons dans l'ordre « me suit » > moments
  partagés (tags) > amis en commun (≥ 1). Jamais « mêmes restos »
  (intrusif), pas encore les contacts. Le « ✕ » est définitif et invisible
  pour l'autre. Affichées dans le Feed après la 4e publication, au plus une
  fois tous les 3 jours par appareil ; toujours dans un Feed vide ; en haut
  de l'écran Abonnés. Pas de repli « profils actifs » pour un nouvel inscrit
  sans liens.

## Publier un moment

- **Un brouillon local, plusieurs photos** : « + » ouvre la caméra ; chaque
  photo prise s'ajoute à un brouillon gardé sur le téléphone. « Continuer »
  mène à la finalisation, puis la publication passe par la cloche.
  Parcours : caméra → finalisation → cloche (`ParcoursCreation`). Chaque
  écran remplace le précédent : la caméra ne reste pas sous la finalisation,
  et « Reprendre des photos » ramène à la caméra.
- **Finalisation** : photos en grand, restaurant proposé d'après les photos
  localisées sinon la position du téléphone (« à 40 m de vous »), **émotion
  à 5 visages obligatoire**, options en lignes (Avec qui ?, Où et quand,
  Ajouter un mot), « Qui peut voir ». **Les étoiles sont facultatives** et ne
  sont jamais agrégées (pas de moyenne, pas de note globale).
- **Publication en deux temps** : le moment est d'abord envoyé invisible
  (brouillon côté base), puis publié d'un coup (commit) une fois toutes les
  photos arrivées. Un envoi interrompu ne montre jamais un moment à moitié.
- **Reprise après fermeture** : fermer la caméra, « Plus tard » ou quitter
  l'app garde le brouillon ; « + » le retrouve. Un envoi en attente repart
  dès que possible.
- **Modifier** (menu « ⋯ ») : rouvre la finalisation prérempli, sans la
  cloche ; **photos et date figées** ; les souvenirs ne sont pas encore
  modifiables.
- Pas encore : « Sans photo », pastille « N brouillons », import de photos de
  plus de 24 h.
- **Qui peut voir ?** : une feuille, jamais une page. Trois choix : Tout le
  monde / Seulement… (Tables et/ou personnes) / Tout le monde sauf…
  (personnes). Une Table choisie inclut ses futurs membres. Taguer quelqu'un
  n'élargit jamais l'audience (avertissement « X était avec vous mais ne
  verra pas ce moment ») ; une personne exclue n'est jamais notifiée du tag.

## Souvenirs (repas passés)

- Même table que les moments (`souvenirs.est_souvenir`). **Jamais dans le
  Feed** (filtré par `feed()`, pas par la RLS) ; visibles sur le profil, la
  carte et la page du restaurant.
- **Pas de souvenir sans photo** ; jusqu'à 10 photos ; mois + année suffisent
  (`jour_connu = false`).
- La photo est au cœur : choisir des photos → aperçu en grand → préremplissage
  (restaurant le plus proche avec sa distance, jour et moment de la 1re
  photo). Pas de « Lequel de ces restaurants ? » : on propose le plus proche,
  modifiable d'un toucher.
- Plusieurs endroits sur les photos : on retient le groupe le plus fourni
  (photos à < 150 m), à égalité celui de la plus ancienne photo.
- **Import de plusieurs repas** : ≤ 60 photos ; même repas si < 3 h et
  < 300 m ; revue repas par repas ; empreinte = métadonnées d'origine, jamais
  l'image.
- **Lieux personnels** (chez soi, chez un ami) : le nom se lit sur les
  souvenirs, jamais d'adresse ni de position ; absents des cartes et de la
  recherche des autres, sans page restaurant.

## Feed

- **Commentaires façon Instagram** : feuille par-dessus le Feed, réponses sur
  un seul niveau (répondre à une réponse = même fil + « @pseudo »), repliées
  sous « Voir les N réponses ». J'aime un commentaire = les deux verres en
  petit.
- **« A aimé »** : les visages de tous ceux qui ont aimé, le mien d'abord
  quand j'aime, puis les personnes que je suis, 3 au plus.
- **Plusieurs photos** : compteur « 1/3 » en haut à droite + points sous la
  photo (sur la photo, ils étaient invisibles).

## Profil

- En-tête : photo + prénom + **moments · abonnés · abonnements**. Pas de « sur
  Tabl depuis », pas de bouton Partager (aucun lien de profil à partager).
- Onglets texte : **Bilan** d'abord (au « tu », pastilles par année), puis
  **Souvenirs** (grille serrée par mois). D'autres onglets viendront
  (`RubriqueProfil`).
- J'aime = deux verres qui trinquent (choix par défaut, pas encore validé
  explicitement).

## Carte et Explorer

- La carte ne montre **que les restaurants où au moins une personne suivie
  est allée**. De loin, des bulles chiffrées (regroupement Mapbox natif,
  valable partout dans le monde) ; de près, chaque resto.
- **Explorer = la maquette « Carnet »** : grille de tuiles + barre flottante
  + recherche + thème clair et sombre (réglage Apparence
  Automatique/Clair/Sombre ; le thème de l'app le suit, écran par écran :
  fait pour le Feed et l'Explorer, le reste est en cours de migration, voir
  « Apparence » ci-dessous). Les
  modes Envies et Le cercle ont été supprimés. Filtres : feuille (papier
  en clair), une ligne par filtre, une seule ouverte, compte en direct
  (« Voir N adresses »). Tri : menu « Trié par » avec descriptions.
- **Recherche** : la pilule glisse vers le haut (jamais de téléportation) ;
  on cherche d'abord un **endroit** (villes connues puis géocodage Mapbox),
  1er résultat = « Chercher les restaurants dont le nom est « … » ».
- **Fiche « Éventail » (faite)** : bandeau nuit (photo, nom, retour,
  marque-page doré quand l'adresse est gardée, qui remplace « Garder »),
  puis les proches qui y sont allés en cartes en éventail (≤ 4 proches → 4
  cartes, au-delà 3 cartes + « +min(n−3, 10) » qui ouvre « Qui y est
  allé » ; une carte ouvre le profil), « On y va ? » (propose à l'une de
  ses Tables ; masqué sans Table) et Itinéraire (application de plans, via
  `url_launcher` ; coordonnées si on les a, sinon nom + adresse), puis
  Demander · Carte. Fiche sombre en dur (pas encore migrée au thème).
  Depuis l'Explorer, elle se pose sur la carte en `opaque: false`.
  Reste à faire : (4) « Où explorer » (rayon Automatique/1/3/10/25 km),
  titre « Autour de moi · 1 km ». Visages : ≤ 4 proches → 4 visages, au-delà
  3 visages + « +min(n−3, 10) ».
- Note /5 calculée côté app à partir des ressentis, pas en SQL.
- Réseau étendu, Premium, Créateurs/Pros : pas pour l'instant.

## Constellation

- Ciel dessiné par l'app en plein écran (`widgets/carte/ciel_constellation.dart`,
  logique dans `services/carte/ciel_constellation.dart`), immersion : seuls
  le titre, les compteurs et le bouton Constellation restent.
- Liens **Dense** (le mode « Chrono » a été refusé : tout était relié à la
  ville principale). Carte toujours affichée sous le ciel ; le plan Mapbox de
  près n'apparaît qu'au repos.
- Hiérarchie pays → régions → villes → restos ; un groupe s'ouvre quand il a
  la place à l'écran. Plus de différence entre ville et restaurant : les
  étoiles trop proches n'en font qu'une, au nom de la plus grande, et se
  dédoublent en zoomant (effet très apprécié). 5 noms au plus à l'écran,
  sans « +N ».
- Une ville peut recouvrir le nom d'une plus petite, jamais d'une plus
  grande ; même vitesse de flottement pour toutes les étoiles.

## Aide et contact

Réglages → « Aide et contact » : type + texte + 3 captures → table `retours`
→ fonction Edge `transmettre-retours` → Google Sheet de l'équipe (Apps Script
`scripts/feuille_retours.gs`). Le suivi (statut, priorité…) vit dans la
feuille, pas en base.

## Supprimer son compte

Réglages → « Supprimer mon compte » → fonction Edge `supprimer-compte` (ne
supprime que le compte du jeton) : souvenirs, lieux personnels, fichiers des
buckets, puis le compte ; le reste part en cascade depuis `profils`. Les
`retours` restent, sans auteur.

## Annuaire des restaurants

Un filtre « lieux où l'on mange » a été codé puis **mis en pause** (« pour
l'instant on garde tout ») ; rien n'a été appliqué à la base. Pour le
reprendre : `git revert dfd6712`. Exigence : des règles valables pour le
monde entier, jamais de liste d'exclusion à la main.

## Apparence (clair / sombre)

- Le réglage Apparence pilote le thème de toute l'app (`TablTheme.clair()`,
  `TablTheme.sombre()`, `themeMode`). Le clair de tous les écrans reprend la
  palette de l'Explorer (fond de lin, braise, ivoire, encre).
- La Constellation reste TOUJOURS de nuit, quel que soit le réglage.
- Connexion, inscription et accueil suivent aussi le réglage.
- Un écran lit ses couleurs par `TablCouleurs.of(context)` (dans
  `theme/tokens.dart`), jamais par `TablTokens.fond` & co, qui sont les
  couleurs du sombre seul. Un écran qui lit encore `TablTokens.<couleur>`
  est illisible en clair tant qu'il n'est pas migré.
- L'Explorer a sa propre palette (`PaletteExplorer`) et son thème la suit
  (clair avec elle, sombre dans la Constellation). Ses composants lisent
  `TablCouleurs.of(context)` ou la palette ; ses feuilles (filtres, tri,
  « Proposer », « Où cherchez-vous ? ») suivent le réglage — la feuille des
  filtres n'est plus « toujours papier » (décision réversible). Restent
  volontairement fixes : la barre flottante et les tuiles de lieux (objets
  sombres ou ivoire, encre propre à chaque type de tuile) et la pilule
  « Rechercher » (ivoire, encre). La
  fiche d'un restaurant (`widgets/carte/fiche.dart`) suit le réglage ; seul
  le voile noir posé sur sa photo, derrière le bouton retour, reste noir.
