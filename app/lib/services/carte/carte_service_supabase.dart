import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurants/envies_restaurants.dart';
import '../restaurants/lieu_restaurant.dart';
import '../restaurants/registre_restaurants.dart';
import '../social/photo_profil.dart';
import 'carte_service.dart';
import 'filtres_carte.dart';
import 'lieu_carte.dart';

class CarteServiceSupabase implements CarteService {
  CarteServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    int limite = 400,
  }) async {
    final lignes = await _client.rpc<List<dynamic>>(
      'lieux_carte',
      params: {
        'p_sud': zone.sud,
        'p_ouest': zone.ouest,
        'p_nord': zone.nord,
        'p_est': zone.est,
        'p_personne': filtres.personneId,
        'p_table': filtres.tableId,
        'p_categories': filtres.categories,
        'p_mes_envies': filtres.mesEnvies,
        'p_jamais_essaye': filtres.jamaisEssaye,
        'p_coups_de_coeur': filtres.coupsDeCoeur,
        'p_la_ou_on_revient': filtres.laOuOnRevient,
        'p_moment': filtres.moment,
        'p_limite': limite,
      },
    );
    return [
      for (final l in lignes.cast<Map<String, dynamic>>())
        LieuCarte(
          restaurantId: l['restaurant_id'] as String,
          fsqPlaceId: l['fsq_place_id'] as String?,
          nom: l['nom'] as String,
          ville: l['ville'] as String? ?? '',
          adresse: l['adresse'] as String?,
          latitude: (l['latitude'] as num).toDouble(),
          longitude: (l['longitude'] as num).toDouble(),
          categories: (l['categories'] as List?)?.cast<String>() ?? const [],
          amis: l['amis'] as int,
          visites: l['visites'] as int,
          coupsDeCoeur: l['coups_de_coeur'] as int,
          visiteParMoi: l['visite_par_moi'] as bool,
          estEnvie: l['est_envie'] as bool,
          amiPseudo: l['ami_pseudo'] as String?,
          amiPhotoUrl: urlPhotoProfil(
            _client,
            l['ami_photo'] as String?,
            miniature: true,
          ),
        ),
    ];
  }

  @override
  Future<Set<String>> mesLieuxVisites() async {
    final lignes = await _client
        .from('souvenirs')
        .select('restaurants!inner(fsq_place_id)')
        .eq('auteur_id', _monId)
        .not('restaurants.fsq_place_id', 'is', null);
    return {
      for (final l in lignes)
        (l['restaurants'] as Map<String, dynamic>)['fsq_place_id'] as String,
    };
  }

  @override
  Future<List<LieuCarte>> lieuxAnnuaire(
    ZoneCarte zone, {
    int limite = 600,
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
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) =>
      EnviesRestaurants(_client).basculer(restaurantId, envie: envie);
}
