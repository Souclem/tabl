import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config_oauth.dart';
import 'auth_service.dart';
import 'utilisateur.dart';

/// Authentification adossée à Supabase.
///
/// Supabase gère les comptes (`auth.users`) ; nous gérons le profil public
/// (`public.profils`), qui porte le pseudo.
class AuthServiceSupabase implements AuthService {
  AuthServiceSupabase(this._client);

  final SupabaseClient _client;

  /// Code d'erreur Postgres pour une violation de contrainte d'unicité.
  static const String _codeDoublon = '23505';

  @override
  Future<Utilisateur> connexion({
    required String email,
    required String motDePasse,
  }) async {
    final AuthResponse reponse;
    try {
      reponse = await _client.auth.signInWithPassword(
        email: email,
        password: motDePasse,
      );
    } on AuthException catch (e) {
      throw ErreurAuth(_messageLisible(e));
    }

    final compte = reponse.user;
    if (compte == null) {
      throw const ErreurAuth('Connexion impossible. Réessaie.');
    }
    return _profilDe(compte);
  }

  @override
  Future<Utilisateur?> utilisateurConnecte() async {
    final compte = _client.auth.currentSession?.user;
    if (compte == null) return null;
    try {
      return await _profilDe(compte);
    } catch (_) {
      // Session locale obsolète (compte supprimé côté serveur, projet
      // Supabase réinitialisé...) : on la purge pour retomber proprement
      // sur l'écran de connexion plutôt que de bloquer le démarrage.
      await _client.auth.signOut();
      return null;
    }
  }

