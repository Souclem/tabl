import 'package:supabase_flutter/supabase_flutter.dart';

import 'lieu_restaurant.dart';
import 'recherche_lieu_service.dart';

/// Recherche adossée aux fonctions `rechercher_lieux` (migration
/// `20261017000000_annuaire_restaurants.sql`) et `lieux_proches`
/// (`20261026010000_lieux_proches.sql`).
class RechercheLieuServiceSupabase implements RechercheLieuService {
  RechercheLieuServiceSupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async {
    if (texte.trim().length < 2) return const [];
    final lignes = await _client.rpc<List<dynamic>>(
      'rechercher_lieux',
      params: {
        'p_texte': texte,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    return _lieux(lignes);
  }

  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
  }) async {
    final lignes = await _client.rpc<List<dynamic>>(
      'lieux_proches',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_rayon_m': rayonM,
      },
    );
    return _lieux(lignes);
  }

  List<LieuRestaurant> _lieux(List<dynamic> lignes) {
    return [
      for (final l in lignes.cast<Map<String, dynamic>>())
        LieuRestaurant(
          restaurantId: l['restaurant_id'] as String?,
          fsqPlaceId: l['fsq_place_id'] as String?,
          nom: l['nom'] as String,
          ville: l['ville'] as String? ?? '',
          adresse: l['adresse'] as String?,
          latitude: (l['latitude'] as num?)?.toDouble(),
          longitude: (l['longitude'] as num?)?.toDouble(),
          categories: (l['categories'] as List?)?.cast<String>() ?? const [],
          distanceM: (l['distance_m'] as num?)?.toDouble(),
        ),
    ];
  }
}
