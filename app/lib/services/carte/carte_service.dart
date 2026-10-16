import 'lieu_carte.dart';

/// Les données de la carte.
abstract interface class CarteService {
  /// Les lieux entrés dans Tabl que je peux voir : ceux où mon réseau est
  /// allé (avec ses visites, pour les filtres) et mes envies. Tous d'un
  /// coup — c'est un volume modeste, et la carte les regroupe elle-même
  /// selon le zoom.
  Future<List<LieuCarte>> lieuxTabl();

  /// Les lieux de l'annuaire dans [zone], pour les afficher en points
  /// discrets quand on zoome sur un quartier.
  Future<List<LieuCarte>> lieuxAnnuaire(ZoneCarte zone, {int limite = 400});

  /// L'identifiant `restaurants` d'un lieu, en l'y faisant entrer s'il
  /// n'est encore que dans l'annuaire (mettre en envie un lieu jamais
  /// visité le fait entrer dans Tabl, comme une première visite).
  Future<String> idRestaurant(LieuCarte lieu);

  /// Ajoute ou retire un restaurant de mes envies.
  Future<void> basculerEnvie(String restaurantId, {required bool envie});
}
