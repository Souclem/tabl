import 'dart:async';
import 'dart:typed_data';

import '../position/position_service.dart';
import 'brouillon_local.dart';
import 'metadonnees_photo.dart';
import 'nouveau_souvenir.dart';
import 'precompletion_souvenir.dart';

/// Revenir sur un brouillon après au moins ce délai : la caméra propose
/// de le reprendre.
const delaiCarteReprise = Duration(minutes: 10);

/// Ce que l'écran caméra trouve à son ouverture.
class OuvertureCamera {
  const OuvertureCamera({this.actif, this.aRejoindre, this.reprise = false});

  static const vide = OuvertureCamera();

  /// Le brouillon que les prochaines photos rejoignent (moins de 3 h après
  /// sa dernière photo).
  final Brouillon? actif;

  /// Un brouillon plus ancien (3 h ou plus) : les prochaines photos
  /// commencent un nouveau repas, sauf si l'on dit que c'en est la suite.
  final Brouillon? aRejoindre;

  /// Le retour se fait après 10 min ou plus sur [actif] : carte de reprise.
  final bool reprise;
}

/// Ce que la caméra propose d'après les [brouillons] du téléphone : seuls
/// ceux qui ont des photos comptent, le plus récemment modifié d'abord.
OuvertureCamera ouvertureCamera(
  List<Brouillon> brouillons,
  DateTime maintenant,
) {
  Brouillon? recent;
  for (final b in brouillons) {
    if (b.photos.isEmpty) continue;
    if (recent == null || b.modifieLe.isAfter(recent.modifieLe)) recent = b;
  }
  if (recent == null) return OuvertureCamera.vide;
  if (!recent.accueille(maintenant)) return OuvertureCamera(aRejoindre: recent);
  return OuvertureCamera(
    actif: recent,
    reprise: maintenant.difference(recent.modifieLe) >= delaiCarteReprise,
  );
}

/// Une séance sur l'écran caméra : vers quel brouillon vont les photos
/// prises ou importées. Les ajouts se font l'un après l'autre, donc des
/// déclenchements rapprochés se rangent dans le même brouillon.
class SessionCamera {
  SessionCamera(
    this._brouillons, {
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

  /// Le brouillon qui reçoit la prochaine photo ; `null` : un nouveau repas.
  Brouillon? actif;

  /// Voir [OuvertureCamera.aRejoindre].
  Brouillon? aRejoindre;

  /// Lit les brouillons du téléphone et choisit celui qui reçoit les
  /// prochaines photos.
  Future<OuvertureCamera> ouvrir() async {
    final ouverture = ouvertureCamera(
      await _brouillons.lister(),
      _maintenant(),
    );
    actif = ouverture.actif;
    aRejoindre = ouverture.aRejoindre;
    unawaited(actualiserPosition());
    return ouverture;
  }

  /// « Autre repas » : les prochaines photos commencent un nouveau brouillon.
  void autreRepas() => actif = null;

  /// « C'est la suite de … » : les prochaines photos rejoignent le repas
  /// plus ancien.
  void rejoindre() {
    actif = aRejoindre ?? actif;
    aRejoindre = null;
  }

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

  /// Garde une photo prise par la caméra, dans le brouillon actif — ou un
  /// nouveau si c'est un autre repas.
  Future<Brouillon> ajouter({
    required Uint8List octets,
    required DateTime priseLe,
  }) {
    final position = _position;
    final resultat = _enchainer(() async {
      final cible = actif;
      final b = await _brouillons.ajouterPhoto(
        octets: octets,
        priseLe: priseLe,
        position: position,
        brouillonId: cible?.id,
        nouveauRepas: cible == null,
      );
      actif = b;
      aRejoindre = null;
      return b;
    });
    unawaited(actualiserPosition());
    return resultat;
  }

  /// Garde les photos choisies dans la photothèque, avec leur date et leur
  /// position, la plus ancienne d'abord. Chacune rejoint le brouillon actif
  /// si elle date de moins de 3 h de sa dernière photo, sinon un nouveau
  /// repas commence. `null` si rien n'a été choisi.
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
        final priseLe = m.prisLe ?? maintenant;
        final cible = actif;
        final suite = cible != null && cible.accueille(priseLe) ? cible : null;
        dernier = await _brouillons.ajouterPhoto(
          octets: photo.octets,
          priseLe: priseLe,
          position: m.aUnePosition
              ? (latitude: m.latitude!, longitude: m.longitude!)
              : null,
          brouillonId: suite?.id,
          nouveauRepas: suite == null,
        );
        actif = dernier;
        aRejoindre = null;
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

/// « Suite du repas de 12 h 30 » : le brouillon actif accueille la photo.
String libelleSuiteDuRepas(Brouillon brouillon) =>
    'Suite du repas de ${heureLisible(brouillon.priseLe)}';

/// « C'est la suite de 12 h 30 » : le repas plus ancien, à rejoindre.
String libelleRepasARejoindre(Brouillon brouillon) =>
    "C'est la suite de ${heureLisible(brouillon.priseLe)}";

/// Le lieu du brouillon, ou « Repas en cours » tant qu'il n'est pas choisi.
String titreReprise(Brouillon brouillon) =>
    brouillon.lieu?.nom ?? 'Repas en cours';

/// « Votre moment de 12 h 30 · 3 photos ».
String detailReprise(Brouillon brouillon) {
  final n = brouillon.photos.length;
  return 'Votre moment de ${heureLisible(brouillon.priseLe)} · '
      '$n photo${n > 1 ? 's' : ''}';
}

/// « Continuer · 3 ».
String libelleContinuer(int nombrePhotos) => 'Continuer · $nombrePhotos';

/// Ce que dit le compteur après une photo : « photo gardée » jusqu'à 9,
/// « le maximum publiable » à 10, au-delà on prévient du plafond.
String libelleCompteurPhotos(int nombrePhotos) {
  if (nombrePhotos < nombreMaxPhotosSouvenir) {
    return nombrePhotos > 1 ? 'photos gardées' : 'photo gardée';
  }
  if (nombrePhotos == nombreMaxPhotosSouvenir) {
    return 'photos · le maximum publiable';
  }
  return 'photos · vous en publierez $nombreMaxPhotosSouvenir';
}
