import 'mode_carte.dart';
import 'objet_cartographique.dart';
import 'periode_carte.dart';
import 'portee_sociale.dart';

/// Les données de la carte Explorer (megaprompt Bloc 1).
///
/// Ne retourne jamais que des agrégats anonymes pour le réseau étendu
/// (règle 8, 68) — aucune méthode de ce contrat n'expose d'identité
/// d'ami d'ami, uniquement des compteurs.
abstract interface class CarteService {
  /// Les villes où au moins un restaurant est visible dans le [mode] et
  /// la [portee] donnés, pour la période choisie — sert à l'agrégat de
  /// ville à grand zoom (règle 21) et à peupler la recherche de la sheet
  /// d'ajout de raccourci.
  Future<List<AgregatVille>> agregatsVilles({
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
  });

  /// Les restaurants d'une ville donnée, prêts à afficher — le
  /// regroupement en clusters selon le niveau de zoom se fait ensuite
  /// avec [regrouperEnClusters], côté appelant, pas ici.
  Future<List<RestaurantMarqueur>> restaurantsPourVille({
    required String ville,
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
    String? amiSelectionneId,
  });

  /// Garde ou retire un restaurant (bouton "Garder" / "Gardé ✓" de la
  /// preview, mode Envies).
  Future<void> basculerGarder(String restaurantId, {required bool garder});
}
