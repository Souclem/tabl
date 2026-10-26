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

  /// Les lieux à moins de [rayonM] d'un point (là où une photo a été
  /// prise), du plus proche au plus loin, avec leur distance à ce point.
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  });

  /// Mes lieux personnels (« Chez mes parents »), par ordre alphabétique :
  /// la recherche ne les propose jamais, à personne.
  Future<List<LieuRestaurant>> mesLieuxPersonnels();
}
