import 'lieu_carte.dart';

/// Les familles de cuisine proposées dans le filtre "Cuisine" : les
/// catégories Foursquare sont trop nombreuses (des centaines) pour être
/// proposées telles quelles.
const Map<String, Set<String>> famillesCuisine = {
  'Belge et française': {
    'Belgian Restaurant',
    'French Restaurant',
    'Friterie',
    'Modern European Restaurant',
    'Fine Dining Restaurant',
  },
  'Brasserie et bistrot': {'Brasserie', 'Bistro', 'Gastropub', 'Diner'},
  'Italienne et pizza': {'Italian Restaurant', 'Pizzeria'},
  'Asiatique': {
    'Asian Restaurant',
    'Chinese Restaurant',
    'Japanese Restaurant',
    'Sushi Restaurant',
    'Thai Restaurant',
    'Vietnamese Restaurant',
    'Korean Restaurant',
    'Indian Restaurant',
    'Poke Restaurant',
  },
  'Orientale': {
    'Middle Eastern Restaurant',
    'Lebanese Restaurant',
    'Turkish Restaurant',
    'Moroccan Restaurant',
    'Kebab Restaurant',
    'Doner Restaurant',
    'Falafel Restaurant',
    'Halal Restaurant',
  },
  'Méditerranéenne': {
    'Mediterranean Restaurant',
    'Greek Restaurant',
    'Spanish Restaurant',
    'Tapas Restaurant',
    'Portuguese Restaurant',
    'Seafood Restaurant',
  },
  'Américaine et burger': {
    'Burger Joint',
    'American Restaurant',
    'BBQ Joint',
    'Steakhouse',
    'Fried Chicken Joint',
    'Fast Food Restaurant',
  },
  'Mexicaine et latino': {
    'Mexican Restaurant',
    'Taco Restaurant',
    'Latin American Restaurant',
  },
  'Africaine': {'African Restaurant'},
  'Végétarienne': {'Vegan and Vegetarian Restaurant', 'Salad Restaurant'},
  'Café et sucré': {
    'Café',
    'Coffee Shop',
    'Tea Room',
    'Bakery',
    'Pastry Shop',
    'Dessert Shop',
    'Ice Cream Parlor',
    'Waffle Shop',
    'Creperie',
    'Breakfast Spot',
  },
  'Bar': {
    'Bar',
    'Pub',
    'Cocktail Bar',
    'Wine Bar',
    'Beer Bar',
    'Lounge',
    'Sports Bar',
    'Brewery',
    'Beer Garden',
  },
};

/// Les filtres de la carte, tous combinés (ET). Les filtres "réseau"
/// (une personne, une Table, coups de cœur, là où on revient, midi/soir)
/// portent sur les visites de mon réseau : ils masquent d'office les
/// lieux de l'annuaire, où personne n'est allé.
class FiltresCarte {
  const FiltresCarte({
    this.personneId,
    this.tableId,
    this.familles = const {},
    this.mesEnvies = false,
    this.jamaisEssaye = false,
    this.coupsDeCoeur = false,
    this.laOuOnRevient = false,
    this.moment,
  });

  static const aucun = FiltresCarte();

  /// Une personne précise (auteur des visites).
  final String? personneId;

  /// Les sorties partagées dans cette Table.
  final String? tableId;

  /// Familles de cuisine ([famillesCuisine]) — au moins une doit
  /// correspondre.
  final Set<String> familles;

  final bool mesEnvies;

  /// Où je ne suis jamais allé moi-même.
  final bool jamaisEssaye;

  /// Visites notées 😍.
  final bool coupsDeCoeur;

  /// Au moins deux visites (qui correspondent aux autres filtres).
  final bool laOuOnRevient;

  /// `'midi'` ou `'soir'`.
  final String? moment;

  bool get _filtreVisites =>
      personneId != null ||
      tableId != null ||
      coupsDeCoeur ||
      laOuOnRevient ||
      moment != null;

  /// Les points de l'annuaire restent visibles : aucun filtre ne les
  /// exclut par nature.
  bool get annuaireVisible => !_filtreVisites && !mesEnvies;

  int get nombreActifs => [
    personneId != null,
    tableId != null,
    familles.isNotEmpty,
    mesEnvies,
    jamaisEssaye,
    coupsDeCoeur,
    laOuOnRevient,
    moment != null,
  ].where((actif) => actif).length;

  /// Les catégories Foursquare des familles choisies (pour la base),
  /// `null` si aucune famille n'est choisie.
  List<String>? get categories => familles.isEmpty
      ? null
      : [for (final f in familles) ...?famillesCuisine[f]];

  /// Un lieu de l'annuaire passe-t-il les filtres ? (Les lieux de mon
  /// réseau arrivent déjà filtrés par la base.) Personne de mon réseau
  /// n'y est allé : seuls la cuisine et l'absence de filtre "réseau"
  /// comptent.
  bool gardeAnnuaire(LieuCarte lieu) {
    if (!annuaireVisible) return false;
    final choisies = categories;
    return choisies == null || lieu.categories.any(choisies.contains);
  }

  FiltresCarte copierAvec({
    String? Function()? personneId,
    String? Function()? tableId,
    Set<String>? familles,
    bool? mesEnvies,
    bool? jamaisEssaye,
    bool? coupsDeCoeur,
    bool? laOuOnRevient,
    String? Function()? moment,
  }) {
    return FiltresCarte(
      personneId: personneId != null ? personneId() : this.personneId,
      tableId: tableId != null ? tableId() : this.tableId,
      familles: familles ?? this.familles,
      mesEnvies: mesEnvies ?? this.mesEnvies,
      jamaisEssaye: jamaisEssaye ?? this.jamaisEssaye,
      coupsDeCoeur: coupsDeCoeur ?? this.coupsDeCoeur,
      laOuOnRevient: laOuOnRevient ?? this.laOuOnRevient,
      moment: moment != null ? moment() : this.moment,
    );
  }
}
