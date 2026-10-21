import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  final maintenant = DateTime(2026, 10, 21, 18);

  test('rien en mémoire : tout est à signer, une seule fois chacun', () {
    final tri = MemoireLiens().trier('souvenirs', [
      'a.jpg',
      'b.jpg',
      'a.jpg',
    ], maintenant);

    expect(tri.connus, isEmpty);
    expect(tri.aSigner, ['a.jpg', 'b.jpg']);
  });

  test('un lien qui vaut encore assez est redonné tel quel', () {
    final memoire = MemoireLiens()
      ..retenir(
        'souvenirs',
        'a.jpg',
        'https://lien-a',
        maintenant.add(dureeLienSigne),
      );

    final tri = memoire.trier('souvenirs', ['a.jpg', 'b.jpg'], maintenant);

    expect(tri.connus, {'a.jpg': 'https://lien-a'});
    expect(tri.aSigner, ['b.jpg']);
  });

  test('un lien trop près de sa fin est resigné', () {
    final memoire = MemoireLiens()
      ..retenir(
        'souvenirs',
        'a.jpg',
        'https://lien-a',
        maintenant.add(margeLienSigne - const Duration(minutes: 1)),
      );

    final tri = memoire.trier('souvenirs', ['a.jpg'], maintenant);

    expect(tri.connus, isEmpty);
    expect(tri.aSigner, ['a.jpg']);
  });

  test('un même chemin dans un autre bucket n\'est pas le même lien', () {
    final memoire = MemoireLiens()
      ..retenir(
        'souvenirs',
        'a.jpg',
        'https://lien-a',
        maintenant.add(dureeLienSigne),
      );

    final tri = memoire.trier('instants', ['a.jpg'], maintenant);

    expect(tri.aSigner, ['a.jpg']);
  });

  test('vider oublie tout', () {
    final memoire = MemoireLiens()
      ..retenir(
        'souvenirs',
        'a.jpg',
        'https://lien-a',
        maintenant.add(dureeLienSigne),
      )
      ..vider();

    expect(memoire.trier('souvenirs', ['a.jpg'], maintenant).aSigner, [
      'a.jpg',
    ]);
  });
}
