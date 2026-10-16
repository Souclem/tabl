import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('0 à 6 photos : retournées telles quelles, sans tri ni tirage', () {
    expect(selectionnerMosaique([]), isEmpty);
    expect(selectionnerMosaique(['a']), ['a']);
    expect(selectionnerMosaique(['a', 'b']), ['a', 'b']);
    expect(selectionnerMosaique(['a', 'b', 'c']), ['a', 'b', 'c']);
    expect(
      selectionnerMosaique(['a', 'b', 'c', 'd', 'e', 'f']),
      ['a', 'b', 'c', 'd', 'e', 'f'],
    );
  });

  test('plus de 6 photos : garde les 6 premières (les plus pertinentes)', () {
    final photos = List.generate(20, (i) => 'photo-$i');
    final resultat = selectionnerMosaique(photos);

    expect(resultat, hasLength(6));
    expect(resultat, ['photo-0', 'photo-1', 'photo-2', 'photo-3', 'photo-4', 'photo-5']);
  });

  test('déterministe : deux appels avec la même entrée donnent le même résultat', () {
    final photos = List.generate(9, (i) => 'photo-$i');
    expect(selectionnerMosaique(photos), selectionnerMosaique(photos));
  });
}
