import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_choix_restaurant.dart';

// Ce que « Ajouter un souvenir » et « Publier » partagent : les photos
// en grand qu'on ajoute, range et retire, et le restaurant proposé
// d'après l'endroit où l'on est — ou celui des photos.

/// Choisit au plus `restant` photos dans la photothèque.
typedef ChoisirPhotos = Future<List<Uint8List>> Function(int restant);

/// Prend une photo avec l'appareil ; `null` : annulé.
typedef PrendrePhoto = Future<Uint8List?> Function();

/// Le sélecteur de photos du téléphone. Les photos sont réduites, mais
/// gardent leur date et leur position (c'est d'elles que part le
/// souvenir).
Future<List<Uint8List>> photosDuTelephone(int restant) async {
  if (restant <= 0) return const [];
  final selecteur = ImagePicker();
  // Le sélecteur multiple refuse une limite de 1.
  final fichiers = restant == 1
      ? [
          ?await selecteur.pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 1600,
          ),
        ]
      : await selecteur.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
          limit: restant,
        );
  return [for (final f in fichiers.take(restant)) await f.readAsBytes()];
}

/// L'appareil photo du téléphone, même réduction que la photothèque.
Future<Uint8List?> photoDeLAppareil() async {
  final fichier = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
    maxWidth: 1600,
  );
  return fichier?.readAsBytes();
}

/// Les photos d'un souvenir ou d'un moment en création, en haut de
/// l'écran : grandes, sans écraser ce qui suit.
double hauteurPhotosCreation(Size ecran) =>
    math.min(ecran.width * 1.12, ecran.height * 0.56);

/// Les photos d'un souvenir ou d'un moment en création : en ajouter,
/// choisir la principale, en retirer, et la zone qui les montre.
mixin EditionPhotos<T extends StatefulWidget> on State<T> {
  /// Celles déjà là à l'ouverture.
  List<PhotoChoisie> get photosInitiales;

  /// La première est la principale.
  late final List<PhotoChoisie> photos = List.of(photosInitiales);

  /// La photo regardée ; `photos.length` : la page d'ajout.
  int page = 0;

  int get placesRestantes => nombreMaxPhotosSouvenir - photos.length;

  /// Des photos viennent d'arriver : ce qu'elles disent (l'endroit, le
  /// jour…) peut compléter le reste. Appelé dans un `setState`.
  void photosAjoutees() {}

  /// Ajoute [octets] après les autres, avec leurs métadonnées. La page ne
  /// bouge pas : sur la page d'ajout, elle montre la première nouvelle.
  Future<void> ajouterPhotos(List<Uint8List> octets) async {
    if (octets.isEmpty || placesRestantes <= 0) return;
    try {
      final nouvelles = await lirePhotos(octets);
      if (!mounted) return;
      setState(() {
        photos.addAll(nouvelles.take(placesRestantes));
        photosAjoutees();
      });
    } catch (e) {
      debugPrint('EditionPhotos: $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  void rendrePrincipale() {
    if (page == 0 || page >= photos.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      photos.insert(0, photos.removeAt(page));
      page = 0;
    });
  }

  void retirerPhoto() {
    if (page >= photos.length) return;
    setState(() {
      photos.removeAt(page);
      page = math.min(page, math.max(photos.length - 1, 0));
    });
  }

  /// Les photos en grand, leurs vignettes, et la page d'ajout avec
  /// [actions] tant qu'il reste de la place.
  Widget zonePhotos(
    BuildContext context, {
    required List<ActionAjoutPhoto> actions,
    String? titreAjout,
  }) {
    return TablZonePhotos(
      photos: [for (final p in photos) p.octets],
      page: page,
      hauteur: hauteurPhotosCreation(MediaQuery.sizeOf(context)),
      onPage: (p) => setState(() => page = p),
      onRendrePrincipale: rendrePrincipale,
      onRetirer: retirerPhoto,
      actionsAjout: placesRestantes > 0 ? actions : const [],
      titreAjout: titreAjout,
    );
  }
}

/// Le restaurant d'un souvenir ou d'un moment en création : le plus
/// proche des [endroits] — ceux des photos, ou là où l'on est —, proposé
/// d'office et modifiable d'un tap. Jamais par-dessus un choix de
/// l'utilisateur.
mixin PropositionLieu<T extends StatefulWidget> on State<T> {
  /// `null` : ni proposition, ni recherche (saisie à la main).
  RechercheLieuService? get rechercheLieuService;
  PositionService? get positionService;

  /// Où chercher, le principal d'abord.
  List<Coordonnees> endroits = const [];

  /// D'où se mesure la distance aux [endroits].
  RepereDistance repere = RepereDistance.photo;

  /// Les restaurants autour de chacun des [endroits], du plus proche au
  /// plus loin.
  List<List<LieuRestaurant>> prochesParEndroit = const [];
  bool rechercheProches = false;

  LieuRestaurant? lieu;

  /// [lieu] a été choisi (par l'utilisateur, ou avant d'ouvrir) : une
  /// proposition ne le remplace plus.
  bool lieuChoisi = false;

  /// Sous le nom du restaurant : "Végétarien · Liège · à 40 m de vous",
  /// ou où en est la recherche.
  String? get detailLieu {
    final choisi = lieu;
    if (choisi == null) {
      return rechercheProches ? 'Recherche du restaurant…' : null;
    }
    return detailLieuSouvenir(
      choisi,
      repere: endroits.isNotEmpty && choisi.distanceM != null ? repere : null,
    );
  }

  /// Cherche les restaurants autour de [nouveaux] endroits ; le plus
  /// proche du premier est proposé, si rien n'a été choisi.
  Future<void> chercherAutour(
    List<Coordonnees> nouveaux, {
    required RepereDistance repere,
  }) async {
    endroits = nouveaux;
    this.repere = repere;
    final service = rechercheLieuService;
    if (service == null || nouveaux.isEmpty) return;
    // Souvent appelé pendant une construction : l'état ne change
    // qu'après.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => rechercheProches = true);
    try {
      final proches = await Future.wait([
        for (var i = 0; i < nouveaux.length; i++)
          service.lieuxProches(
            latitude: nouveaux[i].latitude,
            longitude: nouveaux[i].longitude,
            limite: i == 0 ? 8 : 4,
          ),
      ]);
      // D'autres endroits ont été demandés entre-temps.
      if (!mounted || !identical(endroits, nouveaux)) return;
      setState(() {
        prochesParEndroit = proches;
        final propose = proches.first.firstOrNull;
        if (!lieuChoisi && propose != null) lieu = propose;
      });
    } catch (e) {
      debugPrint('PropositionLieu: lieux proches : $e');
    } finally {
      if (mounted) setState(() => rechercheProches = false);
    }
  }

  /// « Quel restaurant ? » : la liste autour des [endroits], la carte,
  /// la recherche, la saisie à la main.
  Future<void> changerLieu() async {
    final choisi = await choisirRestaurant(
      context,
      rechercheLieuService: rechercheLieuService,
      positionService: positionService,
      endroits: endroits,
      prochesParEndroit: prochesParEndroit,
      repere: repere,
      choisi: lieu,
    );
    if (choisi == null || !mounted) return;
    setState(() {
      lieu = choisi.estManuel ? completerLieuManuel(choisi) : choisi;
      lieuChoisi = true;
    });
  }

  /// Un restaurant saisi à la main, tel qu'il sera gardé. Sans position
  /// par défaut : celle du téléphone le placerait au mauvais endroit sur
  /// la carte, si l'on n'y est plus.
  LieuRestaurant completerLieuManuel(LieuRestaurant lieu) => lieu;
}
