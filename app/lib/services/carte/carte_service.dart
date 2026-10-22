import 'filtres_carte.dart';
import 'lieu_carte.dart';

/// Au plus autant de lieux sur la carte : tous les restaurants où mes
/// amis sont allés, chargés d'un coup pour que les bulles chiffrées
/// comptent juste à tous les zooms.
const nombreMaxLieuxCarte = 5000;

/// Les données de la carte.
abstract interface class CarteService {
  /// Les restaurants où au moins un de mes amis est allé, dans [zone],
  /// [filtres] appliqués, une ligne résumée par lieu, les plus
  /// pertinents d'abord.
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    int limite = nombreMaxLieuxCarte,
  });

  /// L'identifiant `restaurants` d'un lieu, en l'y faisant entrer s'il
  /// n'est encore que dans l'annuaire (mettre en envie un lieu jamais
  /// visité le fait entrer dans Tabl, comme une première visite).
  Future<String> idRestaurant(LieuCarte lieu);

  /// Ajoute ou retire un restaurant de mes envies.
  Future<void> basculerEnvie(String restaurantId, {required bool envie});
}
