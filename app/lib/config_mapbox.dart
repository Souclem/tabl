/// Token d'accès Mapbox (carte et globe).
///
/// Public par conception (il commence par `pk.`) : il est embarqué dans
/// l'application, comme la clé Supabase. Il est malgré tout gardé hors du
/// dépôt, dans `app/.env` (ignoré par git), et fourni au lancement :
/// `flutter run --dart-define-from-file=.env`. À restreindre à
/// l'identifiant de l'app dans le compte Mapbox avant publication.
class ConfigMapbox {
  const ConfigMapbox._();

  static const String token = String.fromEnvironment('MAPBOX_TOKEN');
}
