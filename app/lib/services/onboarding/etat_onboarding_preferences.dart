import 'package:shared_preferences/shared_preferences.dart';

import 'etat_onboarding.dart';

/// [EtatOnboarding] persisté localement via `shared_preferences`.
class EtatOnboardingPreferences implements EtatOnboarding {
  static const String _cle = 'onboarding_vu';

  @override
  Future<bool> aDejaVuOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_cle) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> marquerOnboardingVu() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cle, true);
  }
}
