import 'dart:typed_data';

import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'commentaire.dart';
import 'emotion.dart';
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

  /// Finalise et publie un souvenir. [emotion] est la seule information
  /// obligatoire en plus de ce qui est déjà acquis (photo, restaurant) —
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
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
  });

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
  Future<List<SouvenirFeed>> feed();

  /// Les souvenirs publiés d'un seul auteur, même ordre que [feed] —
  /// pour une page de profil. La RLS reste seule juge : sur le profil de
  /// quelqu'un qu'on ne suit pas, la liste revient simplement vide.
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId);

  /// Ajoute sa réaction ("j'aime") si [reagir] est vrai, la retire sinon.
  Future<void> basculerReaction(String souvenirId, {required bool reagir});

  /// Les commentaires d'un souvenir, du plus ancien au plus récent.
  Future<List<Commentaire>> commentaires(String souvenirId);

  /// Publie un commentaire.
  Future<void> commenter(String souvenirId, String texte);

  /// Retire son propre commentaire.
  Future<void> supprimerCommentaire(String commentaireId);
}
