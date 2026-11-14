import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'emotion.dart';
import 'presentation_finalisation.dart';

/// Une photo supprimée reste récupérable aussi longtemps.
const dureeCorbeilleBrouillon = Duration(days: 30);

/// Un endroit où une photo a été prise.
typedef PositionPrise = ({double latitude, double longitude});

/// Une photo d'un brouillon : son fichier vit sur le téléphone, dans le
/// dossier du brouillon (voir [BrouillonsLocaux.fichierPhoto]).
class PhotoBrouillon {
  const PhotoBrouillon({
    required this.id,
    required this.priseLe,
    this.position,
  });

  /// Nom du fichier, sans extension.
  final String id;

  /// L'heure de la prise (celle de la caméra, ou lue dans la photo importée).
  final DateTime priseLe;
  final PositionPrise? position;
}

/// Un moment en cours de création, gardé sur le téléphone — jamais en base —
/// jusqu'à sa publication. La première photo est la couverture.
class Brouillon {
  const Brouillon({
    required this.id,
    required this.creeLe,
    required this.modifieLe,
    required this.priseLe,
    this.position,
    this.photos = const [],
    this.lieu,
    this.legende,
    this.emotion,
    this.etoiles = const {},
    this.avecQuiIds = const {},
    this.audience = AudienceSouvenir.toutLeMonde,
  });

  final String id;
  final DateTime creeLe;
  final DateTime modifieLe;

  /// L'heure du repas : celle de la plus ancienne photo ajoutée, ou de la
  /// création d'un brouillon sans photo. Modifiable.
  final DateTime priseLe;

  /// Où l'on était à la première prise qui le savait.
  final PositionPrise? position;

  /// Dans l'ordre de publication.
  final List<PhotoBrouillon> photos;

  /// Le lieu choisi.
  final LieuRestaurant? lieu;
  final String? legende;
  final Emotion? emotion;

  /// Les notes facultatives, de 1 à 5, par catégorie (`cuisine`,
  /// `ambiance`…). Une catégorie sans note est absente.
  final Map<String, int> etoiles;
  final Set<String> avecQuiIds;
  final AudienceSouvenir audience;

  /// Le même brouillon, avec les champs donnés. Un champ qui peut être vide
  /// se donne par une fonction (`lieu: () => null` pour l'effacer).
  Brouillon copieAvec({
    DateTime? modifieLe,
    DateTime? priseLe,
    ValueGetter<PositionPrise?>? position,
    List<PhotoBrouillon>? photos,
    ValueGetter<LieuRestaurant?>? lieu,
    ValueGetter<String?>? legende,
    ValueGetter<Emotion?>? emotion,
    Map<String, int>? etoiles,
    Set<String>? avecQuiIds,
    AudienceSouvenir? audience,
  }) => Brouillon(
    id: id,
    creeLe: creeLe,
    modifieLe: modifieLe ?? this.modifieLe,
    priseLe: priseLe ?? this.priseLe,
    position: position != null ? position() : this.position,
    photos: photos ?? this.photos,
    lieu: lieu != null ? lieu() : this.lieu,
    legende: legende != null ? legende() : this.legende,
    emotion: emotion != null ? emotion() : this.emotion,
    etoiles: etoiles ?? this.etoiles,
    avecQuiIds: avecQuiIds ?? this.avecQuiIds,
    audience: audience ?? this.audience,
  );

  Map<String, Object?> versJson() => {
    'version': 1,
    'id': id,
    'creeLe': creeLe.toIso8601String(),
    'modifieLe': modifieLe.toIso8601String(),
    'priseLe': priseLe.toIso8601String(),
    'position': _positionVersJson(position),
    'photos': [
      for (final p in photos)
        {
          'id': p.id,
          'priseLe': p.priseLe.toIso8601String(),
          'position': _positionVersJson(p.position),
        },
    ],
    'lieu': lieu == null ? null : _lieuVersJson(lieu!),
    'legende': legende,
    'emotion': emotion?.emoji,
    'etoiles': etoiles,
    'avecQuiIds': avecQuiIds.toList()..sort(),
    'audience': {
      'mode': audience.mode.valeur,
      'tableIds': audience.tableIds.toList()..sort(),
      'personneIds': audience.personneIds.toList()..sort(),
    },
  };

