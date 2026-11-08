/// Identifiants des fournisseurs OAuth tiers (Apple, Google).
///
/// Comme [ConfigSupabase], ces valeurs sont **publiques par conception** :
/// un Client ID OAuth identifie l'application, il n'autorise rien à lui
/// seul (contrairement au secret du client Web, qui lui ne doit jamais
/// apparaître ici — voir le dashboard Supabase, seul endroit où il est
/// utilisé).
class ConfigOAuth {
  const ConfigOAuth._();

  /// Client ID iOS du projet Google Cloud "table-506417" (type "iOS",
  /// bundle id `be.tabl.app`). Utilisé par `google_sign_in` pour initier
  /// le flux.
  static const String googleClientIdIOS = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_IOS',
    defaultValue:
        '575572985631-f7jb8is9uauv0khhk4h71h2addrj4hv6.apps.googleusercontent.com',
  );

  /// Client ID "Web application" du même projet Google Cloud. Sert de
  /// `serverClientId` côté Flutter et doit être le même que le "Client ID"
  /// configuré dans le dashboard Supabase (Authentication > Providers >
  /// Google) : c'est l'audience que Supabase vérifie dans l'ID token.
  static const String googleClientIdWeb = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_WEB',
    defaultValue:
        '575572985631-cinbaj4mip7taqkvdbr7c2dv1pak470o.apps.googleusercontent.com',
  );
}
