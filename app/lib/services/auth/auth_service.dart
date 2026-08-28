import 'utilisateur.dart';

/// Erreur d'authentification porteuse d'un message affichable tel quel.
class ErreurAuth implements Exception {
  const ErreurAuth(this.message);

  final String message;

  @override
  String toString() => 'ErreurAuth: $message';
}

/// Ce qui se passe après une tentative d'inscription réussie : soit le
/// compte est immédiatement utilisable, soit il faut d'abord confirmer
/// l'adresse e-mail. Un type plutôt qu'une exception, parce que ce n'est
/// pas une erreur — c'est le déroulement normal quand la confirmation par
/// e-mail est activée.
sealed class ResultatInscription {
  const ResultatInscription();
}

/// Le compte est créé et une session est ouverte : pas de confirmation
/// d'e-mail requise (ou déjà effectuée).
class InscriptionReussie extends ResultatInscription {
  const InscriptionReussie(this.utilisateur);

  final Utilisateur utilisateur;
}

/// Le compte est créé mais reste inactif tant que l'e-mail n'est pas
/// confirmé.
class InscriptionEnAttenteConfirmation extends ResultatInscription {
  const InscriptionEnAttenteConfirmation();
}

/// Ce qui se passe après une connexion Apple/Google réussie côté
/// fournisseur : soit le compte a déjà un profil (pseudo) et l'utilisateur
/// peut entrer directement, soit c'est son premier login et il n'a pas
/// encore de pseudo — il faut le lui demander avant de continuer.
sealed class ResultatConnexionOAuth {
  const ResultatConnexionOAuth();
}

/// Le compte a déjà un profil : connexion complète.
class ConnexionOAuthReussie extends ResultatConnexionOAuth {
  const ConnexionOAuthReussie(this.utilisateur);

  final Utilisateur utilisateur;
}

/// Premier login via Apple/Google : le compte existe côté Supabase mais
/// n'a pas encore de pseudo. Voir [AuthService.completerProfil].
class ProfilAConfigurer extends ResultatConnexionOAuth {
  const ProfilAConfigurer({required this.id, required this.email});

  final String id;
  final String email;
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

  /// Crée un compte. Voir [ResultatInscription] pour la suite : connecté
  /// tout de suite, ou en attente de confirmation par e-mail.
  /// Lance [ErreurAuth] si l'e-mail ou le pseudo est déjà pris.
  Future<ResultatInscription> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  });

  /// L'utilisateur déjà connecté, si une session valide a été restaurée
  /// au démarrage (voir `TablBackend.demarrer`) — `null` si personne
  /// n'est connecté. Sert à sauter l'écran de connexion pour qui est déjà
  /// identifié.
  Future<Utilisateur?> utilisateurConnecte();

  /// Connecte (ou inscrit, si premier login) via Sign in with Apple.
  /// Lance [ErreurAuth] en cas d'échec. `null` si l'utilisateur annule —
  /// ce n'est pas une erreur, l'écran ne doit rien afficher dans ce cas.
  Future<ResultatConnexionOAuth?> connexionApple();

  /// Connecte (ou inscrit, si premier login) via Google Sign-In.
  /// Lance [ErreurAuth] en cas d'échec. `null` si l'utilisateur annule —
  /// ce n'est pas une erreur, l'écran ne doit rien afficher dans ce cas.
  Future<ResultatConnexionOAuth?> connexionGoogle();

  /// Termine la création du profil après un premier login Apple/Google
  /// (voir [ProfilAConfigurer]). Lance [ErreurAuth] si le pseudo est pris.
  Future<Utilisateur> completerProfil({
    required String id,
    required String email,
    required String pseudo,
  });

  /// Met fin à la session en cours.
  Future<void> deconnexion();
}
