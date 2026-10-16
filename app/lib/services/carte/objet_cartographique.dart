/// Les 4 objets cartographiques de l'Explorer — quatre types
/// techniquement et visuellement distincts, jamais ambigus (megaprompt
/// Bloc 1, règle 2). Un point individuel est toujours un restaurant,
/// jamais un ami, une visite, une émotion ou un avis (règle 1).
sealed class ObjetCartographique {
  const ObjetCartographique();
}

/// Taille d'un [RestaurantMarqueur] — jamais un chiffre exact affiché,
/// seulement l'une de ces 3 tailles (règle 4). Liée au nombre de proches
/// directs pertinents pour la période en cours : 1 → [small],
/// 2 ou 3 → [medium], 4 et plus → [large].
enum TailleMarqueur { small, medium, large }

TailleMarqueur tailleMarqueurDepuisCompte(int procheDirectCompte) {
  if (procheDirectCompte >= 4) return TailleMarqueur.large;
  if (procheDirectCompte >= 2) return TailleMarqueur.medium;
  return TailleMarqueur.small;
}

/// Un restaurant individuel. Toujours un seul point même si à la fois
/// connu du cercle direct et du réseau étendu (règle 10) : c'est
/// [reseauEtenduCompte] qui porte l'information supplémentaire, pas un
/// second marqueur.
class RestaurantMarqueur extends ObjetCartographique {
  const RestaurantMarqueur({
    required this.id,
    required this.nom,
    required this.ville,
    required this.quartier,
    required this.latitude,
    required this.longitude,
    required this.taille,
    required this.procheDirectCompte,
    required this.procheDirectResume,
    required this.aDeLaRecurrence,
    required this.dejaVisiteParMoi,
    required this.dejaGardeParMoi,
    this.reseauEtenduCompte,
    this.emotionsRepresentatives = const [],
  });

  final String id;
  final String nom;
  final String ville;
  final String? quartier;
  final double latitude;
  final double longitude;

  final TailleMarqueur taille;

  /// Nombre de proches directs pertinents pour la période en cours.
  final int procheDirectCompte;

  /// Phrase déjà composée ("Emma, Thomas +2 connaissent cette adresse")
  /// — jamais recomposée dans le widget, conformément à la règle
  /// d'organisation (widgets/ n'affiche que ce qu'on lui donne).
  final String procheDirectResume;

  /// `null` si la portée sociale actuelle n'inclut pas le réseau étendu,
  /// ou si l'utilisateur n'est pas Premium. Jamais d'identité derrière ce
  /// chiffre (règle 8).
  final int? reseauEtenduCompte;

  /// "Votre cercle revient ici" — au moins un proche direct y est
  /// retourné au moins deux fois sur la période (règle 6).
  final bool aDeLaRecurrence;

  final bool dejaVisiteParMoi;
  final bool dejaGardeParMoi;

  /// Quelques émojis d'émotion des souvenirs les plus récents du cercle
  /// à cette adresse, pour la preview (règle 43).
  final List<String> emotionsRepresentatives;
}

/// Plusieurs restaurants regroupés à ce niveau de zoom — jamais affiché
/// en même temps que ses propres enfants (règle 24). Le chiffre affiché
/// est toujours un nombre d'adresses, jamais autre chose (règle 22).
class ClusterRestaurants extends ObjetCartographique {
  const ClusterRestaurants({
    required this.latitude,
    required this.longitude,
    required this.idsRestaurants,
    required this.latitudeMin,
    required this.latitudeMax,
    required this.longitudeMin,
    required this.longitudeMax,
  });

  final double latitude;
  final double longitude;
  final List<String> idsRestaurants;

  int get nombreRestaurants => idsRestaurants.length;

  /// Limites du groupe, pour zoomer exactement sur ses restaurants au
  /// tap (règle 24).
  final double latitudeMin;
  final double latitudeMax;
  final double longitudeMin;
  final double longitudeMax;
}

/// Une ville agrégée à très grand zoom ("Paris 47") — disparaît dès
/// qu'on entre dans la ville, jamais affichée en même temps que les
/// restaurants individuels qu'elle représente (règle 21). Distinct d'un
/// raccourci ville personnel (règle 20).
class AgregatVille extends ObjetCartographique {
  const AgregatVille({
    required this.ville,
    required this.latitude,
    required this.longitude,
    required this.nombreRestaurants,
  });

  final String ville;
  final double latitude;
  final double longitude;
  final int nombreRestaurants;
}

/// La position de l'utilisateur — jamais confondue avec un restaurant
/// sélectionné ou une ville (règle 29).
class PositionUtilisateur extends ObjetCartographique {
  const PositionUtilisateur({
    required this.latitude,
    required this.longitude,
    required this.precisionMetres,
    this.capDegres,
  });

  final double latitude;
  final double longitude;

  /// Rayon d'incertitude GPS, en mètres — un halo translucide s'affiche
  /// si la précision est faible (règle 29).
  final double precisionMetres;

  /// `null` si le cap n'est pas disponible : on n'invente jamais de
  /// direction (règle 30).
  final double? capDegres;
}
