import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurants/envies_restaurants.dart';
import '../social/photo_profil.dart';
import '../stockage/liens_signes.dart';
import '../restaurants/lieu_restaurant.dart';
import '../restaurants/registre_restaurants.dart';
import 'carte_service.dart';
import 'filtres_carte.dart';
import 'lieu_carte.dart';

class CarteServiceSupabase implements CarteService {
  CarteServiceSupabase(this._client);

  final SupabaseClient _client;

  @override
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    ModeExplorer mode = ModeExplorer.cercle,
    int limite = nombreMaxLieuxCarte,
  }) async {
    final depuis = filtres.periode.depuis(DateTime.now());
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
        'p_depuis': depuis == null ? null : _date(depuis),
        'p_mode': mode.valeur,
      },
    );
    DateTime? date(Object? valeur) =>
        valeur == null ? null : DateTime.parse(valeur as String);
    List<String> textes(Object? valeur) =>
        (valeur as List?)?.cast<String>() ?? const [];
    return [
      for (final l in lignes.cast<Map<String, dynamic>>())
        LieuCarte(
          restaurantId: l['restaurant_id'] as String,
          fsqPlaceId: l['fsq_place_id'] as String?,
          nom: l['nom'] as String,
          ville: l['ville'] as String? ?? '',
          quartier: l['quartier'] as String?,
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
          amisQuiReviennent: l['amis_qui_reviennent'] as int? ?? 0,
          derniereVisite: date(l['derniere_visite']),
          ressentis: textes(l['ressentis']),
          cheminPhoto: l['photo'] as String?,
          visages: [
            for (final (i, pseudo) in textes(l['visages_pseudos']).indexed)
              (
                pseudo: pseudo,
                photoUrl: urlPhotoProfil(
                  _client,
                  textes(l['visages_photos']).elementAtOrNull(i),
                  miniature: true,
                ),
              ),
          ],
          mesVisites: l['mes_visites'] as int? ?? 0,
          maPremiereVisite: date(l['ma_premiere_visite']),
          maDerniereVisite: date(l['ma_derniere_visite']),
        ),
    ];
  }

  @override
  Future<Map<String, String>> photos(Iterable<String> chemins) =>
      liensSignes(_client, 'souvenirs', chemins.toSet());

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Future<LieuCarte?> lieuDuRestaurant(String restaurantId) async {
    final l = await _client
        .from('restaurants')
        .select(
          'nom, ville, quartier, adresse, latitude, longitude, categories',
        )
        .eq('id', restaurantId)
        .maybeSingle();
    final latitude = (l?['latitude'] as num?)?.toDouble();
    final longitude = (l?['longitude'] as num?)?.toDouble();
    if (l == null || latitude == null || longitude == null) return null;
    return LieuCarte(
      restaurantId: restaurantId,
      nom: l['nom'] as String,
      ville: l['ville'] as String? ?? '',
      quartier: l['quartier'] as String?,
      adresse: l['adresse'] as String?,
      latitude: latitude,
      longitude: longitude,
      categories: (l['categories'] as List?)?.cast<String>() ?? const [],
    );
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
