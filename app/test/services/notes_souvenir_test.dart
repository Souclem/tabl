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
      expect(notesPourBase({'plat:Risotto': 0}), isNull);
    });

    test('les plats notés vont sous "plats", dans l\'ordre écrit', () {
      expect(
        notesPourBase({
          'cuisine': 4,
          'plat:Risotto': 5,
          'plat:Pain': 0,
          'plat:Tiramisu': 3,
        }),
        {
          'cuisine': 4,
          'plats': [
            {'nom': 'Risotto', 'note': 5},
            {'nom': 'Tiramisu', 'note': 3},
          ],
        },
      );
    });

    test('cinq plats au plus', () {
      final notes = notesPourBase({
        for (var i = 1; i <= 7; i++) 'plat:Plat $i': 4,
      });
      expect((notes!['plats']! as List).length, 5);
    });
  });

  group('notesDepuisBase', () {
    test('lit le jsonb', () {
      expect(notesDepuisBase({'cuisine': 4, 'service': 2}), {
        'cuisine': 4,
        'service': 2,
      });
    });

    test('relit les plats sous leur clé, aller-retour fidèle', () {
      final etoiles = {'cuisine': 4, 'plat:Risotto': 5, 'plat:Tiramisu': 3};
      expect(notesDepuisBase(notesPourBase(etoiles)), etoiles);
      expect(notesDepuisBase(notesPourBase(etoiles)).keys.toList(), [
        'cuisine',
        'plat:Risotto',
        'plat:Tiramisu',
      ]);
    });

    test('un plat mal formé est ignoré', () {
      expect(
        notesDepuisBase({
          'plats': [
            {'nom': 'Risotto'},
            'x',
            {'nom': 'Pain', 'note': 2},
          ],
        }),
        {'plat:Pain': 2},
      );
    });

    test('vide quand la colonne est nulle ou illisible', () {
      expect(notesDepuisBase(null), isEmpty);
      expect(notesDepuisBase('x'), isEmpty);
      expect(notesDepuisBase({'cuisine': 'bon'}), isEmpty);
    });
  });

  group('plats écrits', () {
    test('validation : vide, trop long, en double, au-delà de cinq', () {
      expect(validationPlat('  ', {}), isNotNull);
      expect(validationPlat('a' * 41, {}), '40 caractères maximum.');
      expect(validationPlat('Risotto', {}), isNull);
      expect(validationPlat('risotto ', {'plat:Risotto': 4}), isNotNull);
      final cinq = {for (var i = 1; i <= 5; i++) 'plat:Plat $i': 0};
      expect(peutAjouterPlat(cinq), isFalse);
      expect(validationPlat('Sixième', cinq), libelleLimitePlats);
    });

    test('clé et nom', () {
      expect(clePlat('  Risotto '), 'plat:Risotto');
      expect(nomPlat('plat:Risotto'), 'Risotto');
      expect(estClePlat('cuisine'), isFalse);
      expect(clesPlats({'cuisine': 3, 'plat:B': 0, 'plat:A': 2}), [
        'plat:B',
        'plat:A',
      ]);
    });
  });
}
