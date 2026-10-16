import 'filtres_carte.dart';
import 'lieu_carte.dart';

/// Les données de la carte, toujours pour une zone précise : on ne
/// charge jamais plus que ce qui peut s'afficher.
abstract interface class CarteService {
  /// Les lieux de mon réseau (visités par moi ou les personnes que je
  /// suis, ou en envie) dans [zone], [filtres] appliqués, une ligne
  /// résumée par lieu, les plus pertinents d'abord.
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    int limite = 400,
  });

  /// Les lieux de l'annuaire dans [zone], pour les restaurants où
  /// personne de mon réseau n'est allé.
  Future<List<LieuCarte>> lieuxAnnuaire(ZoneCarte zone, {int limite = 600});

  /// Identifiants Foursquare des restaurants où je suis allé moi-même :
  /// le filtre "Jamais essayé" les écarte aussi des points de l'annuaire.
  Future<Set<String>> mesLieuxVisites();

  /// L'identifiant `restaurants` d'un lieu, en l'y faisant entrer s'il
  /// n'est encore que dans l'annuaire (mettre en envie un lieu jamais
  /// visité le fait entrer dans Tabl, comme une première visite).
  Future<String> idRestaurant(LieuCarte lieu);

  /// Ajoute ou retire un restaurant de mes envies.
  Future<void> basculerEnvie(String restaurantId, {required bool envie});
}
