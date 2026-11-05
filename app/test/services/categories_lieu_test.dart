import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  group('libelleCategorie', () {
    test('traduit une catégorie connue', () {
      expect(libelleCategorie('Cupcake Shop'), 'Cupcakes');
      expect(libelleCategorie('Bakery'), 'Boulangerie');
    });

    test('traduit toute cuisine « X Restaurant » du monde', () {
      expect(libelleCategorie('Peruvian Restaurant'), 'Péruvien');
      expect(libelleCategorie('Sri Lankan Restaurant'), 'Sri-lankais');
      expect(libelleCategorie('Ethiopian Restaurant'), 'Éthiopien');
    });

    test("garde le texte d'origine si la catégorie est inconnue", () {
      expect(libelleCategorie('Zorglub Restaurant'), 'Zorglub Restaurant');
      expect(libelleCategorie('Quelque chose'), 'Quelque chose');
      expect(libelleCategorie(''), '');
    });

    test('ignore les espaces autour du nom', () {
      expect(libelleCategorie(' Cupcake Shop '), 'Cupcakes');
    });
  });
}
