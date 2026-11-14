import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'une réponse du géocodage : le nom, où, et le contour s’il est donné',
    () {
      final endroits = endroitsDepuisMapbox({
        'features': [
          {
            'properties': {
              'name': 'Ixelles',
              'place_formatted': 'Bruxelles, Belgique',
              'coordinates': {'latitude': 50.83, 'longitude': 4.37},
              'bbox': [4.35, 50.80, 4.40, 50.85],
            },
          },
          {
            'properties': {
              'name': 'Rue du Pont 16',
              'coordinates': {'latitude': 50.64, 'longitude': 5.57},
            },
          },
          // Incomplet : ignoré.
          {
            'properties': {'name': 'Nulle part'},
          },
        ],
      });

      expect(endroits.map((e) => e.nom), ['Ixelles', 'Rue du Pont 16']);
      expect(endroits.first.detail, 'Bruxelles, Belgique');
      expect(endroits.first.zone.ouest, 4.35);
      expect(endroits.first.zone.nord, 50.85);
      // Une adresse : un petit carré autour du point.
      expect(endroits.last.zone.contient(50.64, 5.57), isTrue);
      expect(endroits.last.zone.contient(50.70, 5.57), isFalse);
    },
  );

  test('on demande aussi les rues et les codes postaux, pas seulement les '
      'villes et les adresses numérotées', () {
    // Sans `street`, « rue Saint-Gilles » ne trouvait rien.
    final types = RechercheEndroitMapbox.types.split(',');
    expect(types, containsAll(['street', 'address', 'postcode', 'place']));
  });
}
