import 'categories_lieu.dart';
import 'distance.dart';

/// Où l'on a mangé. Hors restaurant, le lieu est personnel : jamais
/// d'adresse ni de position, ni en base (contrainte
/// `lieu_personnel_sans_adresse`) ni sur aucune carte.
enum GenreLieu {
  /// Un restaurant, un café, un bar… ouvert à tous : le seul localisé.
  restaurant,

  /// Chez moi.
  domicile,

  /// Chez quelqu'un : une personne de Tabl ([LieuRestaurant.hoteId]), ou
  /// un nom (« Chez Mamie »). Les lieux personnels d'avant les genres en
  /// sont aussi.
  chez,

  /// Chez personne : pique-nique, au travail, en voyage, une fête.
  ailleurs;

  /// En base (`restaurants.genre`) ; `null` pour un restaurant.
  String? get enBase => this == restaurant ? null : name;

  /// Depuis `restaurants.genre` et `restaurants.prive`.
  static GenreLieu depuisBase(String? genre, {required bool prive}) {
    if (!prive) return restaurant;
    return values.where((g) => g.name == genre).firstOrNull ?? chez;
  }
}

/// Le nom enregistré de « Chez moi » : chacun le lit à sa façon (voir
/// [libelleLieu]).
const nomDomicile = 'Chez moi';

/// Le nom enregistré chez une personne de Tabl : on lit son pseudo tant
/// qu'elle est liée, « Chez quelqu'un » si elle a retiré son nom.
const nomChezQuelquun = 'Chez quelqu\'un';

final _chezEnTete = RegExp(r'^chez\b\s*', caseSensitive: false);

/// « Mamie », « chez mes parents » → « Chez Mamie », « Chez mes
/// parents » : quelqu'un qui n'est pas sur Tabl, juste un nom.
String nomChezHorsTabl(String saisie) =>
    'Chez ${saisie.trim().replaceFirst(_chezEnTete, '')}';

/// Sous un rond « Chez qui ? » : « Chez Mamie » → « Mamie ».
String nomSansChez(String nom) {
  final reste = nom.trim().replaceFirst(_chezEnTete, '');
  if (reste.isEmpty) return nom.trim();
  return reste[0].toUpperCase() + reste.substring(1);
}

/// Le nom d'un lieu personnel : `null` s'il va, sinon le message.
String? erreurNomLieuPersonnel(String nom) {
  final n = nom.trim();
  if (n.isEmpty) return 'Donnez-lui un nom.';
  if (n.length > 60) return '60 caractères au plus.';
  return null;
}

/// Un lieu personnel écrit à la main, dans la feuille « Où et quand » :
/// chez quelqu'un hors Tabl (« Mamie » → « Chez Mamie ») ou ailleurs
/// (« Au bord du lac »). Le même nom qu'un de [mesLieux] du même genre :
/// c'est lui. Sinon [erreur] dit ce qui ne va pas.
({LieuRestaurant? lieu, String? erreur}) lieuPersonnelSaisi(
  String saisie,
  GenreLieu genre, {
  List<LieuRestaurant> mesLieux = const [],
}) {
  final chez = genre == GenreLieu.chez;
  final erreur = erreurNomLieuPersonnel(
    chez ? saisie.trim().replaceFirst(_chezEnTete, '') : saisie,
  );
  if (erreur != null) return (lieu: null, erreur: erreur);
  final nom = chez ? nomChezHorsTabl(saisie) : saisie.trim();
  final existant = mesLieux.where(
    (l) =>
        l.genre == genre &&
        l.hoteId == null &&
        normaliserPourRecherche(l.nom) == normaliserPourRecherche(nom),
  );
  return (
    lieu:
        existant.firstOrNull ??
        LieuRestaurant.personnel(nom: nom, genre: genre),
    erreur: null,
  );
}

/// Les « chez personne » proposés d'office.
const lieuxAilleurs = ['Pique-nique', 'Au travail', 'En voyage', 'Une fête'];

/// Le lieu d'un moment tel qu'on le lit : « Chez vous » pour soi,
/// « Chez Léa » pour les autres ; chez une personne de Tabl, son
/// pseudo (« Chez vous » pour elle) ; sinon le nom enregistré.
String libelleLieu({
  required GenreLieu genre,
  required String nom,
  String? hotePseudo,
  bool hoteEstMoi = false,
  String? auteurPseudo,
  bool auteurEstMoi = false,
}) {
  switch (genre) {
    case GenreLieu.domicile:
      if (auteurEstMoi) return 'Chez vous';
      final auteur = auteurPseudo?.trim() ?? '';
      return auteur.isEmpty ? nom : 'Chez $auteur';
    case GenreLieu.chez:
      if (hoteEstMoi) return 'Chez vous';
      final hote = hotePseudo?.trim() ?? '';
      return hote.isEmpty ? nom : 'Chez $hote';
    case GenreLieu.restaurant:
    case GenreLieu.ailleurs:
      return nom;
  }
}

/// La fin d'une phrase sur mon moment (« Emma a aimé votre moment
/// chez Bibo ») : « chez Bibo », « chez vous », « chez Mamie » ; `null`
/// quand aucune tournure ne va (un pique-nique, ou pas de lieu).
String? chezDansUnePhrase(String? nom, String? genre) {
  final n = nom?.trim() ?? '';
  if (n.isEmpty) return null;
  switch (genre) {
    case 'domicile':
      return 'chez vous';
    case 'ailleurs':
      return null;
  }
  // « Chez Mamie », « Chez quelqu'un » : le « chez » y est déjà.
  final sansChez = RegExp(r'^chez\s+', caseSensitive: false);
  if (sansChez.hasMatch(n)) return 'chez ${n.replaceFirst(sansChez, '')}';
  return 'chez $n';
}

