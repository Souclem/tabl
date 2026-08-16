import 'utilisateur.dart';

/// Erreur d'authentification porteuse d'un message affichable tel quel.
class ErreurAuth implements Exception {
  const ErreurAuth(this.message);

  final String message;

  @override
  String toString() => 'ErreurAuth: $message';
}

/// Contrat d'authentification.
///
/// L'application dépend de cette interface, jamais d'une implémentation
/// concrète. Le jour où Supabase est branché, on écrit un
/// `AuthServiceSupabase` et aucun écran ne bouge — même principe que
/// `ITerminalClient` côté SGT.
abstract interface class AuthService {
  /// Connecte un utilisateur existant.
  /// Lance [ErreurAuth] si les identifiants sont refusés.
  Future<Utilisateur> connexion({
    required String email,
    required String motDePasse,
  });

  /// Crée un compte puis connecte l'utilisateur.
  /// Lance [ErreurAuth] si l'e-mail ou le pseudo est déjà pris.
  Future<Utilisateur> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  });
}
