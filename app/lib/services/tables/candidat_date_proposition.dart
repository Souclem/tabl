/// Une date candidate du sondage de dates, avec son agrégat de
/// disponibilités déjà calculé (megaprompt Bloc 4, règles 14-22, 67).
///
/// [disponibles]/[eligibles] sont des agrégats anonymes — on ne sait
/// jamais ici QUI est disponible, seulement combien (sauf pour le
/// creator, qui a ses propres champs sur [DetailProposition]).
class CandidatDateProposition {
  const CandidatDateProposition({
    required this.id,
    required this.date,
    required this.disponibles,
    required this.eligibles,
    required this.moiDisponible,
    required this.passee,
  });

  final String id;
  final DateTime date;
  final int disponibles;
  final int eligibles;

  /// `true` si j'ai marqué ce jour disponible dans ma dernière réponse
  /// soumise.
  final bool moiDisponible;

  /// Règle 33 : une date candidate passée devient automatiquement
  /// indisponible, ne peut plus être sélectionnée.
  final bool passee;

  /// Règle 15 : tout le monde disponible = seule date à 100%.
  bool get toutLeMondeDisponible => eligibles > 0 && disponibles == eligibles;
}
