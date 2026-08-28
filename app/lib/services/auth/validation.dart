/// Règles de validation des formulaires d'authentification.
///
/// Elles vivent dans le métier, pas dans l'UI : décider qu'un mot de passe
/// de 5 caractères est trop court est une décision produit. L'écran se
/// contente d'afficher le message qu'on lui renvoie.
///
/// Convention : chaque fonction renvoie `null` si la valeur est correcte,
/// sinon le message à montrer à l'utilisateur.
class Validation {
  const Validation._();

  /// Longueur minimale d'un mot de passe.
  static const int longueurMinMotDePasse = 8;

  /// Longueur minimale d'un pseudo.
  static const int longueurMinPseudo = 3;

  static const int longueurMaxPseudo = 20;

  static final RegExp _formatEmail = RegExp(
    r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
  );

  static final RegExp _formatPseudo = RegExp(r'^[a-zA-Z0-9_.-]+$');

  static String? email(String valeur) {
    final v = valeur.trim();
    if (v.isEmpty) return 'Entre ton adresse e-mail.';
    if (!_formatEmail.hasMatch(v)) return "Cette adresse e-mail n'est pas valide.";
    return null;
  }

  static String? motDePasse(String valeur) {
    if (valeur.isEmpty) return 'Entre un mot de passe.';
    if (valeur.length < longueurMinMotDePasse) {
      return 'Au moins $longueurMinMotDePasse caractères.';
    }
    return null;
  }

  /// Utilisé à la connexion : on vérifie seulement que le champ est rempli.
  /// Rejeter un mot de passe trop court ici renseignerait un attaquant sur
  /// nos règles sans aucun bénéfice.
  static String? motDePasseRempli(String valeur) {
    if (valeur.isEmpty) return 'Entre ton mot de passe.';
    return null;
  }

  static String? pseudo(String valeur) {
    final v = valeur.trim();
    if (v.isEmpty) return 'Choisis un pseudo.';
    if (v.length < longueurMinPseudo) {
      return 'Au moins $longueurMinPseudo caractères.';
    }
    if (v.length > longueurMaxPseudo) {
      return 'Au plus $longueurMaxPseudo caractères.';
    }
    if (!_formatPseudo.hasMatch(v)) {
      return 'Lettres, chiffres, tiret, point et souligné uniquement.';
    }
    return null;
  }

  static String? confirmationMotDePasse(String motDePasse, String confirmation) {
    if (confirmation.isEmpty) return 'Confirme ton mot de passe.';
    if (motDePasse != confirmation) {
      return 'Les deux mots de passe ne correspondent pas.';
    }
    return null;
  }
}
