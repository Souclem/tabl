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

/// Les trois façons de regarder l'Explorer.
enum ModeExplorer {
  maCarte('Ma carte', 'moi'),
  envies('Envies', 'envies'),
  cercle('Le cercle', 'cercle');

  const ModeExplorer(this.libelle, this.valeur);

  final String libelle;

  /// Valeur du paramètre `p_mode` de `lieux_carte`.
  final String valeur;
}

/// Jusqu'où remonter dans les visites.
enum PeriodeCarte {
  troisMois('3 derniers mois'),
  unAn('1 an'),
  tout('Tout');

  const PeriodeCarte(this.libelle);

  final String libelle;

  /// La première date retenue ; `null` : depuis toujours.
  DateTime? depuis(DateTime maintenant) => switch (this) {
    troisMois => DateTime(maintenant.year, maintenant.month - 3, maintenant.day),
    unAn => DateTime(maintenant.year - 1, maintenant.month, maintenant.day),
    tout => null,
  };
}

/// Les filtres de la carte, tous combinés (ET), appliqués par la base.
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
    this.periode = PeriodeCarte.tout,
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

  final PeriodeCarte periode;

  int get nombreActifs => [
    personneId != null,
    tableId != null,
    familles.isNotEmpty,
    mesEnvies,
    jamaisEssaye,
    coupsDeCoeur,
    laOuOnRevient,
    moment != null,
    periode != PeriodeCarte.tout,
  ].where((actif) => actif).length;

  /// Les catégories Foursquare des familles choisies (pour la base),
  /// `null` si aucune famille n'est choisie.
  List<String>? get categories => familles.isEmpty
      ? null
      : [for (final f in familles) ...?famillesCuisine[f]];

  FiltresCarte copierAvec({
    String? Function()? personneId,
    String? Function()? tableId,
    Set<String>? familles,
    bool? mesEnvies,
    bool? jamaisEssaye,
    bool? coupsDeCoeur,
    bool? laOuOnRevient,
    String? Function()? moment,
    PeriodeCarte? periode,
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
      periode: periode ?? this.periode,
    );
  }
}
