import 'filtres_carte.dart';
import 'lieu_carte.dart';

/// Au plus autant de lieux sur la carte : tous les restaurants où mes
/// amis sont allés, chargés d'un coup pour que les bulles chiffrées
/// comptent juste à tous les zooms.
const nombreMaxLieuxCarte = 5000;

/// Les données de la carte.
abstract interface class CarteService {
  /// Les lieux de [mode] dans [zone] — par défaut, les restaurants où
  /// au moins un de mes proches est allé —, [filtres] appliqués, une
  /// ligne résumée par lieu, les plus pertinents d'abord.
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    ModeExplorer mode = ModeExplorer.cercle,
    int limite = nombreMaxLieuxCarte,
  });

  /// Les adresses affichables des photos des lieux ([LieuCarte.cheminPhoto]),
  /// par chemin — à demander seulement pour ce qui s'affiche.
  Future<Map<String, String>> photos(Iterable<String> chemins);

  /// L'identifiant `restaurants` d'un lieu, en l'y faisant entrer s'il
  /// n'est encore que dans l'annuaire (mettre en envie un lieu jamais
  /// visité le fait entrer dans Tabl, comme une première visite).
  Future<String> idRestaurant(LieuCarte lieu);

  /// Ajoute ou retire un restaurant de mes envies.
  Future<void> basculerEnvie(String restaurantId, {required bool envie});
}
