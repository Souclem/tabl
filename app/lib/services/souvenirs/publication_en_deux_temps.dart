import 'dart:typed_data';

import '../restaurants/lieu_restaurant.dart';
import '../stockage/sans_metadonnees.dart';
import 'precompletion_souvenir.dart';
import 'publication_service.dart';

/// Ce que la publication demande au serveur, geste par geste. La logique
/// (ordre des étapes, idempotence, progression) est dans
/// [PublicationEnDeuxTemps] ; l'implémentation Supabase est un simple
/// relais, et les tests branchent un dépôt en mémoire.
abstract interface class DepotPublication {
  /// L'identifiant de l'auteur connecté : le dossier de ses photos.
  String get monId;

  /// Le statut du moment ([statutBrouillon] ou [statutPublie]) ; `null`
  /// s'il n'existe pas (ou plus).
  Future<String?> statutDe(String momentId);

  Future<String> idRestaurant(LieuRestaurant lieu);

  /// Dépose un fichier dans le dossier de l'auteur. Un fichier déjà là
  /// n'est pas une erreur (deux dépôts du même essai) ; [preparer] retire
  /// d'abord ceux d'un essai précédent, dont le contenu peut différer.
  Future<void> deposerPhoto(String chemin, Uint8List octets);

  /// Crée le moment au statut brouillon.
  Future<void> creerBrouillon(String momentId, Map<String, Object?> colonnes);

  /// Remet à jour un brouillon existant (relance), sans toucher au statut.
  Future<void> mettreAJourBrouillon(
    String momentId,
    Map<String, Object?> colonnes,
  );

  /// Retire d'un brouillon existant les photos supplémentaires, les amis
  /// tagués et les associations de Tables : une relance les réécrit depuis
  /// la demande, pour que le serveur ne garde rien de ce que l'auteur a
  /// retiré entre-temps.
  Future<void> viderLiens(String momentId);

  /// Écrit les lignes liées ; rejouable : ce qui existe déjà est gardé,
  /// la liste des personnes de l'audience remplace l'ancienne.
  Future<void> ecrireLiens(
    String momentId, {
    required List<String> cheminsAutresPhotos,
    required Set<String> empreintes,
    required Set<String> amisTaguesIds,
    required Set<String> personnesAudienceIds,
  });

  /// Associe le moment aux Tables ; retourne celles qui ont échoué.
  Future<List<String>> associerTables(String momentId, Set<String> tableIds);

  /// `UPDATE statut = 'publie'` d'un brouillon ; faux si aucune ligne n'a
  /// été touchée (déjà publié, ou disparu).
  Future<bool> passerEnPublie(String momentId);

  /// Les fichiers déposés pour ce moment, retrouvés par leur nom — même si
  /// la ligne n'a jamais été écrite.
  Future<List<String>> fichiersDuMoment(String momentId);

  Future<void> supprimerLigne(String momentId);
  Future<void> supprimerFichiers(List<String> chemins);
}

const statutBrouillon = 'brouillon';
const statutPublie = 'publie';

/// Le nom du fichier d'une photo : fixe, pour qu'une relance retombe sur le
/// même fichier au lieu d'en déposer un autre.
String cheminPhotoMoment(String monId, String momentId, int rang) =>
    '$monId/$momentId-$rang.jpg';

class PublicationEnDeuxTemps implements PublicationService {
  PublicationEnDeuxTemps(this._depot);

  final DepotPublication _depot;

  @override
  Future<MomentPrepare> preparer(
    DemandePublication demande, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    if (demande.photos.length > nombreMaxPhotosPublication) {
      throw ArgumentError.value(
        demande.photos.length,
        'photos',
        'au plus $nombreMaxPhotosPublication photos',
      );
    }

    final statut = await _depot.statutDe(demande.id);
    if (statut == statutPublie) {
      return MomentPrepare(id: demande.id, dejaPublie: true);
    }

    // Une relance repart de zéro côté serveur : le brouillon garde l'id mais
    // pas son ancien contenu (Table, ami ou photo retirés, couverture
    // changée), qui sinon serait publié ou resterait visible des membres
    // d'une Table retirée.
    if (statut == statutBrouillon) await _depot.viderLiens(demande.id);
    final anciens = await _depot.fichiersDuMoment(demande.id);
    if (anciens.isNotEmpty) await _depot.supprimerFichiers(anciens);

    final total = demande.photos.length;
    final monId = _depot.monId;
    surProgression?.call(0, total);
    var envoyees = 0;
    // Toutes ensemble : dix photos l'une après l'autre feraient attendre.
    final chemins = await Future.wait([
      for (var rang = 0; rang < total; rang++)
        _depot
            .deposerPhoto(
              cheminPhotoMoment(monId, demande.id, rang),
              sansMetadonnees(demande.photos[rang]),
            )
            .then((_) => surProgression?.call(++envoyees, total))
            .then((_) => cheminPhotoMoment(monId, demande.id, rang)),
    ]);

    final audience = demande.audience.normalisee();
    final colonnes = <String, Object?>{
      'restaurant_id': await _depot.idRestaurant(demande.lieu),
      'photo_url': chemins.firstOrNull,
      'visibilite': audience.mode.valeur,
      'legende': demande.legende,
      'emotion': demande.emotion.emoji,
      'moment': momentDuJour(demande.priseLe),
      'date_visite': _dateIso(demande.priseLe),
      'notes': notesPourBase(demande.etoiles),
    };
    if (statut == null) {
      await _depot.creerBrouillon(demande.id, {
        'auteur_id': monId,
        'statut': statutBrouillon,
        ...colonnes,
      });
    } else {
      await _depot.mettreAJourBrouillon(demande.id, colonnes);
    }

    await _depot.ecrireLiens(
      demande.id,
      cheminsAutresPhotos: chemins.skip(1).toList(),
      empreintes: demande.empreintes.toSet(),
      amisTaguesIds: demande.amisTaguesIds,
      personnesAudienceIds: audience.personneIds,
    );
    final tablesEnEchec = await _depot.associerTables(
      demande.id,
      audience.tableIds,
    );
    return MomentPrepare(id: demande.id, tablesEnEchec: tablesEnEchec);
  }

  @override
  Future<void> valider(String momentId) async {
    if (await _depot.passerEnPublie(momentId)) return;
    // Aucune ligne touchée : soit le commit avait déjà abouti (relance),
    // soit le moment a disparu.
    final statut = await _depot.statutDe(momentId);
    if (statut == null) throw MomentIntrouvable(momentId);
  }

  @override
  Future<void> abandonner(String momentId) async {
    final statut = await _depot.statutDe(momentId);
    if (statut == statutPublie) throw MomentDejaPublie(momentId);
    // Les fichiers sont repérés avant : une fois la ligne partie, plus
    // rien ne dirait lesquels étaient les siens.
    final fichiers = await _depot.fichiersDuMoment(momentId);
    if (statut != null) await _depot.supprimerLigne(momentId);
    if (fichiers.isNotEmpty) await _depot.supprimerFichiers(fichiers);
  }
}

String _dateIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
