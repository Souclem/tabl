import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

ProfilPublic _proche(String pseudo) =>
    ProfilPublic(id: pseudo, pseudo: pseudo, statut: StatutAbonnement.abonne);

void main() {
  test('le nombre d’adresses, en toutes lettres quand il n’y en a pas', () {
    expect(nombreAdresses(0), 'Aucune adresse');
    expect(nombreAdresses(1), '1 adresse');
    expect(nombreAdresses(12), '12 adresses');
  });

  test('la valeur d’une ligne : ce qui est choisi, ou ce que vaut rien', () {
    expect(valeurMoment(null), 'Tous');
    expect(valeurMoment('soir'), 'Dîner');
    expect(valeurProche(null), 'Tout le cercle');
    expect(valeurTable(null), 'Toutes');
    expect(valeurHistoire(true), 'Pas encore essayées');
  });

  test('les cuisines : deux nommées au plus, puis « +N »', () {
    final [a, b, c, ...] = famillesCuisine.keys.toList();
    expect(valeurCuisine({}), 'Toutes');
    expect(valeurCuisine({b, a}), '$a, $b');
    expect(valeurCuisine({c, a, b}), '$a +2');
  });

  group('prochesCorrespondants', () {
    final proches = [
      _proche('Noémie'),
      _proche('Emma'),
      _proche('Clément'),
      _proche('Léo'),
      _proche('Emeline'),
    ];

    test('ceux qui commencent par la saisie d’abord, sans accents', () {
      final r = prochesCorrespondants(proches, 'em');
      expect(
        [for (final p in r.proches) p.pseudo],
        ['Emeline', 'Emma', 'Clément', 'Noémie'],
      );
      expect(r.autres, 0);
    });

    test('au plus [max], et combien d’autres', () {
      final r = prochesCorrespondants(proches, '', max: 2);
      expect([for (final p in r.proches) p.pseudo], ['Clément', 'Emeline']);
      expect(r.autres, 3);
    });

    test('les lettres à souligner : le début seulement', () {
      expect(debutCorrespondant('Émeline', 'em'), 2);
      expect(debutCorrespondant('Clément', 'em'), 0);
      expect(debutCorrespondant('Emma', ''), 0);
    });
  });
}
