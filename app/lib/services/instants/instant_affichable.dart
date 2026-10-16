import 'type_media_instant.dart';

/// Un Instant tel qu'affiché dans le viewer — déjà résolu (URL signée),
/// prêt à afficher, aucune requête supplémentaire à faire.
class InstantAffichable {
  const InstantAffichable({
    required this.id,
    required this.mediaUrl,
    required this.type,
    required this.creeLe,
    required this.estMoi,
  });

  final String id;
  final String mediaUrl;
  final TypeMediaInstant type;
  final DateTime creeLe;

  /// `true` si le compte courant est le propriétaire — donne accès au
  /// menu de suppression (règle 61 : owner et viewer ne voient jamais le
  /// même menu).
  final bool estMoi;
}
