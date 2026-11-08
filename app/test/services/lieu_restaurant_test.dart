import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('description : type en français, adresse, ville et distance', () {
    const lieu = LieuRestaurant(
      nom: 'Le Paris-Brest',
      ville: 'Liège',
      fsqPlaceId: 'x',
      adresse: 'Rue du Pont 16',
      categories: ['French Restaurant'],
      distanceM: 348,
    );
    expect(lieu.description, 'Français · Rue du Pont 16, Liège · 350 m');
  });

  test(
    'description : catégorie inconnue gardée telle quelle, sans adresse',
    () {
      const lieu = LieuRestaurant(
        nom: 'X',
        ville: 'Liège',
        categories: ['Zorglub Place'],
      );
      expect(lieu.description, 'Zorglub Place · Liège');
    },
  );

  test('saisi à la main = ni restaurant Tabl ni lieu de l\'annuaire', () {
    expect(
      const LieuRestaurant.manuel(nom: 'Chez K', ville: 'Liège').estManuel,
      isTrue,
    );
    expect(
      const LieuRestaurant(nom: 'a', ville: 'b', fsqPlaceId: 'f').estManuel,
      isFalse,
    );
  });

  test('normaliserPourRecherche : minuscules et sans accents', () {
    expect(
      normaliserPourRecherche('  ¡Toma! Cuisine Immersive '),
      '!toma! cuisine immersive',
    );
    expect(normaliserPourRecherche('Chez Mémères'), 'chez memeres');
    expect(normaliserPourRecherche('Œuf'), 'oeuf');
  });
}
