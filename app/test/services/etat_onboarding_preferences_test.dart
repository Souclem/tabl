import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/services.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EtatOnboardingPreferences', () {
    test('aDejaVuOnboarding retourne false quand rien n\'a été écrit', () async {
      final etat = EtatOnboardingPreferences();

      expect(await etat.aDejaVuOnboarding(), isFalse);
    });

    test('marquerOnboardingVu fait passer aDejaVuOnboarding à true', () async {
      final etat = EtatOnboardingPreferences();

      await etat.marquerOnboardingVu();

      expect(await etat.aDejaVuOnboarding(), isTrue);
    });

    test('marquerOnboardingVu est idempotent', () async {
      final etat = EtatOnboardingPreferences();

      await etat.marquerOnboardingVu();
      await etat.marquerOnboardingVu();

      expect(await etat.aDejaVuOnboarding(), isTrue);
    });
  });
}
