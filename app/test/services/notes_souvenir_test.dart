import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('notesPourBase', () {
    test('garde les catégories notées de 1 à 5', () {
      expect(notesPourBase({'cuisine': 4, 'qualite_prix': 1}), {
        'cuisine': 4,
        'qualite_prix': 1,
      });
    });

    test('écarte les clés inconnues et les notes hors de 1 à 5', () {
      expect(
        notesPourBase({'cuisine': 0, 'service': 6, 'dessert': 3, 'lieu': 5}),
        {'lieu': 5},
      );
    });

    test('null quand rien n\'est noté', () {
      expect(notesPourBase(const {}), isNull);
      expect(notesPourBase({'cuisine': 0}), isNull);
    });
  });

  group('notesDepuisBase', () {
    test('lit le jsonb', () {
      expect(notesDepuisBase({'cuisine': 4, 'service': 2}), {
        'cuisine': 4,
        'service': 2,
      });
    });

    test('vide quand la colonne est nulle ou illisible', () {
      expect(notesDepuisBase(null), isEmpty);
      expect(notesDepuisBase('x'), isEmpty);
      expect(notesDepuisBase({'cuisine': 'bon'}), isEmpty);
    });
  });
}
