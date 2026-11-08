import 'dart:convert';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

/// Une photo JPEG de 8 × 8 pixels prise le 3 novembre 2023 à 20 h 41,
/// par 50,64735° N et 5,58045° O.
final _photoExif = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QESRXhpZgAATU0AKgAAAAgAAwEyAAIAAAAUAAAAMo'
  'dpAAQAAAABAAAARoglAAQAAAABAAAApAAAAAAyMDIzOjExOjAzIDIwOjQxOjEyAAAEkAMA'
  'AgAAABQAAAB8kAQAAgAAABQAAACQoAIABAAAAAEAAAAIoAMABAAAAAEAAAAIAAAAADIwMj'
  'M6MTE6MDMgMjA6NDE6MTIAMjAyMzoxMTowMyAyMDo0MToxMgAABAABAAIAAAACTgAAAAAC'
  'AAUAAAADAAAA2gADAAIAAAACVwAAAAAEAAUAAAADAAAA8gAAAAAAAAAyAAAAAQAAACYAAA'
  'ABAAATtgAAAGQAAAAFAAAAAQAAACIAAAABAAATYgAAAGT/7QA4UGhvdG9zaG9wIDMuMAA4'
  'QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgACAAIAwEiAA'
  'IRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMF'
  'BQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJS'
  'YnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqS'
  'k5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6O'
  'nq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIB'
  'AgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJD'
  'ThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKD'
  'hIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2u'
  'Lj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMFBgUFBQUGCAYGBgYGCAoI'
  'CAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQ'
  'sQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/d'
  'AAQAAf/aAAwDAQACEQMRAD8A8k8c+Bt3mRyR89jjrXlH/Cvv+mdfV/jz/WN9f615lX4phc'
  'VPkWp+54rB0+d6H//Z',
);

/// Une image PNG de 1 × 1 pixel, sans métadonnées.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Un segment EXIF petit-boutiste : l'orientation [orientation] et une
/// position (hémisphère nord).
List<int> _exifOrientationEtPosition(int orientation) {
  final tiff = [
    0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, // II, 42, IFD0 en 8
    0x02, 0x00, // IFD0 : 2 entrées
    0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, orientation, 0, 0, 0,
    0x25, 0x88, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00, 38, 0, 0, 0, // GPS en 38
    0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, // GPS : 1 entrée, GPSLatitudeRef = « N »
    0x01, 0x00, 0x02, 0x00, 0x02, 0x00, 0x00, 0x00, 0x4E, 0, 0, 0,
    0x00, 0x00, 0x00, 0x00,
  ];
  final contenu = [...'Exif'.codeUnits, 0, 0, ...tiff];
  final longueur = contenu.length + 2;
  return [0xFF, 0xE1, longueur >> 8, longueur & 0xFF, ...contenu];
}

/// La position du premier [marqueur] JPEG (0xFF, marqueur).
int _marqueur(Uint8List jpeg, int marqueur) {
  for (var i = 0; i + 1 < jpeg.length; i++) {
    if (jpeg[i] == 0xFF && jpeg[i + 1] == marqueur) return i;
  }
  return -1;
}

void main() {
  test('la date et la position d\'une vraie photo', () async {
    final m = await lireMetadonnees(_photoExif);

    expect(m.prisLe, DateTime(2023, 11, 3, 20, 41, 12));
    expect(m.latitude, closeTo(50.64735, 1e-6));
    expect(m.longitude, closeTo(-5.58045, 1e-6));
    expect(m.aUnePosition, isTrue);
    // La même photo, relue : la même empreinte.
    expect(m.empreinte, hasLength(32));
    expect((await lireMetadonnees(_photoExif)).empreinte, m.empreinte);
  });

  test('une image sans métadonnées n\'en a simplement pas', () async {
    final m = await lireMetadonnees(_png);

    expect(m.prisLe, isNull);
    expect(m.aUnePosition, isFalse);
  });

  test('les dates EXIF, y compris celles qui n\'en sont pas', () {
    expect(dateExif('2023:11:03 20:41:12'), DateTime(2023, 11, 3, 20, 41, 12));
    expect(dateExif('2023:11:03 20:41'), DateTime(2023, 11, 3, 20, 41));
    expect(dateExif('0000:00:00 00:00:00'), isNull);
    expect(dateExif('hier soir'), isNull);
  });

  test('degrés, minutes, secondes et hémisphère', () {
    expect(coordonneeExif([50, 38, 50.46], 'N'), closeTo(50.64735, 1e-6));
    expect(coordonneeExif([5, 34, 49.62], 'W'), closeTo(-5.58045, 1e-6));
    expect(coordonneeExif([33, 52, 0], 'S'), closeTo(-33.866667, 1e-6));
    expect(coordonneeExif([], 'N'), isNull);
  });

  test('envoyée, la photo ne dit plus ni quand ni où', () async {
    final envoyee = sansMetadonnees(_photoExif);

    final m = await lireMetadonnees(envoyee);
    expect(m.prisLe, isNull);
    expect(m.aUnePosition, isFalse);
    expect(await readExifFromBytes(envoyee), isEmpty);
    // La même image, sans réencodage : de ses dimensions à la fin,
    // octet pour octet.
    final image = _marqueur(_photoExif, 0xC0);
    expect(
      envoyee.sublist(_marqueur(envoyee, 0xC0)),
      _photoExif.sublist(image),
    );
    expect(envoyee.length, lessThan(_photoExif.length));
  });

  test('envoyée, la photo garde son orientation', () async {
    final propre = sansMetadonnees(_photoExif);
    final tournee = Uint8List.fromList([
      0xFF,
      0xD8,
      ..._exifOrientationEtPosition(6),
      ...propre.sublist(2),
    ]);
    final avant = await readExifFromBytes(tournee);
    expect(avant.keys, contains('GPS GPSLatitudeRef'));

    final apres = await readExifFromBytes(sansMetadonnees(tournee));
    expect(apres['Image Orientation']?.values.firstAsInt(), 6);
    expect(apres.keys.where((cle) => cle.startsWith('GPS')), isEmpty);
    // Droite, l'orientation n'a pas besoin d'être dite.
    final droite = Uint8List.fromList([
      0xFF,
      0xD8,
      ..._exifOrientationEtPosition(1),
      ...propre.sublist(2),
    ]);
    expect(sansMetadonnees(droite), propre);
  });

  test('envoyée, une image PNG perd ses textes', () {
    // Un morceau tEXt (« Location » : …) juste avant la fin.
    final fin = _png.length - 12;
    final texte = [...'Location'.codeUnits, 0, ...'50.64,5.58'.codeUnits];
    final avecTexte = Uint8List.fromList([
      ..._png.sublist(0, fin),
      0,
      0,
      0,
      texte.length,
      ...'tEXt'.codeUnits,
      ...texte,
      0,
      0,
      0,
      0,
      ..._png.sublist(fin),
    ]);

    expect(sansMetadonnees(avecTexte), _png);
  });

  test('un fichier inconnu ou abîmé part tel quel', () {
    final inconnu = Uint8List.fromList([1, 2, 3]);
    final abime = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0xFF]);

    expect(sansMetadonnees(inconnu), same(inconnu));
    expect(sansMetadonnees(abime), same(abime));
  });
}
