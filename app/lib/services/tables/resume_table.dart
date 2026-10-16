/// Une Table telle qu'affichée sur la home "Vos Tables" (megaprompt Bloc 3,
/// règles 5-9) : visuel + nom + nombre de membres + UNE seule information
/// utile, jamais une accumulation de compteurs sur la même row.
class ResumeTable {
  const ResumeTable({
    required this.id,
    required this.nom,
    required this.nombreMembres,
    required this.etatTexte,
    required this.actionRequise,
    this.emoji,
    this.couverturePhotoUrl,
    this.mosaiquePhotosUrls = const [],
  });

  final String id;
  final String nom;
  final String? emoji;

  /// Gagne toujours sur la mosaïque si présente (règle 11-12).
  final String? couverturePhotoUrl;

  /// Déjà réduite au nécessaire (0/1/2/3/4-6 images) par le service — la
  /// row affiche une version compacte de la même sélection que l'en-tête
  /// de la Table, pour rester stable (règle 16).
  final List<String> mosaiquePhotosUrls;

  final int nombreMembres;

  /// La seule information utile sélectionnée par priorité (règle 7-8),
  /// déjà en langage humain — ex. "À vous de voter", "3 propositions",
  /// "Rien de nouveau".
  final String etatTexte;

  /// `true` si [etatTexte] réclame une action de l'utilisateur (règle 9 :
  /// un texte plus fort plutôt qu'un empilement de badges) — pilote
  /// uniquement le poids visuel du texte, jamais une couleur/glow.
  final bool actionRequise;
}
