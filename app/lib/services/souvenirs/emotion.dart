/// Les 4 émotions parmi lesquelles choisir en finalisant un moment — de
/// vrais emoji (clavier natif), jamais des icônes dessinées sur mesure.
/// Ensemble et ordre exacts repris du prototype fonctionnel
/// (`instruction/Clément (2)/Tabl.dc.html`, `emotionOptions`).
enum Emotion {
  coupDeCoeur('😍'),
  inoubliable('🤩'),
  satisfait('🙂'),
  neutre('😐');

  const Emotion(this.emoji);

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