  /// Relit un brouillon écrit par [versJson]. Lève une erreur si le JSON
  /// n'en est pas un.
  static Brouillon depuisJson(Map<String, dynamic> json) {
    final etoiles = <String, int>{};
    for (final e in ((json['etoiles'] as Map?) ?? const {}).entries) {
      final note = e.value;
      // Un plat écrit garde sa place même sans note (0).
      final minimum = estClePlat(e.key as String) ? 0 : 1;
      if (note is int && note >= minimum && note <= 5) {
        etoiles[e.key as String] = note;
      }
    }
    final audience = (json['audience'] as Map?)?.cast<String, dynamic>();
    return Brouillon(
      id: json['id'] as String,
      creeLe: DateTime.parse(json['creeLe'] as String),
      modifieLe: DateTime.parse(json['modifieLe'] as String),
      priseLe: DateTime.parse(json['priseLe'] as String),
      position: _positionDepuisJson(json['position']),
      photos: [
        for (final p in json['photos'] as List)
          PhotoBrouillon(
            id: (p as Map)['id'] as String,
            priseLe: DateTime.parse(p['priseLe'] as String),
            position: _positionDepuisJson(p['position']),
          ),
      ],
      lieu: json['lieu'] == null
          ? null
          : _lieuDepuisJson((json['lieu'] as Map).cast<String, dynamic>()),
      legende: json['legende'] as String?,
      emotion: Emotion.depuisEmoji(json['emotion'] as String?),
      etoiles: etoiles,
      avecQuiIds: {
        ...((json['avecQuiIds'] as List?) ?? const []).cast<String>(),
      },
      audience: audience == null
          ? AudienceSouvenir.toutLeMonde
          : AudienceSouvenir(
              mode: ModeAudience.depuisValeur(audience['mode'] as String?),
              tableIds: {
                ...((audience['tableIds'] as List?) ?? const []).cast<String>(),
              },
              personneIds: {
                ...((audience['personneIds'] as List?) ?? const [])
                    .cast<String>(),
              },
            ),
    );
  }
}

/// Une photo supprimée d'un brouillon, encore récupérable.
class PhotoCorbeille {
  const PhotoCorbeille({
    required this.photo,
    required this.brouillonId,
    required this.rang,
    required this.supprimeeLe,
  });

  final PhotoBrouillon photo;

  /// Le brouillon dont elle vient, et la place qu'elle y avait.
  final String brouillonId;
  final int rang;
  final DateTime supprimeeLe;

  /// Quand elle disparaît pour de bon.
  DateTime get expireLe => supprimeeLe.add(dureeCorbeilleBrouillon);
}

/// Les brouillons, sur le téléphone : un dossier par brouillon (son
/// `brouillon.json` et ses photos en fichiers), plus une corbeille où une
/// photo supprimée reste 30 jours. Chaque capture et chaque modification est
/// écrite aussitôt ; les écritures sont mises en file, donc plusieurs
/// captures rapprochées ne se marchent pas dessus.
class BrouillonsLocaux {
  BrouillonsLocaux(
    this._racine, {
    DateTime Function()? maintenant,
    String Function()? genererId,
  }) : _maintenant = maintenant ?? DateTime.now,
       _genererId = genererId ?? (() => const Uuid().v4());

  /// Les brouillons du téléphone, dans le dossier de l'app ; purge la
  /// corbeille échue.
  static Future<BrouillonsLocaux> ouvrir() async {
    final dossier = await getApplicationSupportDirectory();
    final brouillons = BrouillonsLocaux(Directory('${dossier.path}/tabl'));
    await brouillons.purgerCorbeille();
    return brouillons;
  }

  final Directory _racine;

  /// Le dossier des données locales de l'app : brouillons, corbeille, et la
  /// file d'envoi (voir [FileEnvoi]).
  Directory get racine => _racine;

  final DateTime Function() _maintenant;
  final String Function() _genererId;

  Future<void> _file = Future.value();

  Directory get _dossierBrouillons => Directory('${_racine.path}/brouillons');
  Directory get _dossierCorbeille => Directory('${_racine.path}/corbeille');
  Directory _dossier(String id) => Directory('${_dossierBrouillons.path}/$id');
  File _fichierJson(String id) => File('${_dossier(id).path}/brouillon.json');

  /// Le fichier d'une photo, à afficher (`Image.file`) ou à envoyer.
  File fichierPhoto(String brouillonId, String photoId) =>
      File('${_dossier(brouillonId).path}/$photoId.jpg');

