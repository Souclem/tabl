import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/services.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RaccourcisVillesServicePreferences', () {
    test('mesVilles retourne une liste vide au départ', () async {
      final service = RaccourcisVillesServicePreferences();

      expect(await service.mesVilles(), isEmpty);
    });

    test('ajouterVille conserve l\'ordre d\'ajout', () async {
      final service = RaccourcisVillesServicePreferences();

      await service.ajouterVille('Paris');
      await service.ajouterVille('Liège');
      await service.ajouterVille('Marbella');

      expect(await service.mesVilles(), ['Paris', 'Liège', 'Marbella']);
    });

    test('ajouterVille est idempotent (pas de doublon)', () async {
      final service = RaccourcisVillesServicePreferences();

      await service.ajouterVille('Paris');
      await service.ajouterVille('Paris');

      expect(await service.mesVilles(), ['Paris']);
    });

    test('ajouterVille ignore une chaîne vide', () async {
      final service = RaccourcisVillesServicePreferences();

      await service.ajouterVille('   ');

      expect(await service.mesVilles(), isEmpty);
    });

    test('retirerVille retire uniquement le raccourci visé', () async {
      final service = RaccourcisVillesServicePreferences();
      await service.ajouterVille('Paris');
      await service.ajouterVille('Liège');

      await service.retirerVille('Paris');

      expect(await service.mesVilles(), ['Liège']);
    });
  });
}
