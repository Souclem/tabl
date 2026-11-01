/// Ce que l'on dit d'un refus du serveur d'authentification. Supabase
/// répond en anglais, parfois en termes techniques : on se fie d'abord à
/// son [code] (stable), au texte du [message] seulement pour les
/// réponses qui n'en ont pas. Jamais le message brut : il est en
/// anglais.
String messageErreurAuth({String? code, required String message}) {
  final m = message.toLowerCase();
  bool est(String c, [String? extrait]) =>
      code == c || (extrait != null && m.contains(extrait));

  if (est('invalid_credentials', 'invalid login credentials')) {
    return 'E-mail ou mot de passe incorrect.';
  }
  if (est('email_not_confirmed', 'email not confirmed')) {
    return "Confirme d'abord ton adresse e-mail : le lien est dans ta "
        'boîte mail.';
  }
  if (est('user_already_exists', 'already registered') ||
      est('email_exists', 'already exists')) {
    return 'Un compte existe déjà avec cette adresse.';
  }
  if (est('email_address_invalid', 'is invalid')) {
    return "Cette adresse e-mail n'est pas valide.";
  }
  if (est('weak_password', 'password should')) {
    return 'Mot de passe trop simple : choisis-en un plus long.';
  }
  // L'envoi de l'e-mail de confirmation est refusé : adresse non
  // autorisée par le service d'envoi, ou trop d'e-mails récents. Rien
  // que l'utilisateur puisse corriger lui-même.
  if (est('email_address_not_authorized', 'not authorized') ||
      est('over_email_send_rate_limit', 'email rate limit')) {
    return "Impossible d'envoyer l'e-mail de confirmation pour l'instant. "
        'Réessaie plus tard, ou continue avec Google.';
  }
  if (est('over_request_rate_limit', 'rate limit')) {
    return 'Trop de tentatives récentes. Réessaie dans quelques minutes.';
  }
  if (est('signup_disabled', 'signups not allowed')) {
    return "Les inscriptions sont fermées pour l'instant.";
  }
  return 'Connexion impossible pour le moment. Réessaie.';
}