  /// La photo à afficher, lue depuis son fichier.
  ImageProvider imagePhoto(String brouillonId, String photoId) =>
      FileImage(fichierPhoto(brouillonId, photoId));

  /// Le contenu d'une photo, à envoyer.
  Future<Uint8List> octetsPhoto(String brouillonId, String photoId) =>
      fichierPhoto(brouillonId, photoId).readAsBytes();

  File _photoCorbeille(String photoId) =>
      File('${_dossierCorbeille.path}/$photoId.jpg');
  File _jsonCorbeille(String photoId) =>
      File('${_dossierCorbeille.path}/$photoId.json');

  Future<T> _enchainer<T>(Future<T> Function() action) {
    final resultat = _file.then((_) => action());
    _file = resultat.then((_) {}, onError: (_) {});
    return resultat;
  }

  /// Les brouillons, le plus récemment modifié d'abord.
  /// Un brouillon illisible est ignoré.
  Future<List<Brouillon>> lister() => _enchainer(_lister);

  Future<Brouillon?> charger(String id) => _enchainer(() => _lire(id));

  /// Un brouillon sans photo (« Sans photo »), prêt à l'heure donnée —
  /// maintenant par défaut.
  Future<Brouillon> creer({DateTime? priseLe}) => _enchainer(() async {
    final maintenant = _maintenant();
    final brouillon = Brouillon(
      id: _genererId(),
      creeLe: maintenant,
      modifieLe: maintenant,
      priseLe: priseLe ?? maintenant,
    );
    await _ecrire(brouillon);
    return brouillon;
  });

  /// Garde une photo à la fin du brouillon [brouillonId] ; sans lui (ou
  /// s'il n'existe plus), dans un nouveau brouillon. Les photos d'un
  /// brouillon s'ajoutent toujours les unes aux autres, quelle que soit leur
  /// date : c'est l'auteur qui choisit le brouillon (voir
  /// `brouillonsAReprendre`).
  Future<Brouillon> ajouterPhoto({
    required Uint8List octets,
    required DateTime priseLe,
    PositionPrise? position,
    String? brouillonId,
  }) => _enchainer(() async {
    final cible = brouillonId == null ? null : await _lire(brouillonId);
    final maintenant = _maintenant();
    final base =
        cible ??
        Brouillon(
          id: brouillonId ?? _genererId(),
          creeLe: maintenant,
          modifieLe: maintenant,
          priseLe: priseLe,
        );
    final photo = PhotoBrouillon(
      id: _genererId(),
      priseLe: priseLe,
      position: position,
    );
    await _dossier(base.id).create(recursive: true);
    await fichierPhoto(base.id, photo.id).writeAsBytes(octets, flush: true);
    final misAJour = base.copieAvec(
      modifieLe: maintenant,
      priseLe: priseLe.isBefore(base.priseLe) ? priseLe : null,
      position: base.position == null && position != null
          ? () => position
          : null,
      photos: [...base.photos, photo],
    );
    await _ecrire(misAJour);
    return misAJour;
  });

  /// Modifie les champs du brouillon (légende, lieu, émotion…) et l'écrit.
  /// Les photos et leur ordre ne passent pas par là : voir [ajouterPhoto],
  /// [supprimerPhoto] et [reordonnerPhotos]. `null` si le brouillon n'existe
  /// plus.
  Future<Brouillon?> mettreAJour(
    String id,
    Brouillon Function(Brouillon actuel) transformation,
  ) => _enchainer(() async {
    final actuel = await _lire(id);
    if (actuel == null) return null;
    final misAJour = transformation(
      actuel,
    ).copieAvec(modifieLe: _maintenant(), photos: actuel.photos);
    await _ecrire(misAJour);
    return misAJour;
  });

  /// Change l'ordre des photos ; [ordre] liste exactement leurs identifiants.
  Future<Brouillon?> reordonnerPhotos(String id, List<String> ordre) =>
      _enchainer(() async {
        final actuel = await _lire(id);
        if (actuel == null) return null;
        final parId = {for (final p in actuel.photos) p.id: p};
        if (ordre.length != parId.length || !ordre.every(parId.containsKey)) {
          throw ArgumentError(
            'L\'ordre doit contenir chaque photo du brouillon, une fois.',
          );
        }
        final misAJour = actuel.copieAvec(
          modifieLe: _maintenant(),
          photos: [for (final photoId in ordre) parId[photoId]!],
        );
        await _ecrire(misAJour);
        return misAJour;
      });

