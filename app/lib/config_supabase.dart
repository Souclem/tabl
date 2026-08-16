/// Coordonnées du projet Supabase.
///
/// Ces deux valeurs sont **publiques par conception** : elles sont
/// embarquées dans l'application installée sur les téléphones, donc
/// lisibles par quiconque décompile l'APK. Ce n'est pas une faille —
/// ce qui protège les données, ce sont les règles d'accès (RLS)
/// écrites sur les tables, pas le secret de cette clé.
///
/// En revanche, la clé `service_role` (ou `sb_secret_...`) du tableau de
/// bord Supabase contourne toutes les règles d'accès : elle ne doit
/// JAMAIS se retrouver ici ni dans le dépôt.
class ConfigSupabase {
  const ConfigSupabase._();

  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://rbxqkgbgebijrlaxrril.supabase.co',
  );

  static const String clePubliable = String.fromEnvironment(
    'SUPABASE_CLE',
    defaultValue: 'sb_publishable_WbGmlz3NwiymI5vpXpvP9g_w5l9EHjT',
  );
}
