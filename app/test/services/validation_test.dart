import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  group('Validation.email', () {
    test('vide → message dédié', () {
      expect(Validation.email(''), 'Entre ton adresse e-mail.');
    });

    test('juste des espaces → traité comme vide', () {
      expect(Validation.email('   '), 'Entre ton adresse e-mail.');
    });

    test('sans @ → invalide', () {
      expect(
        Validation.email('camille.exemple.com'),
        "Cette adresse e-mail n'est pas valide.",
      );
    });

    test('sans domaine → invalide', () {
      expect(
        Validation.email('camille@'),
        "Cette adresse e-mail n'est pas valide.",
      );
    });

    test('adresse valide → null', () {
      expect(Validation.email('camille@exemple.com'), isNull);
    });

    test('espaces autour d\'une adresse valide → acceptée (trim)', () {
      expect(Validation.email('  camille@exemple.com  '), isNull);
    });
  });

  group('Validation.motDePasse', () {
    test('vide → message dédié', () {
      expect(Validation.motDePasse(''), 'Entre un mot de passe.');
    });

    test('juste en dessous du minimum (7) → refusé', () {
      expect(
        Validation.motDePasse('1234567'),
        'Au moins ${Validation.longueurMinMotDePasse} caractères.',
      );
    });

    test('exactement au minimum (8) → accepté', () {
      expect(Validation.motDePasse('12345678'), isNull);
    });

    test('bien au-dessus du minimum → accepté', () {
      expect(Validation.motDePasse('un-mot-de-passe-long'), isNull);
    });
  });

  group('Validation.motDePasseRempli', () {
    test('vide → message dédié', () {
      expect(Validation.motDePasseRempli(''), 'Entre ton mot de passe.');
    });

    test('un seul caractère → accepté (pas de règle de longueur ici)', () {
      expect(Validation.motDePasseRempli('a'), isNull);
    });
  });

  group('Validation.pseudo', () {
    test('vide → message dédié', () {
      expect(Validation.pseudo(''), 'Choisis un pseudo.');
    });

    test('juste en dessous du minimum (2) → refusé', () {
      expect(
        Validation.pseudo('ab'),
        'Au moins ${Validation.longueurMinPseudo} caractères.',
      );
    });

    test('exactement au minimum (3) → accepté', () {
      expect(Validation.pseudo('abc'), isNull);
    });

    test('exactement au maximum (20) → accepté', () {
      expect(Validation.pseudo('a' * 20), isNull);
    });

    test('juste au-dessus du maximum (21) → refusé', () {
      expect(
        Validation.pseudo('a' * 21),
        'Au plus ${Validation.longueurMaxPseudo} caractères.',
      );
    });

    test('espace au milieu → format refusé', () {
      expect(
        Validation.pseudo('camille dupont'),
        'Lettres, chiffres, tiret, point et souligné uniquement.',
      );
    });

    test('accent → format refusé', () {
      expect(
        Validation.pseudo('camillé'),
        'Lettres, chiffres, tiret, point et souligné uniquement.',
      );
    });

    test('tiret, point et souligné → acceptés', () {
      expect(Validation.pseudo('camille-du.pont_x'), isNull);
    });

    test('espaces en trop autour d\'un pseudo valide → acceptés (trim)', () {
      expect(Validation.pseudo('  camille  '), isNull);
    });
  });

  group('Validation.confirmationMotDePasse', () {
    test('confirmation vide → message dédié', () {
      expect(
        Validation.confirmationMotDePasse('motdepasse123', ''),
        'Confirme ton mot de passe.',
      );
    });

    test('ne correspond pas → refusé', () {
      expect(
        Validation.confirmationMotDePasse('motdepasse123', 'autrechose'),
        'Les deux mots de passe ne correspondent pas.',
      );
    });

    test('correspond exactement → accepté', () {
      expect(
        Validation.confirmationMotDePasse('motdepasse123', 'motdepasse123'),
        isNull,
      );
    });

    test('sensible à la casse : correspondance imparfaite → refusé', () {
      expect(
        Validation.confirmationMotDePasse('MotDePasse123', 'motdepasse123'),
        'Les deux mots de passe ne correspondent pas.',
      );
    });
  });
}
