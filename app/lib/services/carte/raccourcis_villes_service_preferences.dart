import 'package:shared_preferences/shared_preferences.dart';

import 'raccourcis_villes_service.dart';

/// [RaccourcisVillesService] persisté localement via
/// `shared_preferences` — même principe que
/// `EtatOnboardingPreferences`.
class RaccourcisVillesServicePreferences implements RaccourcisVillesService {
  static const String _cle = 'carte_raccourcis_villes';

  @override
  Future<List<String>> mesVilles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_cle) ?? const [];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> ajouterVille(String ville) async {
    final v = ville.trim();
    if (v.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final villes = prefs.getStringList(_cle) ?? [];
    if (villes.contains(v)) return;
    await prefs.setStringList(_cle, [...villes, v]);
  }

  @override
  Future<void> retirerVille(String ville) async {
    final prefs = await SharedPreferences.getInstance();
    final villes = prefs.getStringList(_cle) ?? [];
    await prefs.setStringList(_cle, villes.where((v) => v != ville).toList());
  }
}
