import 'dart:typed_data';

import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'commentaire.dart';
import 'emotion.dart';
import 'nouveau_souvenir.dart';
import 'souvenir_feed.dart';

/// Publier un souvenir : le cœur du Feed.
///
/// Parcours en plusieurs temps (voir
/// `instruction/Clément (2)/scraps/clement.txt`, B7-B11) : la photo est
/// capturée puis, soit enregistrée en [enregistrerBrouillon] ("Plus
/// tard" — reprise possible depuis le Profil, non construite ici), soit
/// finalisée directement via [publier] sans jamais transiter par un
/// brouillon serveur ("Finaliser maintenant").
abstract interface class SouvenirService {
  /// Enregistre un brouillon ("Plus tard") : seule la photo et le lieu
  /// sont acquis à ce stade, rien d'autre n'est demandé. Retourne
  /// l'identifiant du souvenir créé, statut `brouillon` — invisible pour
  /// quiconque d'autre que l'auteur tant qu'il n'est pas finalisé.
  Future<String> enregistrerBrouillon({
    required LieuRestaurant lieu,
    required Uint8List photo,
  });

  /// Finalise et publie un souvenir. [photos] : au moins une, au plus
  /// [nombreMaxPhotosSouvenir], la première est la principale ;
  /// [empreintes] : celles des photos venues de la photothèque, pour
  /// qu'un import les reconnaisse. [emotion] est la seule information
  /// obligatoire en plus de ce qui est déjà acquis (photos, restaurant) —
  /// tout le reste ([legende], [amisTaguesIds], la boisson) reste
  /// optionnel, conformément à la maquette de finalisation.
  ///
  /// [audience] : qui peut voir (voir [AudienceSouvenir]). Ses Tables
  /// (mode "Seulement…") sont des associations, jamais une deuxième
  /// publication — l'expérience créée ici est la seule source (megaprompt
  /// Bloc 5, règle 5, 26). Retourne
  /// les identifiants de Table dont l'association a échoué (règle 51 :
  /// ne jamais prétendre qu'une association a réussi si elle a échoué) —
  /// liste vide si tout a réussi. La publication elle-même n'échoue
  /// jamais à cause d'un échec d'association : le souvenir est déjà créé
  /// à ce stade.
  Future<List<String>> publier({
    required LieuRestaurant lieu,
    required List<Uint8List> photos,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> empreintes = const [],
  });

  /// Ajoute un repas passé à son profil ([NouveauSouvenir]) : il se range
  /// à sa date sur le profil et la carte, jamais dans le Feed. Même
  /// retour que [publier] : les Tables dont l'association a échoué.
  Future<List<String>> ajouterSouvenir(NouveauSouvenir souvenir);

  /// Les empreintes des photos déjà rangées dans mes souvenirs, pour
  /// qu'un import les ignore.
  Future<Set<String>> empreintesImportees();

  /// L'audience actuelle d'un souvenir déjà publié, et les amis tagués
  /// (pour l'avertissement "ne verra pas ce moment") — pour préremplir
  /// la feuille "Qui peut voir ?". Réservé à l'auteur (RLS).
  Future<({AudienceSouvenir audience, Set<String> amisTaguesIds})>
  audienceActuelle(String souvenirId);

  /// Remplace l'audience d'un souvenir déjà publié : mode, personnes et
  /// Tables (les Tables retirées sont désassociées, les nouvelles
  /// ajoutées — règle 42, 48). Ne change jamais la date d'origine du
  /// souvenir (règle 40, 68) ni ne recrée d'item Feed (règle 41, 65).
  /// Retourne les Tables dont l'association a échoué. Réservé à
  /// l'auteur (RLS).
  Future<List<String>> modifierAudience(
    String souvenirId,
    AudienceSouvenir audience,
  );

  /// Le Feed : les souvenirs qu'on a le droit de voir (les siens, et ceux
  /// des abonnements acceptés — la RLS de `souvenirs` s'en charge, ce
  /// service n'a rien à filtrer lui-même), du plus récent au plus ancien.
  /// Sans les repas passés ajoutés après coup ([ajouterSouvenir]).
  Future<List<SouvenirFeed>> feed();

  /// Un seul souvenir, s'il est visible (une notification y mène) ;
  /// `null` sinon.
  Future<SouvenirFeed?> souvenir(String souvenirId);

  /// Les souvenirs publiés d'un seul auteur, même ordre que [feed] —
  /// pour une page de profil. La RLS reste seule juge : sur le profil de
  /// quelqu'un qu'on ne suit pas, la liste revient simplement vide.
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId);

  /// Mes propres moments où [profilId] est tagué comme présent — avec
  /// ceux de son profil où c'est moi qui le suis, ils font « vos
  /// moments à deux ».
  Future<List<SouvenirFeed>> mesMomentsAvec(String profilId);

  /// Les avis de mon réseau sur un restaurant (même réseau que le Feed :
  /// les miens, ceux des personnes que je suis, ceux qui m'ont été
  /// adressés), du plus récent au plus ancien — pour sa page.
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId);

  /// Ajoute le restaurant à mes envies ("Enregistrer") ou l'en retire.
  Future<void> basculerEnvie(String restaurantId, {required bool envie});

  /// Supprime l'un de ses souvenirs ou de ses moments, définitivement :
  /// ses photos, réactions, commentaires et Instants partent avec lui.
  /// Réservé à l'auteur (RLS).
  Future<void> supprimer(String souvenirId);

  /// Ajoute sa réaction ("j'aime") si [reagir] est vrai, la retire sinon.
  Future<void> basculerReaction(String souvenirId, {required bool reagir});

  /// Les commentaires d'un souvenir, du plus ancien au plus récent.
  Future<List<Commentaire>> commentaires(String souvenirId);

  /// Publie un commentaire.
  Future<void> commenter(String souvenirId, String texte);

  /// Retire son propre commentaire.
  Future<void> supprimerCommentaire(String commentaireId);
}
