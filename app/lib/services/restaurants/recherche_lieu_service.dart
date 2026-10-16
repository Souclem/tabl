import 'lieu_restaurant.dart';

/// Chercher un restaurant pendant la frappe : les lieux déjà dans Tabl
/// et l'annuaire (Foursquare OS Places), triés par pertinence puis par
/// proximité si une position est connue.
abstract interface class RechercheLieuService {
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  });
}
