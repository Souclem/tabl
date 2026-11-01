/// Un commentaire sur un souvenir, ou une réponse à un commentaire.
class Commentaire {
  const Commentaire({
    required this.id,
    required this.texte,
    required this.creeLe,
    required this.auteurPseudo,
    required this.estLeMien,
    this.auteurId,
    this.auteurPhotoUrl,
    this.parentId,
    this.nombreJaime = 0,
    this.jaiAime = false,
  });

  final String id;
  final String texte;
  final DateTime creeLe;

  /// Pour ouvrir son profil.
  final String? auteurId;
  final String auteurPseudo;

  /// Miniature de sa photo de profil, `null` s'il n'en a pas.
  final String? auteurPhotoUrl;

  /// `true` si le compte courant en est l'auteur — permet à l'écran de
  /// n'afficher l'action "supprimer" que sur ses propres commentaires.
  final bool estLeMien;

  /// Le commentaire auquel celui-ci répond ; `null` : il répond au
  /// moment lui-même. Un seul niveau : jamais la réponse d'une réponse.
  final String? parentId;

  final int nombreJaime;

  /// `true` si le compte courant l'a aimé.
  final bool jaiAime;

  /// Le commentaire d'où part son fil : lui-même, ou celui auquel il
  /// répond. Répondre à une réponse, c'est répondre à ce fil.
  String get filId => parentId ?? id;

  Commentaire copierAvec({int? nombreJaime, bool? jaiAime}) => Commentaire(
    id: id,
    texte: texte,
    creeLe: creeLe,
    auteurPseudo: auteurPseudo,
    estLeMien: estLeMien,
    auteurId: auteurId,
    auteurPhotoUrl: auteurPhotoUrl,
    parentId: parentId,
    nombreJaime: nombreJaime ?? this.nombreJaime,
    jaiAime: jaiAime ?? this.jaiAime,
  );
}

/// Un commentaire et les réponses qu'il a reçues.
class FilCommentaire {
  const FilCommentaire({required this.commentaire, this.reponses = const []});

  final Commentaire commentaire;

  /// De la plus ancienne à la plus récente.
  final List<Commentaire> reponses;
}

/// Les commentaires d'un moment rangés en fils : chacun suivi de ses
/// réponses, les uns et les autres du plus ancien au plus récent (on
/// lit une conversation). Une réponse dont le commentaire n'est pas
/// là (supprimé entre-temps) n'est pas montrée.
List<FilCommentaire> filsDeCommentaires(List<Commentaire> commentaires) {
  int parDate(Commentaire a, Commentaire b) => a.creeLe.compareTo(b.creeLe);
  final reponses = <String, List<Commentaire>>{};
  for (final c in commentaires) {
    final parent = c.parentId;
    if (parent != null) reponses.putIfAbsent(parent, () => []).add(c);
  }
  return [
    for (final c in [
      for (final c in commentaires)
        if (c.parentId == null) c,
    ]..sort(parDate))
      FilCommentaire(
        commentaire: c,
        reponses: (reponses[c.id] ?? <Commentaire>[])..sort(parDate),
      ),
  ];
}

/// Les commentaires après un j'aime donné ou retiré sur l'un d'eux
/// ([commentaireId]) : son compte suit, le reste ne bouge pas.
List<Commentaire> apresJaimeCommentaire(
  List<Commentaire> commentaires,
  String commentaireId, {
  required bool aimer,
}) => [
  for (final c in commentaires)
    if (c.id == commentaireId && c.jaiAime != aimer)
      c.copierAvec(
        jaiAime: aimer,
        nombreJaime: c.nombreJaime + (aimer ? 1 : -1),
      )
    else
      c,
];
