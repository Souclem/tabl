import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  group('lien d\'itinéraire', () {
    test('avec les coordonnées : Google Maps', () {
      final lien = lienItineraire(
        latitude: 50.6326,
        longitude: 5.5797,
        nom: 'Bibo',
        adresse: 'Rue Saint-Gilles 1',
      );
      expect(
        lien.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=50.6326%2C5.5797',
      );
    });

    test('avec les coordonnées : Plans sur iPhone', () {
      final lien = lienItineraire(
        latitude: 50.6326,
        longitude: 5.5797,
        pourApple: true,
      );
      expect(lien?.host, 'maps.apple.com');
      expect(lien?.queryParameters['daddr'], '50.6326,5.5797');
    });

    test('sans coordonnées : le nom et l\'adresse', () {
      final lien = lienItineraire(nom: 'Bibo', adresse: 'Rue Saint-Gilles 1');
      expect(lien?.queryParameters['destination'], 'Bibo, Rue Saint-Gilles 1');
    });

    test('une seule coordonnée ou des coordonnées absurdes : le nom', () {
      expect(
        lienItineraire(
          latitude: 50.6,
          nom: 'Bibo',
        )?.queryParameters['destination'],
        'Bibo',
      );
      expect(
        lienItineraire(
          latitude: 250,
          longitude: 5,
          nom: 'Bibo',
        )?.queryParameters['destination'],
        'Bibo',
      );
    });

    test('nom ou adresse vides ignorés', () {
      expect(
        lienItineraire(
          nom: ' ',
          adresse: 'Rue Saint-Gilles 1',
        )?.queryParameters['destination'],
        'Rue Saint-Gilles 1',
      );
    });

    test('rien à suivre : pas de lien', () {
      expect(lienItineraire(), isNull);
      expect(lienItineraire(nom: '', adresse: '  '), isNull);
    });
  });
}
