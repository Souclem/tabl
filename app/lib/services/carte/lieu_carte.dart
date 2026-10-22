import '../restaurants/categories_lieu.dart';

/// Un lieu de la carte, déjà résumé par la base : un restaurant où au
/// moins un de mes amis est allé. Les chiffres tiennent déjà compte des
/// filtres de la recherche qui l'a renvoyé.
class LieuCarte {
  const LieuCarte({
    required this.nom,
    required this.ville,
    required this.latitude,
    required this.longitude,
    this.restaurantId,
    this.fsqPlaceId,
    this.adresse,
    this.categories = const [],
    this.amis = 0,
    this.visites = 0,
    this.coupsDeCoeur = 0,
    this.visiteParMoi = false,
    this.estEnvie = false,
    this.amiPseudo,
  });

  final String nom;
  final String ville;
  final double latitude;
  final double longitude;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire.
  final String? restaurantId;
  final String? fsqPlaceId;
  final String? adresse;
  final List<String> categories;

  /// Amis différents qui y sont allés (moi exclu).
  final int amis;

  /// Visites de mon réseau, les miennes comprises.
  final int visites;

  /// Visites notées 😍.
  final int coupsDeCoeur;
  final bool visiteParMoi;

  /// Dans mes envies.
  final bool estEnvie;

  /// L'ami mis en avant (celui qui y est allé le plus souvent).
  final String? amiPseudo;

  /// Identifiant stable sur la carte, quelle que soit l'origine du lieu.
  String get cle => restaurantId ?? 'fsq:$fsqPlaceId';

  /// Visité par mon réseau ou mis en envie — par opposition aux simples
  /// points de l'annuaire.
  bool get duReseau => visites > 0 || estEnvie;

  /// L'ami mis en avant, et le nombre d'autres amis qui y sont allés.
  /// `null` si aucun ami n'y est allé.
  ({String pseudo, int autres})? get amiEnAvant {
    final pseudo = amiPseudo;
    if (pseudo == null || amis == 0) return null;
    return (pseudo: pseudo, autres: amis - 1);
  }

  /// "Italien · Rue du Pont 16, Liège".
  String get description {
    final morceaux = [
      if (categories.isNotEmpty) libelleCategorie(categories.first),
      [?adresse, if (ville.isNotEmpty) ville].join(', '),
    ];
    return morceaux.where((m) => m.isNotEmpty).join(' · ');
  }

  /// "Emma et 2 autres y sont allés" / "Vous y êtes allé" — jamais un
  /// chiffre seul, comme sur le Feed.
  String get resumeVisites {
    final ami = amiEnAvant;
    if (ami == null) {
      if (visiteParMoi) return 'Vous y êtes allé';
      return estEnvie
          ? 'Dans vos envies'
          : 'Personne de votre réseau n\'y est allé';
    }
    final qui = ami.autres == 0
        ? ami.pseudo
        : '${ami.pseudo} et ${ami.autres} autre${ami.autres > 1 ? 's' : ''}';
    if (visiteParMoi) return '$qui et vous y êtes allés';
    return '$qui ${ami.autres == 0 ? 'y est allé' : 'y sont allés'}';
  }

  /// Le même lieu, entré dans Tabl et/ou avec une envie changée.
  LieuCarte copierAvec({String? restaurantId, bool? estEnvie}) {
    return LieuCarte(
      nom: nom,
      ville: ville,
      latitude: latitude,
      longitude: longitude,
      restaurantId: restaurantId ?? this.restaurantId,
      fsqPlaceId: fsqPlaceId,
      adresse: adresse,
      categories: categories,
      amis: amis,
      visites: visites,
      coupsDeCoeur: coupsDeCoeur,
      visiteParMoi: visiteParMoi,
      estEnvie: estEnvie ?? this.estEnvie,
      amiPseudo: amiPseudo,
    );
  }
}

/// Une zone rectangulaire de la carte (ce qui est visible à l'écran).
class ZoneCarte {
  const ZoneCarte({
    required this.sud,
    required this.ouest,
    required this.nord,
    required this.est,
  });

  /// Toute la Terre.
  static const monde = ZoneCarte(sud: -90, ouest: -180, nord: 90, est: 180);

  final double sud;
  final double ouest;
  final double nord;
  final double est;
}
