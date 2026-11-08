import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('automatique suit le téléphone ; clair et sombre s’imposent', () {
    expect(Apparence.automatique.estClaire(telephoneClair: true), isTrue);
    expect(Apparence.automatique.estClaire(telephoneClair: false), isFalse);
    expect(Apparence.clair.estClaire(telephoneClair: false), isTrue);
    expect(Apparence.sombre.estClaire(telephoneClair: true), isFalse);
  });

  test(
    'retenue sur l’appareil, « Automatique » tant que rien n’est choisi',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preference = PreferenceApparencePreferences();
      expect(await preference.lire(), Apparence.automatique);

      await preference.ecrire(Apparence.clair);
      expect(await preference.lire(), Apparence.clair);
    },
  );
}
