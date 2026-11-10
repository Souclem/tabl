import 'dart:typed_data';

import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'emotion.dart';
import 'presentation_finalisation.dart';

/// `{"cuisine": 4}` pour `souvenirs.notes` ; `null` quand aucune catégorie
/// n'est notée. Les autres clés et les notes hors de 1 à 5 sont écartées.
Map<String, int>? notesPourBase(Map<String, int> etoiles) {
  final notes = {
    for (final categorie in categoriesEtoiles)
      if (etoiles[categorie.cle] case final note? when note >= 1 && note <= 5)
        categorie.cle: note,
  };
  return notes.isEmpty ? null : notes;
}

/// Les notes lues dans `souvenirs.notes` (jsonb, `null` si aucune).
Map<String, int> notesDepuisBase(Object? json) => {
  if (json is Map)
    for (final e in json.entries)
      if (e.key is String && e.value is int) e.key as String: e.value as int,
};

/// Tout ce qu'il faut pour publier un moment : le contenu de l'écran de
/// finalisation, plus l'[id] généré sur le téléphone à la création du
/// brouillon. Cet id est la clé d'idempotence : le renvoyer (relance après
/// une coupure) reprend la publication au lieu d'en créer une deuxième.
class DemandePublication {
  const DemandePublication({
    required this.id,
    required this.lieu,
    required this.photos,
    required this.emotion,
    required this.priseLe,
    this.legende,
    this.etoiles = const {},
    this.amisTaguesIds = const {},
    this.audience = AudienceSouvenir.toutLeMonde,
    this.empreintes = const [],
  });

  final String id;
  final LieuRestaurant lieu;

  /// Dans l'ordre de publication, la première est la couverture. De 0
  /// (« Sans photo ») à [nombreMaxPhotosPublication].
  final List<Uint8List> photos;
  final Emotion emotion;

  /// L'heure du repas : elle donne la date et le moment (midi / soir).
  final DateTime priseLe;
  final String? legende;

  /// Notes de 1 à 5 par catégorie de [categoriesEtoiles]. Les autres clés
  /// et les notes hors de 1 à 5 sont ignorées ; une catégorie sans note est
  /// simplement absente.
  final Map<String, int> etoiles;
  final Set<String> amisTaguesIds;
  final AudienceSouvenir audience;

  /// Celles des photos venues de la photothèque, pour qu'un import les
  /// reconnaisse.
  final List<String> empreintes;
}

/// Jusqu'à dix photos par moment.
const nombreMaxPhotosPublication = 10;

/// Le résultat de l'étape 1 : le moment existe sur le serveur, invisible
/// pour tout autre que son auteur.
class MomentPrepare {
  const MomentPrepare({
    required this.id,
    this.dejaPublie = false,
    this.tablesEnEchec = const [],
  });

  final String id;

  /// Vrai quand une relance trouve le moment déjà publié (le commit avait
  /// abouti avant la coupure) : il n'y a plus rien à envoyer ni à valider.
  final bool dejaPublie;

  /// Les Tables dont l'association a échoué — jamais prétendre qu'elle a
  /// réussi. Vide si tout a réussi.
  final List<String> tablesEnEchec;
}

/// Le moment demandé n'existe plus sur le serveur (abandonné, supprimé).
class MomentIntrouvable implements Exception {
  const MomentIntrouvable(this.id);
  final String id;

  @override
  String toString() => 'MomentIntrouvable($id)';
}

/// On ne peut plus abandonner un moment déjà publié : il se supprime
/// comme n'importe quel moment publié (`SouvenirService.supprimer`).
class MomentDejaPublie implements Exception {
  const MomentDejaPublie(this.id);
  final String id;

  @override
  String toString() => 'MomentDejaPublie($id)';
}

/// Publier un moment en deux temps, pour ne jamais publier à moitié :
///
/// 1. [preparer] envoie les photos puis écrit le moment avec le statut
///    `brouillon` (le brouillon serveur, que personne d'autre ne voit) ;
/// 2. [valider] le passe à `publie` — le seul geste qui le montre aux
///    autres.
///
/// [abandonner] défait l'étape 1, tant que l'étape 2 n'a pas eu lieu.
/// Toutes les étapes se rejouent sans effet de bord (même id).
abstract interface class PublicationService {
  /// Étape 1. [surProgression] reçoit (photos envoyées, total) : 0 au
  /// départ, puis une fois par photo envoyée. Une erreur laisse ce qui a
  /// déjà été envoyé : on relance avec la même demande, ou on [abandonner].
  Future<MomentPrepare> preparer(
    DemandePublication demande, {
    void Function(int envoyees, int total)? surProgression,
  });

  /// Étape 2 : le commit. Sans effet si le moment est déjà publié. Lève
  /// [MomentIntrouvable] s'il a été abandonné entre-temps.
  Future<void> valider(String momentId);

  /// Supprime la ligne puis les photos d'un moment pas encore publié.
  /// Sans effet s'il n'existe plus ; lève [MomentDejaPublie] sinon.
  Future<void> abandonner(String momentId);
}
