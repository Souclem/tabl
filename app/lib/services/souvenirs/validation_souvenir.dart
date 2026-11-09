import 'presentation_finalisation.dart';

/// Règles de validation du formulaire de publication.
///
/// Même convention que `services/auth/validation.dart` : chaque fonction
/// renvoie `null` si la valeur est correcte, sinon le message à afficher.
class ValidationSouvenir {
  const ValidationSouvenir._();

  static String? nomRestaurant(String valeur) {
    if (valeur.trim().isEmpty) return 'Entre le nom du restaurant.';
    return null;
  }

  static String? ville(String valeur) {
    if (valeur.trim().isEmpty) return 'Entre la ville.';
    return null;
  }

  /// La légende est optionnelle : `valeur` peut être vide. 120 caractères
  /// maximum (voir B9).
  static String? legende(String valeur) {
    if (valeur.length > 120) return '120 caractères maximum.';
    return null;
  }

  /// « Ajouter un mot » de la finalisation : le même texte que la légende,
  /// mais jusqu'à 300 caractères.
  static String? mot(String valeur) {
    if (valeur.length > longueurMaxMot) {
      return '$longueurMaxMot caractères maximum.';
    }
    return null;
  }
}
