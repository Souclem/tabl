import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

LieuCarte _annuaire(String categorie) => LieuCarte(
  fsqPlaceId: categorie,
  nom: categorie,
  ville: 'Liège',
  latitude: 50.6,
  longitude: 5.5,
  categories: [categorie],
);

void main() {
  test('familles de cuisine dépliées en catégories pour la base', () {
    expect(FiltresCarte.aucun.categories, isNull);
    expect(
      const FiltresCarte(familles: {'Italienne et pizza'}).categories,
      unorderedEquals(['Italian Restaurant', 'Pizzeria']),
    );
  });

  test('annuaire : la cuisine filtre, les filtres « réseau » le masquent', () {
    expect(FiltresCarte.aucun.gardeAnnuaire(_annuaire('Pizzeria')), isTrue);
    const italien = FiltresCarte(familles: {'Italienne et pizza'});
    expect(italien.gardeAnnuaire(_annuaire('Pizzeria')), isTrue);
    expect(italien.gardeAnnuaire(_annuaire('Sushi Restaurant')), isFalse);
    for (final reseau in const [
      FiltresCarte(personneId: 'emma'),
      FiltresCarte(tableId: 'marbella'),
      FiltresCarte(coupsDeCoeur: true),
      FiltresCarte(laOuOnRevient: true),
      FiltresCarte(moment: 'midi'),
      FiltresCarte(mesEnvies: true),
    ]) {
      expect(reseau.annuaireVisible, isFalse);
      expect(reseau.gardeAnnuaire(_annuaire('Pizzeria')), isFalse);
    }
    expect(const FiltresCarte(jamaisEssaye: true).annuaireVisible, isTrue);
  });

  test('nombre de filtres actifs', () {
    expect(FiltresCarte.aucun.nombreActifs, 0);
    expect(
      const FiltresCarte(coupsDeCoeur: true, familles: {'Asiatique'}).nombreActifs,
      2,
    );
  });
}