  /// Retire une photo du brouillon : elle va à la corbeille, récupérable
  /// 30 jours. `null` si le brouillon ou la photo n'existe pas.
  Future<PhotoCorbeille?> supprimerPhoto(String id, String photoId) =>
      _enchainer(() async {
        final actuel = await _lire(id);
        if (actuel == null) return null;
        final rang = actuel.photos.indexWhere((p) => p.id == photoId);
        if (rang < 0) return null;
        final photo = actuel.photos[rang];
        final maintenant = _maintenant();
        final entree = PhotoCorbeille(
          photo: photo,
          brouillonId: id,
          rang: rang,
          supprimeeLe: maintenant,
        );
        await _dossierCorbeille.create(recursive: true);
        await fichierPhoto(id, photoId).rename(_photoCorbeille(photoId).path);
        await ecrireJsonAtomique(
          _jsonCorbeille(photoId),
          _corbeilleVersJson(entree),
        );
        await _ecrire(
          actuel.copieAvec(
            modifieLe: maintenant,
            photos: [...actuel.photos]..removeAt(rang),
          ),
        );
        return entree;
      });

  /// Les photos supprimées, encore récupérables, la plus récente d'abord.
  Future<List<PhotoCorbeille>> listerCorbeille() =>
      _enchainer(_listerCorbeille);

  /// Remet une photo de la corbeille à sa place dans son brouillon — ou
  /// dans un nouveau brouillon si celui-ci n'existe plus. `null` si la photo
  /// n'est plus dans la corbeille.
  Future<Brouillon?> restaurerPhoto(String photoId) => _enchainer(() async {
    final entree = await _lireCorbeille(photoId);
    if (entree == null || !await _photoCorbeille(photoId).exists()) {
      return null;
    }
    final maintenant = _maintenant();
    final existant = await _lire(entree.brouillonId);
    final base =
        existant ??
        Brouillon(
          id: _genererId(),
          creeLe: maintenant,
          modifieLe: maintenant,
          priseLe: entree.photo.priseLe,
          position: entree.photo.position,
        );
    await _dossier(base.id).create(recursive: true);
    await _photoCorbeille(photoId).rename(fichierPhoto(base.id, photoId).path);
    await _jsonCorbeille(photoId).delete();
    final photos = [...base.photos];
    photos.insert(entree.rang.clamp(0, photos.length), entree.photo);
    final misAJour = base.copieAvec(modifieLe: maintenant, photos: photos);
    await _ecrire(misAJour);
    return misAJour;
  });

  /// Efface pour de bon les photos supprimées depuis 30 jours ou plus.
  /// Renvoie leur nombre.
  Future<int> purgerCorbeille() => _enchainer(() async {
    final limite = _maintenant().subtract(dureeCorbeilleBrouillon);
    var purgees = 0;
    for (final entree in await _listerCorbeille()) {
      if (entree.supprimeeLe.isAfter(limite)) continue;
      await _supprimerSiExiste(_photoCorbeille(entree.photo.id));
      await _supprimerSiExiste(_jsonCorbeille(entree.photo.id));
      purgees++;
    }
    return purgees;
  });

  /// Efface un brouillon et ses photos, sans corbeille : à la publication,
  /// ou quand on l'abandonne.
  Future<void> supprimerBrouillon(String id) => _enchainer(() async {
    final dossier = _dossier(id);
    if (await dossier.exists()) await dossier.delete(recursive: true);
  });

  Future<List<Brouillon>> _lister() async {
    if (!await _dossierBrouillons.exists()) return [];
    final brouillons = <Brouillon>[];
    await for (final entree in _dossierBrouillons.list()) {
      if (entree is! Directory) continue;
      final brouillon = await _lire(
        entree.uri.pathSegments.lastWhere((s) => s.isNotEmpty),
      );
      if (brouillon != null) brouillons.add(brouillon);
    }
    brouillons.sort((a, b) => b.modifieLe.compareTo(a.modifieLe));
    return brouillons;
  }

