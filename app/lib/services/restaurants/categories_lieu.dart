/// Libellés français des catégories Foursquare les plus fréquentes en
/// Belgique (les catégories sont stockées en anglais, telles que
/// fournies par l'annuaire). Une catégorie absente garde son nom
/// d'origine plutôt que de disparaître.
const Map<String, String> _libelles = {
  'Restaurant': 'Restaurant',
  'Bar': 'Bar',
  'Bakery': 'Boulangerie',
  'Friterie': 'Friterie',
  'Belgian Restaurant': 'Belge',
  'Sandwich Spot': 'Sandwicherie',
  'Lounge': 'Lounge',
  'Italian Restaurant': 'Italien',
  'Pizzeria': 'Pizzeria',
  'Snack Place': 'Snack',
  'Coffee Shop': 'Coffee shop',
  'Bistro': 'Bistrot',
  'Brasserie': 'Brasserie',
  'Café': 'Café',
  'Pub': 'Pub',
  'French Restaurant': 'Français',
  'Cafeteria': 'Cafétéria',
  'Ice Cream Parlor': 'Glacier',
  'Fast Food Restaurant': 'Fast-food',
  'Food Truck': 'Food truck',
  'Cocktail Bar': 'Bar à cocktails',
  'Tea Room': 'Salon de thé',
  'Chinese Restaurant': 'Chinois',
  'Breakfast Spot': 'Petit-déjeuner',
  'Brewery': 'Brasserie artisanale',
  'Burger Joint': 'Burger',
  'Sports Bar': 'Bar sportif',
  'Wine Bar': 'Bar à vin',
  'Asian Restaurant': 'Asiatique',
  'Dessert Shop': 'Desserts',
  'Kebab Restaurant': 'Kebab',
  'Gastropub': 'Gastropub',
  'Turkish Restaurant': 'Turc',
  'Beer Bar': 'Bar à bières',
  'BBQ Joint': 'Barbecue',
  'Sushi Restaurant': 'Sushi',
  'Deli': 'Traiteur',
  'Greek Restaurant': 'Grec',
  'Thai Restaurant': 'Thaï',
  'Diner': 'Diner',
  'Fried Chicken Joint': 'Poulet frit',
  'Doner Restaurant': 'Döner',
  'Buffet': 'Buffet',
  'Beach Bar': 'Bar de plage',
  'Steakhouse': 'Steakhouse',
  'Tapas Restaurant': 'Tapas',
  'Beer Garden': 'Biergarten',
  'Seafood Restaurant': 'Poissons et fruits de mer',
  'Vegan and Vegetarian Restaurant': 'Végétarien',
  'Salad Restaurant': 'Salades',
  'Japanese Restaurant': 'Japonais',
  'Indian Restaurant': 'Indien',
  'Middle Eastern Restaurant': 'Oriental',
  'Moroccan Restaurant': 'Marocain',
  'Mediterranean Restaurant': 'Méditerranéen',
  'Comfort Food Restaurant': 'Cuisine réconfortante',
  'Pastry Shop': 'Pâtisserie',
  'African Restaurant': 'Africain',
  'Creperie': 'Crêperie',
  'Waffle Shop': 'Gaufres',
  'Vietnamese Restaurant': 'Vietnamien',
  'Lebanese Restaurant': 'Libanais',
  'Spanish Restaurant': 'Espagnol',
  'Mexican Restaurant': 'Mexicain',
  'American Restaurant': 'Américain',
  'Poke Restaurant': 'Poké',
  'Halal Restaurant': 'Halal',
  'Korean Restaurant': 'Coréen',
  'Portuguese Restaurant': 'Portugais',
  'Modern European Restaurant': 'Européen moderne',
  'Fine Dining Restaurant': 'Gastronomique',
};

String libelleCategorie(String categorie) => _libelles[categorie] ?? categorie;

/// Version simplifiée d'un nom pour la recherche : minuscules, sans
/// accents — même résultat que `lower(unaccent(...))` côté base pour
/// les caractères courants, afin que les restaurants créés depuis l'app
/// soient retrouvables comme ceux de l'annuaire.
String normaliserPourRecherche(String texte) {
  const accents = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
    'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y',
    'œ': 'oe', 'æ': 'ae', '¡': '!', '¿': '?',
  };
  final minuscules = texte.trim().toLowerCase();
  final resultat = StringBuffer();
  for (final caractere in minuscules.split('')) {
    resultat.write(accents[caractere] ?? caractere);
  }
  return resultat.toString();
}
