import 'package:supabase_flutter/supabase_flutter.dart';

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
  Future<Utilisateur> inscription({
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
    // les règles d'accès bloqueraient l'écriture du profil.
    if (reponse.session == null) {
      throw const ErreurAuth(
        'Compte créé. Confirme ton adresse e-mail, puis connecte-toi.',
      );
    }

    try {
      await _client.from('profils').insert({
        'id': compte.id,
        'pseudo': pseudo,
      });
    } on PostgrestException catch (e) {
      if (e.code == _codeDoublon) {
        throw const ErreurAuth('Ce pseudo est déjà pris.');
      }
      rethrow;
    }

    return Utilisateur(id: compte.id, email: compte.email ?? email, pseudo: pseudo);
  }

  /// Récupère le profil associé à un compte.
  ///
  /// Un compte sans profil est possible : la création se fait en deux
  /// temps (voir [inscription]). On répare alors le trou avec le pseudo
  /// mémorisé sur le compte, plutôt que de bloquer la connexion.
  Future<Utilisateur> _profilDe(User compte) async {
    final ligne = await _client
        .from('profils')
        .select('pseudo')
        .eq('id', compte.id)
        .maybeSingle();

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

    await _client.from('profils').insert({
      'id': compte.id,
      'pseudo': pseudoMemorise,
    });
    return Utilisateur(
      id: compte.id,
      email: compte.email ?? '',
      pseudo: pseudoMemorise,
    );
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
    return e.message;
  }
}
