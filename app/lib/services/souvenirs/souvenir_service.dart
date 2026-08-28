import 'dart:typed_data';

import 'commentaire.dart';
import 'souvenir_feed.dart';

/// Publier un souvenir : le cœur du Feed.
///
/// Capture d'abord, comme le flux réel de la maquette Claude Design
/// (`isPublish` dans `Tabl.dc.html`) : une photo, une phrase parmi 4
/// prédéfinies, le nom et la ville du restaurant. Rien d'autre à
/// remplir — le moment (midi/soir) et la date sont déduits de
/// maintenant plutôt que demandés, dans le même esprit "instantané".
///
/// Pas de sélection de restaurant existant via API de lieux (pas encore
/// branchée) — voir [SouvenirService].
abstract interface class SouvenirService {
  /// Publie un souvenir. Trouve un restaurant existant avec ce nom et
  /// cette ville (comparaison insensible à la casse) et le réutilise,
  /// sinon en crée un nouveau.
  Future<void> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    String? legende,
  });

  /// Le Feed : les souvenirs qu'on a le droit de voir (les siens, et ceux
  /// des abonnements acceptés — la RLS de `souvenirs` s'en charge, ce
  /// service n'a rien à filtrer lui-même), du plus récent au plus ancien.
  Future<List<SouvenirFeed>> feed();

  /// Ajoute sa réaction ("j'aime") si [reagir] est vrai, la retire sinon.
  Future<void> basculerReaction(String souvenirId, {required bool reagir});

  /// Les commentaires d'un souvenir, du plus ancien au plus récent.
  Future<List<Commentaire>> commentaires(String souvenirId);

  /// Publie un commentaire.
  Future<void> commenter(String souvenirId, String texte);

  /// Retire son propre commentaire.
  Future<void> supprimerCommentaire(String commentaireId);
}
