import 'package:supabase_flutter/supabase_flutter.dart';

/// Mes envies (table `restaurants_sauvegardes`) — partagé par le Feed
/// ("Enregistrer") et la carte ("Ajouter à mes envies", filtre "Mes
/// envies"), pour qu'il n'existe qu'une seule notion d'envie.
class EnviesRestaurants {
  EnviesRestaurants(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  Future<Set<String>> mesEnviesIds() async {
    final lignes = await _client
        .from('restaurants_sauvegardes')
        .select('restaurant_id')
        .eq('profil_id', _monId);
    return lignes.map((l) => l['restaurant_id'] as String).toSet();
  }

  Future<void> basculer(String restaurantId, {required bool envie}) async {
    if (envie) {
      try {
        await _client.from('restaurants_sauvegardes').insert({
          'restaurant_id': restaurantId,
          'profil_id': _monId,
        });
      } on PostgrestException catch (e) {
        // Déjà dans mes envies (double tap) : l'état voulu est atteint.
        if (e.code != '23505') rethrow;
      }
    } else {
      await _client
          .from('restaurants_sauvegardes')
          .delete()
          .eq('restaurant_id', restaurantId)
          .eq('profil_id', _monId);
    }
  }
}
