import 'dart:convert';

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

void main() {
  test('la date et la position d\'une vraie photo', () async {
    final m = await lireMetadonnees(_photoExif);

    expect(m.prisLe, DateTime(2023, 11, 3, 20, 41, 12));
    expect(m.latitude, closeTo(50.64735, 1e-6));
    expect(m.longitude, closeTo(-5.58045, 1e-6));
    expect(m.aUnePosition, isTrue);
  });

  test('une image sans métadonnées n\'en a simplement pas', () async {
    final m = await lireMetadonnees(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
      ),
    );

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
}
