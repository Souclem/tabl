import 'dart:typed_data';

import 'package:exif/exif.dart';

/// Ce qu'une photo dit d'elle-même : quand et où elle a été prise. Rien
/// d'autre n'est lu — jamais le contenu de l'image.
class MetadonneesPhoto {
  const MetadonneesPhoto({this.prisLe, this.latitude, this.longitude});

  static const aucune = MetadonneesPhoto();

  /// L'heure de l'appareil au moment de la photo (sans fuseau : celle
  /// qu'il affichait sur place).
  final DateTime? prisLe;
  final double? latitude;
  final double? longitude;

  bool get aUnePosition => latitude != null && longitude != null;
}

/// Une photo choisie pour un souvenir, et ce qu'elle dit d'elle-même.
typedef PhotoChoisie = ({Uint8List octets, MetadonneesPhoto metadonnees});

/// Les photos choisies, avec leurs métadonnées lues toutes ensemble.
Future<List<PhotoChoisie>> lirePhotos(List<Uint8List> photos) async {
  final metadonnees = await Future.wait(photos.map(lireMetadonnees));
  return [
    for (var i = 0; i < photos.length; i++)
      (octets: photos[i], metadonnees: metadonnees[i]),
  ];
}

/// Lit la date et la position d'une photo (EXIF). Une photo sans
/// métadonnées, ou illisible, n'en a simplement pas.
Future<MetadonneesPhoto> lireMetadonnees(Uint8List octets) async {
  final Map<String, IfdTag> tags;
  try {
    tags = await readExifFromBytes(octets);
  } catch (_) {
    return MetadonneesPhoto.aucune;
  }
  final date =
      tags['EXIF DateTimeOriginal'] ??
      tags['EXIF DateTimeDigitized'] ??
      tags['Image DateTime'];
  return MetadonneesPhoto(
    prisLe: date == null ? null : dateExif(date.printable),
    latitude: _coordonnee(tags['GPS GPSLatitude'], tags['GPS GPSLatitudeRef']),
    longitude: _coordonnee(
      tags['GPS GPSLongitude'],
      tags['GPS GPSLongitudeRef'],
    ),
  );
}

double? _coordonnee(IfdTag? valeur, IfdTag? reference) {
  final valeurs = valeur?.values;
  if (valeurs is! IfdRatios) return null;
  return coordonneeExif([
    for (final r in valeurs.ratios) r.toDouble(),
  ], reference?.printable ?? '');
}

/// "2023:11:03 20:41:12" → le 3 novembre 2023 à 20 h 41 ; `null` si le
/// texte n'est pas une date EXIF.
DateTime? dateExif(String texte) {
  final m = RegExp(
    r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
  ).firstMatch(texte.trim());
  if (m == null) return null;
  final parties = [for (var i = 1; i <= 6; i++) int.tryParse(m[i] ?? '0')!];
  // Les appareils écrivent « 0000:00:00 00:00:00 » quand ils ne savent pas.
  if (parties[0] == 0 || parties[1] == 0 || parties[2] == 0) return null;
  return DateTime(
    parties[0],
    parties[1],
    parties[2],
    parties[3],
    parties[4],
    parties[5],
  );
}

/// Degrés, minutes, secondes et hémisphère (« N », « S », « E », « W »)
/// → degrés décimaux, négatifs au sud et à l'ouest.
double? coordonneeExif(List<double> dms, String reference) {
  if (dms.isEmpty || dms.any((v) => v.isNaN || v.isInfinite)) return null;
  final degres =
      dms[0] +
      (dms.length > 1 ? dms[1] / 60 : 0) +
      (dms.length > 2 ? dms[2] / 3600 : 0);
  final signe = switch (reference.trim().toUpperCase()) {
    'S' || 'W' => -1,
    _ => 1,
  };
  return signe * degres;
}