  @override
  Future<ResultatInscription> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  }) async {
    final AuthResponse reponse;
    try {
      reponse = await _client.auth.signUp(
        email: email,
        password: motDePasse,
        // Conservé sur le compte : si la création du profil échoue,
        // le pseudo choisi n'est pas perdu.
        data: {'pseudo': pseudo},
      );
    } on AuthException catch (e) {
      throw ErreurAuth(_messageLisible(e));
    }

    final compte = reponse.user;
    if (compte == null) {
      throw const ErreurAuth('Création du compte impossible. Réessaie.');
    }

    // Sans session, l'utilisateur doit d'abord confirmer son e-mail :
    // les règles d'accès bloqueraient l'écriture du profil. Elle se fera
    // à la première connexion réussie (voir _profilDe).
    if (reponse.session == null) {
      return const InscriptionEnAttenteConfirmation();
    }

    await _creerProfil(
      id: compte.id,
      pseudo: pseudo,
      messageDoublon: 'Ce pseudo est déjà pris.',
    );

    return InscriptionReussie(
      Utilisateur(id: compte.id, email: compte.email ?? email, pseudo: pseudo),
    );
  }

  @override
  Future<ResultatConnexionOAuth?> connexionApple() async {
    final rawNonce = _genererNonce();
    final nonceHache = sha256.convert(utf8.encode(rawNonce)).toString();

    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceHache,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const ErreurAuth('Connexion avec Apple impossible. Réessaie.');
    }

    final identityToken = credential.identityToken;
    if (identityToken == null) {
      throw const ErreurAuth('Connexion avec Apple impossible. Réessaie.');
    }

    final AuthResponse reponse;
    try {
      reponse = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: identityToken,
        nonce: rawNonce,
      );
    } on AuthException catch (e) {
      throw ErreurAuth(_messageLisible(e));
    }

    final compte = reponse.user;
    if (compte == null) {
      throw const ErreurAuth('Connexion avec Apple impossible. Réessaie.');
    }
    return _resultatConnexionOAuth(compte);
  }

  @override
  Future<ResultatConnexionOAuth?> connexionGoogle() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: ConfigOAuth.googleClientIdIOS,
      serverClientId: ConfigOAuth.googleClientIdWeb,
    );

    final GoogleSignInAccount compteGoogle;
    try {
      compteGoogle = await googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ErreurAuth('Connexion avec Google impossible. Réessaie.');
    }

    final idToken = compteGoogle.authentication.idToken;
    if (idToken == null) {
      throw const ErreurAuth('Connexion avec Google impossible. Réessaie.');
    }

    final AuthResponse reponse;
    try {
      reponse = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } on AuthException catch (e) {
      throw ErreurAuth(_messageLisible(e));
    }

    final compte = reponse.user;
    if (compte == null) {
      throw const ErreurAuth('Connexion avec Google impossible. Réessaie.');
    }
    return _resultatConnexionOAuth(compte);
  }

  @override
  Future<Utilisateur> completerProfil({
    required String id,
    required String email,
    required String pseudo,
  }) async {
    await _creerProfil(
      id: id,
      pseudo: pseudo,
      messageDoublon: 'Ce pseudo est déjà pris.',
    );
    return Utilisateur(id: id, email: email, pseudo: pseudo);
  }

  @override
  Future<void> deconnexion() => _client.auth.signOut();

  /// Chaîne aléatoire servant de nonce brut pour Sign in with Apple (sa
  /// version hachée en SHA-256 est envoyée à Apple ; la version brute, à
  /// Supabase, qui vérifie que les deux correspondent — protection contre
  /// le rejeu d'un identityToken intercepté).
  String _genererNonce([int longueur = 32]) {
    const caracteres =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final aleatoire = Random.secure();
    return List.generate(
      longueur,
      (_) => caracteres[aleatoire.nextInt(caracteres.length)],
    ).join();
  }

  /// Ligne `profils` d'un compte, ou `null` si elle n'existe pas encore.
  Future<Map<String, dynamic>?> _ligneProfil(String id) {
    return _client.from('profils').select('pseudo').eq('id', id).maybeSingle();
  }

  /// Récupère le profil associé à un compte.
  ///
  /// Un compte sans profil est possible : la création se fait en deux
  /// temps (voir [inscription]). On répare alors le trou avec le pseudo
  /// mémorisé sur le compte, plutôt que de bloquer la connexion.
  Future<Utilisateur> _profilDe(User compte) async {
    final ligne = await _ligneProfil(compte.id);

    if (ligne != null) {
      return Utilisateur(
        id: compte.id,
        email: compte.email ?? '',
        pseudo: ligne['pseudo'] as String,
      );
    }

    final pseudoMemorise = compte.userMetadata?['pseudo'] as String?;
    if (pseudoMemorise == null) {
      throw const ErreurAuth('Profil introuvable. Contacte le support.');
    }

    // Le pseudo choisi à l'inscription a pu être pris par quelqu'un
    // d'autre entre-temps (le compte, lui, existe déjà : confirmé par
    // Supabase) — d'où un message différent de celui de l'inscription.
    await _creerProfil(
      id: compte.id,
      pseudo: pseudoMemorise,
      messageDoublon:
          'Ce pseudo est déjà pris. Contacte le support pour en choisir un '
          'autre.',
    );
    return Utilisateur(
      id: compte.id,
      email: compte.email ?? '',
      pseudo: pseudoMemorise,
    );
  }

  /// Variante de [_profilDe] pour les connexions Apple/Google : un compte
  /// sans profil n'y est pas une erreur (il n'y a pas de pseudo mémorisé
  /// possible, contrairement à l'inscription par e-mail) mais le signal
  /// qu'il faut demander un pseudo avant de continuer.
  Future<ResultatConnexionOAuth> _resultatConnexionOAuth(User compte) async {
    final ligne = await _ligneProfil(compte.id);
    if (ligne == null) {
      return ProfilAConfigurer(id: compte.id, email: compte.email ?? '');
    }
    return ConnexionOAuthReussie(
      Utilisateur(
        id: compte.id,
        email: compte.email ?? '',
        pseudo: ligne['pseudo'] as String,
      ),
    );
  }

  /// Crée la ligne `profils` d'un compte. Lance [ErreurAuth] avec
  /// [messageDoublon] si le pseudo est déjà pris par quelqu'un d'autre.
  Future<void> _creerProfil({
    required String id,
    required String pseudo,
    required String messageDoublon,
  }) async {
    try {
      await _client.from('profils').insert({'id': id, 'pseudo': pseudo});
    } on PostgrestException catch (e) {
      if (e.code == _codeDoublon) {
        throw ErreurAuth(messageDoublon);
      }
      rethrow;
    }
  }

  /// Traduit les messages de Supabase, qui sont en anglais et parfois
  /// techniques, en quelque chose de présentable.
  String _messageLisible(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login credentials')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (m.contains('already registered') || m.contains('already exists')) {
      return 'Un compte existe déjà avec cette adresse.';
    }
    if (m.contains('email not confirmed')) {
      return "Confirme d'abord ton adresse e-mail.";
    }
    if (m.contains('rate limit')) {
      return "Trop de tentatives récentes. Réessaie dans quelques minutes.";
    }
    return e.message;
  }
}
