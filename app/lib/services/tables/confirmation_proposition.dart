/// Date (et éventuellement heure) confirmées d'une proposition
/// (megaprompt Bloc 4, règles 34-37, 63).
class ConfirmationProposition {
  const ConfirmationProposition({
    required this.date,
    required this.heure,
    required this.fuseauHoraire,
  });

  final DateTime date;

  /// `null` = date confirmée mais "Heure à confirmer" (règle 36).
  /// Format "HH:mm", en heure locale du [fuseauHoraire], jamais celle du
  /// téléphone du lecteur (règle 63).
  final String? heure;

  final String fuseauHoraire;
}
