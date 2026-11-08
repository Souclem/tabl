/// Un message du mini-chat "Organisation" (megaprompt Bloc 4, règles
/// 38-48) : texte seul, jamais de pièce jointe, jamais de statut "vu"
/// (règle 46).
class MessageOrganisation {
  const MessageOrganisation({
    required this.id,
    required this.auteurId,
    required this.auteurPseudo,
    required this.contenu,
    required this.creeLe,
    required this.parMoi,
  });

  final String id;
  final String auteurId;
  final String auteurPseudo;
  final String contenu;
  final DateTime creeLe;
  final bool parMoi;
}
