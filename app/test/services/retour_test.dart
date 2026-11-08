import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('un message part avec un type et quelques mots', () {
    expect(peutEnvoyerRetour(null, 'La carte reste blanche.'), isFalse);
    expect(peutEnvoyerRetour(TypeRetour.bug, '   '), isFalse);
    expect(
      peutEnvoyerRetour(TypeRetour.bug, 'La carte reste blanche.'),
      isTrue,
    );
    expect(
      peutEnvoyerRetour(TypeRetour.idee, 'a' * (longueurMaxRetour + 1)),
      isFalse,
    );
  });

  test('chaque type a sa valeur en base', () {
    expect(TypeRetour.values.map((t) => t.valeur), [
      'bug',
      'idee',
      'pas_clair',
      'lieu',
      'signalement',
      'autre',
    ]);
  });

  test('format d\'une capture : PNG reconnu, JPEG sinon', () {
    final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]);
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
    expect(formatCapture(png), (extension: 'png', typeMime: 'image/png'));
    expect(formatCapture(jpeg), (extension: 'jpg', typeMime: 'image/jpeg'));
  });
}
