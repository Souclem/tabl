import 'categories_lieu.dart';

/// Un restaurant tel qu'on le choisit au moment de publier (ou de le
/// proposer à une Table) : soit déjà dans Tabl ([restaurantId]), soit
/// trouvé dans l'annuaire ([fsqPlaceId]), soit saisi à la main (ni l'un
/// ni l'autre).
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
       distanceM = null;

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

  bool get estManuel => restaurantId == null && fsqPlaceId == null;

  /// "Italien · Rue du Pont 16, Liège · 350 m" — tout ce qui aide à
  /// reconnaître le bon lieu dans une liste de suggestions.
  String get description {
    final morceaux = <String>[
      if (categories.isNotEmpty) libelleCategorie(categories.first),
      [?adresse, if (ville.isNotEmpty) ville].join(', '),
      ?_distanceLisible,
    ];
    return morceaux.where((m) => m.isNotEmpty).join(' · ');
  }

  String? get _distanceLisible {
    final d = distanceM;
    if (d == null) return null;
    if (d < 1000) return '${(d / 10).round() * 10} m';
    if (d < 10000) return '${(d / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    return '${(d / 1000).round()} km';
  }
}
