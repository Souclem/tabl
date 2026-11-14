import 'dart:async';
import 'dart:typed_data';

import '../position/position_service.dart';
import 'brouillon_local.dart';
import 'metadonnees_photo.dart';
import 'nouveau_souvenir.dart';

/// Une séance sur l'écran caméra, sur un seul brouillon : celui choisi en
/// ouvrant la caméra ([actif]), ou un nouveau, créé à la première photo.
/// Toutes les photos prises ou importées s'y ajoutent, à la suite, quelle
/// que soit leur date. Les ajouts se font l'un après l'autre, donc des
/// déclenchements rapprochés ne se marchent pas dessus.
class SessionCamera {
  SessionCamera(
    this._brouillons, {
    this.actif,
    this.positionService,
    DateTime Function()? maintenant,
  }) : _maintenant = maintenant ?? DateTime.now;

  final BrouillonsLocaux _brouillons;

  /// Sans lui, les photos prises n'ont pas de position.
  final PositionService? positionService;
  final DateTime Function() _maintenant;

  Future<void> _file = Future.value();
  Future<void>? _positionEnCours;
  PositionPrise? _position;

  /// Le brouillon qui reçoit les photos ; `null` jusqu'à la première d'un
  /// nouveau moment.
  Brouillon? actif;

  /// Relève où l'on est, pour la prochaine photo. Une seule demande à la
  /// fois ; sans autorisation, la photo n'a simplement pas de position.
  Future<void> actualiserPosition() {
    final service = positionService;
    if (service == null) return Future.value();
    return _positionEnCours ??= service
        .positionActuelle()
        .then((p) {
          if (p != null) {
            _position = (latitude: p.latitude, longitude: p.longitude);
          }
        })
        .whenComplete(() => _positionEnCours = null);
  }

  /// Garde une photo prise par la caméra, à la fin du brouillon.
  Future<Brouillon> ajouter({
    required Uint8List octets,
    required DateTime priseLe,
  }) {
    final position = _position;
    final resultat = _enchainer(() async {
      final b = await _brouillons.ajouterPhoto(
        octets: octets,
        priseLe: priseLe,
        position: position,
        brouillonId: actif?.id,
      );
      actif = b;
      return b;
    });
    unawaited(actualiserPosition());
    return resultat;
  }

  /// Garde les photos choisies dans la photothèque, avec leur date et leur
  /// position, à la suite de celles du brouillon (les choisies, de la plus
  /// ancienne à la plus récente). `null` si rien n'a été choisi.
  Future<Brouillon?> ajouterImportees(List<PhotoChoisie> photos) {
    final maintenant = _maintenant();
    final triees = [...photos]
      ..sort(
        (a, b) => (a.metadonnees.prisLe ?? maintenant).compareTo(
          b.metadonnees.prisLe ?? maintenant,
        ),
      );
    return _enchainer(() async {
      Brouillon? dernier;
      for (final photo in triees) {
        final m = photo.metadonnees;
        dernier = await _brouillons.ajouterPhoto(
          octets: photo.octets,
          priseLe: m.prisLe ?? maintenant,
          position: m.aUnePosition
              ? (latitude: m.latitude!, longitude: m.longitude!)
              : null,
          brouillonId: actif?.id,
        );
        actif = dernier;
      }
      return dernier;
    });
  }

  /// Retire une photo du brouillon actif : elle va à la corbeille, récupérable
  /// 30 jours. `null` si rien n'a été retiré.
  Future<PhotoCorbeille?> retirer(String photoId) => _enchainer(() async {
    final cible = actif;
    if (cible == null) return null;
    final entree = await _brouillons.supprimerPhoto(cible.id, photoId);
    if (entree == null) return null;
    actif = await _brouillons.charger(cible.id) ?? cible;
    return entree;
  });

  /// Change l'ordre des photos du brouillon ; [ordre] liste exactement
  /// leurs identifiants. `null` si rien n'a changé.
  Future<Brouillon?> reordonner(List<String> ordre) => _enchainer(() async {
    final cible = actif;
    if (cible == null) return null;
    final b = await _brouillons.reordonnerPhotos(cible.id, ordre);
    if (b != null) actif = b;
    return b;
  });

  /// Remet une photo retirée à sa place. `null` si elle n'est plus dans la
  /// corbeille.
  Future<Brouillon?> restaurer(String photoId) => _enchainer(() async {
    final brouillon = await _brouillons.restaurerPhoto(photoId);
    if (brouillon != null && actif?.id == brouillon.id) actif = brouillon;
    return brouillon;
  });

  /// Le brouillon actif, une fois toutes les photos en cours rangées.
  Future<Brouillon?> terminer() async {
    await _file;
    return actif;
  }

  Future<T> _enchainer<T>(Future<T> Function() action) {
    final resultat = _file.then((_) => action());
    _file = resultat.then((_) {}, onError: (_) {});
    return resultat;
  }
}

/// « Continuer · 3 ».
String libelleContinuer(int nombrePhotos) => 'Continuer · $nombrePhotos';

/// Ce que dit le compteur après une photo : « photo gardée » jusqu'à 9,
/// « le maximum publiable » à 10 ; au-delà, combien en retirer pour
/// continuer.
String libelleCompteurPhotos(int nombrePhotos) {
  if (nombrePhotos < nombreMaxPhotosSouvenir) {
    return nombrePhotos > 1 ? 'photos gardées' : 'photo gardée';
  }
  if (nombrePhotos == nombreMaxPhotosSouvenir) {
    return 'photos · le maximum publiable';
  }
  return 'photos · retirez-en ${nombrePhotos - nombreMaxPhotosSouvenir} '
      'pour continuer';
}

/// « Continuer » ne mène à la suite qu'avec dix photos au plus.
bool peutContinuerCamera(int nombrePhotos) =>
    nombrePhotos >= 1 && nombrePhotos <= nombreMaxPhotosSouvenir;

/// Le message d'un « Continuer » refusé : « 10 photos au maximum :
/// retirez-en 3. » ([nombrePhotos] au-delà de 10).
String libelleTropDePhotos(int nombrePhotos) {
  final enTrop = nombrePhotos - nombreMaxPhotosSouvenir;
  return '$nombreMaxPhotosSouvenir photos au maximum : retirez-en $enTrop '
      '(touchez la pile, puis ×).';
}