  Future<Brouillon?> _lire(String id) async {
    final json = await lireJson(_fichierJson(id));
    if (json == null) return null;
    try {
      return Brouillon.depuisJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ecrire(Brouillon brouillon) =>
      ecrireJsonAtomique(_fichierJson(brouillon.id), brouillon.versJson());

  Future<List<PhotoCorbeille>> _listerCorbeille() async {
    if (!await _dossierCorbeille.exists()) return [];
    final entrees = <PhotoCorbeille>[];
    await for (final fichier in _dossierCorbeille.list()) {
      if (fichier is! File || !fichier.path.endsWith('.json')) continue;
      final nom = fichier.uri.pathSegments.last;
      final entree = await _lireCorbeille(
        nom.substring(0, nom.length - '.json'.length),
      );
      if (entree != null) entrees.add(entree);
    }
    entrees.sort((a, b) => b.supprimeeLe.compareTo(a.supprimeeLe));
    return entrees;
  }

  Future<PhotoCorbeille?> _lireCorbeille(String photoId) async {
    final json = await lireJson(_jsonCorbeille(photoId));
    if (json == null) return null;
    try {
      return PhotoCorbeille(
        photo: PhotoBrouillon(
          id: json['id'] as String,
          priseLe: DateTime.parse(json['priseLe'] as String),
          position: _positionDepuisJson(json['position']),
        ),
        brouillonId: json['brouillonId'] as String,
        rang: json['rang'] as int,
        supprimeeLe: DateTime.parse(json['supprimeeLe'] as String),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _corbeilleVersJson(PhotoCorbeille e) => {
    'id': e.photo.id,
    'priseLe': e.photo.priseLe.toIso8601String(),
    'position': _positionVersJson(e.photo.position),
    'brouillonId': e.brouillonId,
    'rang': e.rang,
    'supprimeeLe': e.supprimeeLe.toIso8601String(),
  };
}

/// Écrit dans un fichier voisin puis le renomme : une coupure en pleine
/// écriture ne laisse jamais un JSON à moitié écrit.
Future<void> ecrireJsonAtomique(File fichier, Map<String, Object?> json) async {
  await fichier.parent.create(recursive: true);
  final provisoire = File('${fichier.path}.tmp');
  await provisoire.writeAsString(jsonEncode(json), flush: true);
  await provisoire.rename(fichier.path);
}

Future<Map<String, dynamic>?> lireJson(File fichier) async {
  try {
    final lu = jsonDecode(await fichier.readAsString());
    return lu is Map<String, dynamic> ? lu : null;
  } on FileSystemException {
    return null;
  } on FormatException {
    return null;
  }
}

Future<void> _supprimerSiExiste(File fichier) async {
  if (await fichier.exists()) await fichier.delete();
}

Map<String, double>? _positionVersJson(PositionPrise? p) =>
    p == null ? null : {'latitude': p.latitude, 'longitude': p.longitude};

PositionPrise? _positionDepuisJson(Object? json) {
  if (json is! Map) return null;
  final latitude = json['latitude'], longitude = json['longitude'];
  if (latitude is! num || longitude is! num) return null;
  return (latitude: latitude.toDouble(), longitude: longitude.toDouble());
}

Map<String, Object?> _lieuVersJson(LieuRestaurant l) => {
  'nom': l.nom,
  'ville': l.ville,
  'restaurantId': l.restaurantId,
  'fsqPlaceId': l.fsqPlaceId,
  'adresse': l.adresse,
  'latitude': l.latitude,
  'longitude': l.longitude,
  'categories': l.categories,
  'genre': l.genre.name,
  'hoteId': l.hoteId,
  'hotePseudo': l.hotePseudo,
  'hotePhotoUrl': l.hotePhotoUrl,
};

LieuRestaurant _lieuDepuisJson(Map<String, dynamic> json) {
  // Avant les genres, un simple drapeau : un lieu personnel est « chez ».
  final genre =
      GenreLieu.values.where((g) => g.name == json['genre']).firstOrNull ??
      (json['personnel'] == true ? GenreLieu.chez : GenreLieu.restaurant);
  if (genre != GenreLieu.restaurant) {
    // Jamais de position hors restaurant, même lue d'un vieux brouillon.
    return LieuRestaurant.personnel(
      nom: json['nom'] as String,
      restaurantId: json['restaurantId'] as String?,
      genre: genre,
      hoteId: json['hoteId'] as String?,
      hotePseudo: json['hotePseudo'] as String?,
      hotePhotoUrl: json['hotePhotoUrl'] as String?,
    );
  }
  return LieuRestaurant(
    nom: json['nom'] as String,
    ville: json['ville'] as String,
    restaurantId: json['restaurantId'] as String?,
    fsqPlaceId: json['fsqPlaceId'] as String?,
    adresse: json['adresse'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    categories: [...((json['categories'] as List?) ?? const []).cast<String>()],
  );
}
