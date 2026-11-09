/// Les émotions d'un moment — de vrais emoji (clavier natif), jamais des
/// icônes dessinées sur mesure. On en propose 5, du pire au meilleur
/// (voir [proposees]) ; `neutre` ne sert plus qu'à relire les anciens
/// moments.
enum Emotion {
  decu('😞', 'Déçu'),
  bof('😕', 'Bof'),
  satisfait('🙂', 'Bien'),
  coupDeCoeur('😍', 'J\'adore'),
  inoubliable('🤩', 'Exceptionnel'),
  neutre('😐', 'Neutre');

  const Emotion(this.emoji, this.libelle);

  /// Les 5 émotions proposées à la finalisation, dans l'ordre d'affichage.
  /// `neutre` (ancien jeu) n'y figure plus.
  static const List<Emotion> proposees = [
    decu,
    bof,
    satisfait,
    coupDeCoeur,
    inoubliable,
  ];

  /// Le nom affiché sous l'emoji choisi.
  final String libelle;

  /// L'emoji affiché — c'est aussi la valeur stockée telle quelle en
  /// base (colonne `souvenirs.emotion`), pas de code interne séparé à
  /// tenir synchronisé.
  final String emoji;

  /// Retrouve l'émotion à partir de l'emoji stocké. `null` si absent ou
  /// non reconnu (donnée plus ancienne, ou corrompue).
  static Emotion? depuisEmoji(String? emoji) {
    if (emoji == null) return null;
    for (final valeur in Emotion.values) {
      if (valeur.emoji == emoji) return valeur;
    }
    return null;
  }
}
