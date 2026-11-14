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
- **Onglet Tables : « en construction »** (2026-11-14). L'écran des Tables
  (`EcranTables`) est gardé tel quel ; `_tablesEnConstruction` dans
  `ecran_principal.dart` le rallume. Les autres accès aux Tables
  (« On y va ? » sur une fiche, filtre « Une Table », audience d'un moment)
  restent ouverts.
- **À faire — « Où et quand » : chercher un restaurant sur la carte**, en
  plus de la recherche par nom et des propositions (demandé, pas encore
  fait).
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

- **Un brouillon local, plusieurs photos** : chaque photo prise ou importée
  s'ajoute, à la suite, au brouillon ouvert dans la caméra, quelle que soit
  sa date (pas de regroupement automatique par heure : un deuxième import
  ne remplace jamais les photos déjà là). On en retire une avec le ×.
  « Continuer » mène à la finalisation, puis la publication passe par la
  cloche. Parcours : caméra → finalisation → cloche (`ParcoursCreation`).
  Chaque écran remplace le précédent : la caméra ne reste pas sous la
  finalisation, et l'appareil photo en haut à droite de la finalisation
  (« Reprendre des photos ») ramène à la caméra, sur le même brouillon.
  Plus de feuille « Photos du moment » ni d'étape « Choisir les photos » :
  le tri se fait dans la caméra (× sur une photo), qui ne laisse continuer
  qu'avec une à dix photos ; toutes les photos du brouillon sont publiées.
- **« + » et les brouillons** : sans brouillon en cours, « + » ouvre
  directement la caméra. Sinon, la feuille « Brouillons » les liste (le
  plus récent d'abord ; la corbeille d'une ligne le supprime après
  confirmation), avec « Nouveau moment » en dernier. Reprendre un brouillon
  ouvre la caméra avec ses photos. **Trois brouillons au maximum** : au-delà,
  « Nouveau moment » est grisé et dit d'en publier ou d'en supprimer un ;
  le toucher quand même ne crée rien : la ligne grossit, tremble et le
  téléphone vibre. Si les brouillons ne peuvent pas être lus, « + » ne
  crée rien non plus (un message d'erreur) : ce serait peut-être le
  quatrième. Un
  moment qui attend d'être envoyé (« Envoyer dès que possible ») n'est pas
  proposé. S'il en reste davantage sur le téléphone (d'avant la limite), les
  plus anciens sont effacés à l'ouverture de « + ».
- **Dix photos au plus par moment** : la caméra laisse en prendre
  davantage, mais « Continuer » est grisé au-delà de 10 ; le toucher fait
  trembler le bouton (avec vibration) et dit combien en retirer. Le
  compteur le dit aussi (« 13 photos · retirez-en 3 pour continuer »).
- **Éventail de la caméra** : les photos dans l'ordre de publication (la
  première en haut de l'arc ; au-delà de six, les six dernières). Toucher
  une photo l'agrandit, le × la supprime ; la glisser (tout de suite, ou
  après un appui long) la soulève : on la pose à une autre place (les
  autres s'écartent) ou dans la corbeille.
- **Finalisation** : photos en grand, restaurant proposé d'après les photos
  localisées sinon la position du téléphone (« à 40 m de vous »), **émotion
  à 5 visages obligatoire**, options en lignes (Avec qui ?, Où et quand,
  Ajouter un mot), « Qui peut voir ». **Les étoiles sont facultatives** et ne
  sont jamais agrégées (pas de moyenne, pas de note globale). **« Publier »
  ne fait que publier** (2026-11-14) : il reste grisé tant qu'il manque le
  lieu ou l'émotion, et le toucher fait respirer ce qui manque (la ligne du
  lieu, la rangée d'émotions). Il n'ouvre jamais « Où et quand » : le lieu
  se choisit en touchant son nom, en haut à gauche.
- **Où l'on a mangé** (2026-11-14, « la maison discrète ») — décision née
  d'une fuite : un « chez moi » saisi comme restaurant recevait la position
  du téléphone et plaçait le domicile sur la carte des abonnés.
  - **Seul un lieu ouvert au public a une position.** Chez moi, chez
    quelqu'un, ailleurs : un lieu personnel (`restaurants.prive`, avec
    `genre` `domicile` / `chez` / `ailleurs`), sans adresse ni position —
    la contrainte `lieu_personnel_sans_adresse` le garantit en base.
    Jamais la position du téléphone sur un lieu ; un restaurant pas dans
    Tabl n'a de position que si l'on place soi-même son épingle sur une
    carte (« Ce lieu sera visible sur la carte par vos abonnés »), qui part
    de l'endroit des photos. Sans épingle, il n'est sur aucune carte.
  - **La feuille « Où et quand »** : le restaurant d'abord, la majorité des
    cas. Le plus probable (photos, sinon position du téléphone, qui ne sert
    qu'à trier) est **déjà coché, sans question** (plus de « Étiez-vous
    chez X ? » ni de pastille « à confirmer ») ; toucher une autre ligne la
    coche et **replie la liste** sur ce choix (« Voir les autres
    restaurants », ou retoucher le choix, la rouvre) ; « OK » ferme. La
    liste va jusqu'à 20 restaurants autour des photos et défile, le moment
    du repas restant fixe en bas. La maison s'anime (petit rebond, listes
    en fondu). **Tout se passe dans la feuille** (2026-11-14) :
    la recherche cherche au fil de la frappe sans ouvrir d'autre feuille,
    et « Pas dans Tabl ? Ajoutez-le » s'écrit sur place (nom déjà repris
    de la recherche, ville, « Placer sur la carte » pour l'épingle). À
    droite de la recherche, **une maison** : touchée, le verre se
    réchauffe et la maison devient dorée, sans texte d'explication. Une
    **rangée de ronds qui défile de côté** : Chez moi, toutes les personnes
    que l'on suit (photo et pseudo ; celles qui étaient à table d'abord),
    mes « chez » et « Chez… » pour quelqu'un qui n'est pas sur Tabl
    (« Mamie » → « Chez Mamie »). Puis « Chez personne » : Pique-nique, Au
    travail, En voyage, Une fête, Autre. La feuille garde sa hauteur quel
    que soit le nombre d'abonnements : « Chez personne », le moment du
    repas (en pied, toujours visible) et « OK » restent à l'écran. Le
    bureau est « ailleurs » exprès : un lieu de travail répété est aussi
    sensible qu'un domicile.
  - **Chez moi** se lit « Chez vous » pour soi, « Chez Léa » (le
    pseudo de l'auteur) pour les autres.
  - **Chez quelqu'un de Tabl** : lié à son profil, jamais à une adresse
    (`restaurants.hote_id`, seulement quelqu'un qu'on suit). L'hôte est
    coché d'office dans « Avec qui » (décochable ; comme un tag, ça
    n'élargit pas l'audience), prévenu dans ses notifications (« X a publié
    un moment chez vous », si le moment lui est visible) et peut **retirer
    son nom** (menu « ⋯ ») : le lieu redevient « Chez quelqu'un ». Sur le
    Fil, sa photo à la place de l'épingle ; toucher le lieu ouvre son
    profil. Hors restaurant sans hôte : une maison, jamais l'épingle
    (l'épingle veut dire « sur la carte »).
  - En-tête de la finalisation : sans lieu, « Où étiez-vous ? » en
    pointillé ; sinon le lieu (épingle, maison ou photo de l'hôte) et un
    chevron.
  - Pas encore (proposés, pas demandés) : « à emporter / livré » ; ne rien
    cocher d'office quand aucun restaurant n'est à moins de 80 m ;
    « Chez vous ? » retenu sur le téléphone ; demander « C'est chez
    quelqu'un ? » quand un restaurant saisi à la main s'appelle « chez… »,
    « maison »… ; la notification push de « chez vous » (seulement dans
    l'écran des notifications pour l'instant).
- **Rappels de brouillon** : un brouillon pas encore publié envoie une
  notification 2 h puis 5 h après sa dernière modification (« Votre moment
  chez … »). Programmés quand l'app passe en arrière-plan, retirés quand
  elle revient : ils ne sonnent jamais app ouverte. Annulés dès que le
  moment part (cloche, « Envoyer dès que possible ») ou est publié. Le
  toucher ouvre « + ». Sans paquet : notifications locales iOS par le canal
  natif `tabl/notifications` (`AppDelegate.swift`) — iPhone seulement,
  comme les notifications push.
- **Plats notés** (« Ce qui ressort ») : en plus des cinq catégories, on
  écrit le nom d'un plat (ou d'un vin…) et on le note, **cinq au plus** par
  moment, 40 caractères chacun. Un plat écrit sans toucher « Ajouter » est
  gardé à la fermeture. En base : `souvenirs.notes` →
  `{"cuisine": 4, "plats": [{"nom": "Risotto", "note": 5}]}` (seuls les
  plats notés sont envoyés). Jamais agrégés non plus.
- **Style des commandes de création** (caméra, finalisation, feuille
  « Brouillons ») : celui du prototype « Création V5 ». Police Instrument
  Sans ; rail en ronds de verre de 42 px (« Aa », étincelle, silhouettes) ;
  émojis dans une capsule de verre ; « Plus tard » et l'audience en pilules
  de verre de 40 px ; bouton principal en pilule de 50 px, à sa largeur. La
  feuille « Brouillons » est toujours sombre, comme la caméra.
- **En-tête et feuilles de la finalisation**, même prototype, sans les
  traits de progression en haut (ça ferait « story » : on publie). En haut,
  sous « Plus tard » : le lieu (voir « Où l'on a mangé »), le moment du
  repas, puis le mot en italique — rien quand il n'y a pas de mot, le rail le propose. Les
  feuilles « Où et quand », « Ce qui ressort » (« facultatif »), « Avec
  qui » sont en verre sombre : titre court, rubriques en petites capitales,
  lignes à case ronde, bouton en bas à droite (« OK » ; « Passer » ou
  « Valider » pour les étoiles). Verre du prototype : flou 20, couleurs
  saturées, teinte nuit à 36 % — la photo se voit à travers (teinte chaude
  côté maison d'« Où et quand »). Le moment du repas : « Petit-déjeuner » (`matin`, 5 h –
  10 h), « Déjeuner » (`midi`), « Dîner » (`soir`), comme l'en-tête ; pas
  de goûter (non demandé). Le filtre « moment » d'Explorer ne propose
  encore que déjeuner et dîner. « Ajouter un mot » est une barre posée sur le
  clavier. Une photo supprimée dit seulement « Photo supprimée » avec
  « Annuler » : aucune corbeille n'est montrée, on ne promet donc pas de la
  récupérer plus tard.
- **Ordre du Feed et du profil** : les moments arrivent du plus récemment
  publié au plus ancien (`cree_le`), pas par date du repas : un repas
  ancien (photos de 2009) publié aujourd'hui doit apparaître tout de suite.
  Le journal du profil le range ensuite sous le mois du repas.
- **Publication en deux temps** : le moment est d'abord envoyé invisible
  (brouillon côté base), puis publié d'un coup (commit) une fois toutes les
  photos arrivées. Un envoi interrompu ne montre jamais un moment à moitié.
- **Reprise après fermeture** : fermer la caméra, « Plus tard » ou quitter
  l'app garde le brouillon ; « + » le retrouve. Un envoi en attente repart
  dès que possible.
- **Pendant la cloche** (2026-11-14) : ni « Modifier » ni « Annuler ».
  Une fois « Publier » touché, la publication va au bout ; les boutons
  n'apparaissent qu'en cas d'échec ou sans réseau (Garder en brouillon,
  Réessayer, Envoyer dès que possible).
- **Après la cloche** (`suiteApresCloche`, câblé dans `EcranPrincipal`) :
  publié ou déjà publié → retour au Fil, rechargé de zéro, le nouveau moment
  en haut, sans message ; brouillon incomplet → on reste sur la
  finalisation ;
  annulé, gardé en brouillon, en attente → rien ne change (on reste sur
  l'onglet d'où l'on est parti) et un message discret dit que le moment est
  gardé sur le téléphone (il n'y a pas encore de bandeau de brouillon dans
  le Fil). Si des Tables n'ont pas pu être associées, le moment est publié
  et un message discret le dit. Pas encore : la puce « n-ième fois ici »
  (rien ne la définit : ni texte, ni règle de comptage).
- **Modifier** (menu « ⋯ ») : rouvre la finalisation prérempli, sans la
  cloche ; **photos et date figées** ; les souvenirs ne sont pas encore
  modifiables.
- Pas encore : « Sans photo », import de photos de plus de 24 h.
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
  recherche des autres, sans page restaurant. Mêmes règles que pour un
  moment (voir « Où l'on a mangé ») ; l'ajout d'un souvenir passe encore
  par « Quel restaurant ? » (« Créer un lieu personnel »), pas par la
  maison.

## Feed

- **Commentaires façon Instagram** : feuille par-dessus le Feed, réponses sur
  un seul niveau (répondre à une réponse = même fil + « @pseudo »), repliées
  sous « Voir les N réponses ». J'aime un commentaire = la cloche en
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
- **J'aime = la cloche de service** (2026-11-14, remplace les deux verres
  qui trinquent) : au tap, le dôme se soulève, un cœur doré jaillit, puis
  la cloche retombe et se remplit d'or, le cœur gravé dedans. Retaper la
  vide, sans animation.

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
  on cherche d'abord un **endroit** (villes connues puis géocodage Mapbox :
  villes, quartiers, rues, adresses, codes postaux), 1er résultat =
  « Chercher les restaurants dont le nom est « … » ». Un endroit choisi
  où personne n'est allé : la carte recule, centrée sur lui, jusqu'aux 3
  adresses les plus proches (à moins de 25 km ; au-delà, elle reste sur
  l'endroit et dit « rien ici »). La barre flottante
  (Rechercher, filtres, Carte | Grille) s'efface pendant qu'on déplace la
  carte du doigt et revient quand elle s'arrête.
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
