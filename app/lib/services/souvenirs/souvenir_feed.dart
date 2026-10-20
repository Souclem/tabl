import 'emotion.dart';
import 'personne_presente.dart';

/// Un souvenir tel qu'affiché dans le Feed — déjà résolu et prêt à
/// afficher (l'URL de la photo est une URL signée, pas le chemin brut du
/// bucket) : l'écran n'a aucune requête à faire, juste à afficher.
class SouvenirFeed {
  const SouvenirFeed({
    required this.id,
    required this.photoUrl,
    required this.legende,
    required this.restaurantNom,
    required this.ville,
    required this.moment,
    required this.dateVisite,
    required this.auteurPseudo,
    required this.nombreReactions,
    required this.jaiReagi,
    required this.nombreCommentaires,
    this.emotion,
    this.premieresReactions = const [],
    this.presents = const [],
    this.categories = const [],
    this.impressions = const [],
    this.estAMoi = false,
    this.audienceRestreinte = false,
    this.restaurantId,
    this.estEnvie = false,
    this.auteurPhotoUrl,
    this.auteurId,
  });

  final String id;

  /// L'auteur, pour ouvrir son profil.
  final String? auteurId;

  /// `null` si le souvenir n'a pas de photo, ou si l'URL n'a pas pu être
  /// résolue (fichier introuvable côté bucket).
  final String? photoUrl;

  final String? legende;
  final String restaurantNom;
  final String ville;

  /// `'midi'` ou `'soir'`, tel qu'enregistré en base.
  final String moment;

  final DateTime dateVisite;
  final String auteurPseudo;

  final int nombreReactions;

  /// `true` si le compte courant a réagi à ce souvenir.
  final bool jaiReagi;

  final int nombreCommentaires;

  /// `null` pour un souvenir publié avant l'introduction de ce champ.
  final Emotion? emotion;

  /// Pseudos des personnes ayant réagi le plus récemment — sert à
  /// composer la phrase "Martin, Sarah et 12 autres ont aimé" plutôt
  /// qu'un chiffre brut mis en avant.
  final List<String> premieresReactions;

  /// Les personnes taguées comme présentes lors de ce moment.
  final List<PersonnePresente> presents;

  /// Catégories du restaurant, telles que l'annuaire les fournit (en
  /// anglais : "Italian Restaurant") — à traduire avec
  /// `libelleCategorie` pour l'affichage.
  final List<String> categories;

  /// Ce qui ressort ("Assiette · Exceptionnelle", "Service · Attentionné"...),
  /// affiché en pastilles sous la légende.
  final List<String> impressions;

  /// `true` si le compte courant est l'auteur — sert au CTA "+ Instant"
  /// (megaprompt Bloc 2, règle 3 : owner only, les autres ne le voient
  /// jamais).
  final bool estAMoi;

  /// `true` si l'audience n'est pas "Tout le monde" — n'est renseigné
  /// que pour ses propres publications (l'audience des autres ne nous
  /// regarde pas), pour le petit cadenas à côté de la date.
  final bool audienceRestreinte;

  final String? restaurantId;

  /// Photo de profil de l'auteur, `null` s'il n'en a pas.
  final String? auteurPhotoUrl;

  /// Le restaurant est dans mes envies ("Enregistrer").
  final bool estEnvie;

  /// Nouvelle instance avec certains champs remplacés — pour la mise à
  /// jour optimiste après une action (réagir, commenter), sans recharger
  /// tout le Feed.
  SouvenirFeed copierAvec({
    int? nombreReactions,
    bool? jaiReagi,
    int? nombreCommentaires,
    List<String>? premieresReactions,
    bool? estEnvie,
  }) {
    return SouvenirFeed(
      id: id,
      photoUrl: photoUrl,
      legende: legende,
      restaurantNom: restaurantNom,
      ville: ville,
      moment: moment,
      dateVisite: dateVisite,
      auteurPseudo: auteurPseudo,
      nombreReactions: nombreReactions ?? this.nombreReactions,
      jaiReagi: jaiReagi ?? this.jaiReagi,
      nombreCommentaires: nombreCommentaires ?? this.nombreCommentaires,
      emotion: emotion,
      premieresReactions: premieresReactions ?? this.premieresReactions,
      presents: presents,
      categories: categories,
      impressions: impressions,
      estAMoi: estAMoi,
      audienceRestreinte: audienceRestreinte,
      restaurantId: restaurantId,
      auteurId: auteurId,
      estEnvie: estEnvie ?? this.estEnvie,
      auteurPhotoUrl: auteurPhotoUrl,
    );
  }
}
