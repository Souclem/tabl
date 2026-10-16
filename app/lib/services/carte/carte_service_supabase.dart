import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurants/lieu_restaurant.dart';
import '../restaurants/registre_restaurants.dart';
import '../souvenirs/emotion.dart';
import '../souvenirs/filtre_reseau.dart';
import 'carte_service.dart';
import 'lieu_carte.dart';

class CarteServiceSupabase implements CarteService {
  CarteServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  static const _colonnesRestaurant =
      'id, nom, ville, adresse, latitude, longitude, categories, fsq_place_id';

  @override
  Future<List<LieuCarte>> lieuxTabl() async {
    final souvenirs = await _client
        .from('souvenirs')
        .select(
          'id, auteur_id, emotion, moment, date_visite, '
          'profils!souvenirs_auteur_id_fkey(pseudo), '
          'restaurants!inner($_colonnesRestaurant)',
        )
        .eq('statut', 'publie')
        .or(await conditionSouvenirsDuReseau(_client, _monId));

    final ids = [for (final s in souvenirs) s['id'] as String];
    final tablesParSouvenir = <String, Set<String>>{};
    if (ids.isNotEmpty) {
      final associations = await _client
          .from('associations_experience_table')
          .select('souvenir_id, table_id')
          .inFilter('souvenir_id', ids);
      for (final a in associations) {
        tablesParSouvenir
            .putIfAbsent(a['souvenir_id'] as String, () => {})
            .add(a['table_id'] as String);
      }
    }

    final envies = await _client
        .from('restaurants_sauvegardes')
        .select('restaurants!inner($_colonnesRestaurant)')
        .eq('profil_id', _monId);

    final restaurants = <String, Map<String, dynamic>>{};
    final visites = <String, List<VisiteCarte>>{};
    for (final s in souvenirs) {
      final restaurant = s['restaurants'] as Map<String, dynamic>;
      final id = restaurant['id'] as String;
      restaurants[id] = restaurant;
      final auteur = s['profils'] as Map<String, dynamic>?;
      visites.putIfAbsent(id, () => []).add(
        VisiteCarte(
          souvenirId: s['id'] as String,
          auteurId: s['auteur_id'] as String,
          auteurPseudo: auteur?['pseudo'] as String? ?? '',
          estMoi: s['auteur_id'] == _monId,
          moment: s['moment'] as String? ?? '',
          date: DateTime.parse(s['date_visite'] as String),
          emotion: Emotion.depuisEmoji(s['emotion'] as String?),
          tableIds: tablesParSouvenir[s['id']] ?? const {},
        ),
      );
    }
    final enviesIds = <String>{};
    for (final e in envies) {
      final restaurant = e['restaurants'] as Map<String, dynamic>;
      final id = restaurant['id'] as String;
      restaurants[id] = restaurant;
      enviesIds.add(id);
    }

    return [
      for (final MapEntry(key: id, value: r) in restaurants.entries)
        // Sans position (anciens restaurants saisis à la main), un lieu
        // ne peut pas apparaître sur une carte.
        if (r['latitude'] != null && r['longitude'] != null)
          LieuCarte(
            restaurantId: id,
            fsqPlaceId: r['fsq_place_id'] as String?,
            nom: r['nom'] as String,
            ville: r['ville'] as String? ?? '',
            adresse: r['adresse'] as String?,
            latitude: (r['latitude'] as num).toDouble(),
            longitude: (r['longitude'] as num).toDouble(),
            categories: (r['categories'] as List?)?.cast<String>() ?? const [],
            visites: visites[id] ?? const [],
            estEnvie: enviesIds.contains(id),
          ),
    ];
  }

  @override
  Future<List<LieuCarte>> lieuxAnnuaire(
    ZoneCarte zone, {
    int limite = 400,
  }) async {
    final lignes = await _client
        .from('lieux_reference')
        .select(
          'fsq_place_id, nom, adresse, ville, latitude, longitude, categories',
        )
        .gte('latitude', zone.sud)
        .lte('latitude', zone.nord)
        .gte('longitude', zone.ouest)
        .lte('longitude', zone.est)
        // Les fiches récentes d'abord : si la zone dépasse la limite, on
        // écarte en priorité celles qui sont peut-être fermées.
        .order('rafraichi_le', ascending: false, nullsFirst: false)
        .limit(limite);
    return [
      for (final l in lignes)
        LieuCarte(
          fsqPlaceId: l['fsq_place_id'] as String,
          nom: l['nom'] as String,
          ville: l['ville'] as String? ?? '',
          adresse: l['adresse'] as String?,
          latitude: (l['latitude'] as num).toDouble(),
          longitude: (l['longitude'] as num).toDouble(),
          categories: (l['categories'] as List?)?.cast<String>() ?? const [],
        ),
    ];
  }

  @override
  Future<String> idRestaurant(LieuCarte lieu) async {
    return lieu.restaurantId ??
        await RegistreRestaurants(_client).idPour(
          LieuRestaurant(
            fsqPlaceId: lieu.fsqPlaceId,
            nom: lieu.nom,
            ville: lieu.ville,
            adresse: lieu.adresse,
            latitude: lieu.latitude,
            longitude: lieu.longitude,
            categories: lieu.categories,
          ),
        );
  }

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) async {
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
