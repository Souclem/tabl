import 'dart:typed_data';

import '../restaurants/lieu_restaurant.dart';
import 'audience_souvenir.dart';
import 'date_souvenir.dart';
import 'emotion.dart';

/// Au plus, par souvenir : la principale et 9 autres.
const nombreMaxPhotosSouvenir = 10;

/// Un repas passé à ajouter à son profil : toujours au moins une photo
/// (pas de souvenir sans photo), un lieu et une date ; le reste est
/// facultatif.
class NouveauSouvenir {
  const NouveauSouvenir({
    required this.lieu,
    required this.date,
    this.photos = const [],
    this.emotion,
    this.legende,
    this.moment,
    this.audience = AudienceSouvenir.toutLeMonde,
  }) : assert(photos.length >= 1 && photos.length <= nombreMaxPhotosSouvenir);

  final LieuRestaurant lieu;
  final DateSouvenir date;

  /// La première est la principale.
  final List<Uint8List> photos;
  final Emotion? emotion;
  final String? legende;

  /// `'midi'` ou `'soir'`.
  final String? moment;
  final AudienceSouvenir audience;
}
