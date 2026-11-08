/// Le type de média d'un Instant — photo, ou courte vidéo (megaprompt
/// Bloc 2, règle 21-22). Jamais de sélection depuis la galerie en V1.
enum TypeMediaInstant {
  photo('photo'),
  video('video');

  const TypeMediaInstant(this.valeur);

  /// La valeur telle que stockée en base (`instants.media_type`).
  final String valeur;

  static TypeMediaInstant depuisValeur(String valeur) {
    return TypeMediaInstant.values.firstWhere((v) => v.valeur == valeur);
  }
}
