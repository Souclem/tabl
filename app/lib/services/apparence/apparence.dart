import 'package:shared_preferences/shared_preferences.dart';

/// Clair ou sombre. Pour l'instant, seul l'Explorer suit ce réglage : le
/// reste de l'app reste sombre.
enum Apparence {
  automatique('Automatique', 'Comme votre téléphone'),
  clair('Clair', 'Fond ivoire'),
  sombre('Sombre', 'Fond nuit');

  const Apparence(this.libelle, this.detail);

  final String libelle;
  final String detail;

  /// Clair pour de bon, le réglage du téléphone pris en compte.
  bool estClaire({required bool telephoneClair}) => switch (this) {
    automatique => telephoneClair,
    clair => true,
    sombre => false,
  };
}

/// Où l'apparence choisie est retenue.
abstract interface class PreferenceApparence {
  /// [Apparence.automatique] tant que rien n'a été choisi, ou si le
  /// stockage ne répond pas.
  Future<Apparence> lire();

  Future<void> ecrire(Apparence apparence);
}

/// [PreferenceApparence] gardée sur l'appareil, via `shared_preferences`.
class PreferenceApparencePreferences implements PreferenceApparence {
  static const String _cle = 'apparence';

  @override
  Future<Apparence> lire() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final valeur = prefs.getString(_cle);
      return Apparence.values.where((a) => a.name == valeur).firstOrNull ??
          Apparence.automatique;
    } catch (_) {
      return Apparence.automatique;
    }
  }

  @override
  Future<void> ecrire(Apparence apparence) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, apparence.name);
    } catch (_) {
      // Pas de stockage : le choix vaut pour cette ouverture de l'app.
    }
  }
}
