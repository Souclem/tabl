import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('familles de cuisine dépliées en catégories pour la base', () {
    expect(FiltresCarte.aucun.categories, isNull);
    expect(
      const FiltresCarte(familles: {'Italienne et pizza'}).categories,
      unorderedEquals(['Italian Restaurant', 'Pizzeria']),
    );
  });

  test('nombre de filtres actifs', () {
    expect(FiltresCarte.aucun.nombreActifs, 0);
    expect(
      const FiltresCarte(
        coupsDeCoeur: true,
        familles: {'Asiatique'},
      ).nombreActifs,
      2,
    );
  });
}
