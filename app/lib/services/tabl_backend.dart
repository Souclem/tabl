import 'package:supabase_flutter/supabase_flutter.dart';

/// Point d'entrée du backend.
///
/// À appeler une fois au démarrage, avant `runApp`. Le SDK Supabase
/// restaure au passage la session enregistrée sur le téléphone : un
/// utilisateur déjà connecté n'a pas à ressaisir son mot de passe.
class TablBackend {
  const TablBackend._();

  static Future<void> demarrer({
    required String url,
    required String clePubliable,
  }) async {
    await Supabase.initialize(url: url, publishableKey: clePubliable);
    _demarre = true;
  }

  static bool _demarre = false;

  /// `true` une fois [demarrer] appelé — jamais pendant les tests, où
  /// Supabase n'est pas initialisé.
  static bool get estDemarre => _demarre;

  /// Le client Supabase, une fois [demarrer] appelé.
  static SupabaseClient get client => Supabase.instance.client;

  /// La session en cours, ou `null` si personne n'est connecté.
  static Session? get session => client.auth.currentSession;
}
