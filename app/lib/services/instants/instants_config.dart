/// Constantes du Bloc Instants (megaprompt, règle 4, 5, 29) — nommées et
/// centralisées plutôt qu'éparpillées en littéraux, pour rester faciles
/// à faire évoluer en configuration distante si un jour cette
/// infrastructure existe (aucune aujourd'hui dans le projet).
class InstantsConfig {
  const InstantsConfig._();

  /// `instant_creation_window_hours`.
  static const fenetreCreation = Duration(hours: 6);

  /// `instant_max_per_experience`.
  static const maxParExperience = 6;

  /// Durée de visibilité sociale d'un Instant, à partir de SA création
  /// (règle 5) — pas de celle du parent.
  static const dureeVisibiliteSociale = Duration(hours: 24);

  /// Durée maximale d'une vidéo capturée (règle 22).
  static const dureeMaxVideo = Duration(seconds: 10);
}