/// Un lieu tel qu'on le choisit au moment de publier (ou de le proposer
/// à une Table) : un restaurant déjà dans Tabl ([restaurantId]), trouvé
/// dans l'annuaire ([fsqPlaceId]) ou saisi à la main (ni l'un ni
/// l'autre) ; ou un lieu personnel ([genre] autre que restaurant).
class LieuRestaurant {
  const LieuRestaurant({
    required this.nom,
    required this.ville,
    this.restaurantId,
    this.fsqPlaceId,
    this.adresse,
    this.latitude,
    this.longitude,
    this.categories = const [],
    this.distanceM,
    this.genre = GenreLieu.restaurant,
    this.hoteId,
    this.hotePseudo,
    this.hotePhotoUrl,
  });

  /// Un restaurant introuvable, ajouté à la main.
  const LieuRestaurant.manuel({
    required this.nom,
    required this.ville,
    this.latitude,
    this.longitude,
  }) : restaurantId = null,
       fsqPlaceId = null,
       adresse = null,
       categories = const [],
       distanceM = null,
       genre = GenreLieu.restaurant,
       hoteId = null,
       hotePseudo = null,
       hotePhotoUrl = null;

  /// Un lieu à soi (« Chez mes parents », « Pique-nique ») : son nom se
  /// lit sur les moments qu'on y a, jamais son adresse ni sa position —
  /// il n'en a pas.
  const LieuRestaurant.personnel({
    required this.nom,
    this.restaurantId,
    this.genre = GenreLieu.chez,
    this.hoteId,
    this.hotePseudo,
    this.hotePhotoUrl,
  }) : ville = '',
       fsqPlaceId = null,
       adresse = null,
       latitude = null,
       longitude = null,
       categories = const [],
       distanceM = null;

  /// Chez moi.
  const LieuRestaurant.domicile({String? restaurantId})
    : this.personnel(
        nom: nomDomicile,
        restaurantId: restaurantId,
        genre: GenreLieu.domicile,
      );

  /// Chez une personne de Tabl que je suis.
  const LieuRestaurant.chezQuelquun({
    required String hoteId,
    required String hotePseudo,
    String? hotePhotoUrl,
    String? restaurantId,
  }) : this.personnel(
         nom: nomChezQuelquun,
         restaurantId: restaurantId,
         hoteId: hoteId,
         hotePseudo: hotePseudo,
         hotePhotoUrl: hotePhotoUrl,
       );

  final String nom;
  final String ville;

  /// Déjà entré dans Tabl : on réutilise cette ligne telle quelle.
  final String? restaurantId;

  /// Identifiant Foursquare OS Places : évite tout doublon quand deux
  /// personnes choisissent le même lieu de l'annuaire.
  final String? fsqPlaceId;

  final String? adresse;
  final double? latitude;
  final double? longitude;

  /// Catégories Foursquare telles qu'en base ("Italian Restaurant").
  final List<String> categories;

  /// Distance depuis la position de l'utilisateur, si connue.
  final double? distanceM;

  /// Restaurant, chez moi, chez quelqu'un, ailleurs.
  final GenreLieu genre;

  /// Chez une personne de Tabl : son profil, son pseudo et sa photo (ce
  /// que lit la feuille et l'en-tête ; en base, seul l'identifiant).
  final String? hoteId;
  final String? hotePseudo;
  final String? hotePhotoUrl;

  /// Hors restaurant : jamais localisé.
  bool get personnel => genre != GenreLieu.restaurant;

  /// Tel que je le lis, moi qui publie : « Chez vous », « Chez Emma »,
  /// « Bibo ».
  String get libelle => libelleLieu(
    genre: genre,
    nom: nom,
    hotePseudo: hotePseudo,
    auteurEstMoi: true,
  );

  bool get estManuel =>
      restaurantId == null && fsqPlaceId == null && !personnel;

  /// Le même lieu, avec sa distance à [latitude], [longitude] (l'endroit
  /// d'une photo, plutôt que le téléphone) ; inchangé sans position.
  LieuRestaurant aDistanceDe(double latitude, double longitude) {
    final lat = this.latitude, lng = this.longitude;
    if (lat == null || lng == null || personnel) return this;
    return LieuRestaurant(
      nom: nom,
      ville: ville,
      restaurantId: restaurantId,
      fsqPlaceId: fsqPlaceId,
      adresse: adresse,
      latitude: lat,
      longitude: lng,
      categories: categories,
      distanceM: distanceEnMetres(latitude, longitude, lat, lng),
    );
  }

  /// Ce qui le distingue des autres, même entré à la main. Un lieu
  /// personnel se reconnaît à son genre et à son hôte (ou son nom), qu'il
  /// soit déjà enregistré ou non : « Chez moi » est toujours « Chez moi ».
  String get cle => personnel
      ? 'perso|${genre.name}|${hoteId ?? nom.trim().toLowerCase()}'
      : restaurantId ?? fsqPlaceId ?? '$nom|$ville|$latitude|$longitude';

  /// "Italien · Rue du Pont 16, Liège · 350 m" — tout ce qui aide à
  /// reconnaître le bon lieu dans une liste de suggestions.
  String get description {
    final morceaux = <String>[
      if (categories.isNotEmpty) libelleCategorie(categories.first),
      [?adresse, if (ville.isNotEmpty) ville].join(', '),
      if (distanceM != null) distanceLisible(distanceM!),
    ];
    return morceaux.where((m) => m.isNotEmpty).join(' · ');
  }
}
