import 'package:supabase_flutter/supabase_flutter.dart';

import 'carte_service.dart';
import 'mode_carte.dart';
import 'objet_cartographique.dart';
import 'periode_carte.dart';
import 'portee_sociale.dart';

/// [CarteService] adossé à Supabase — tables `restaurants`, `souvenirs`
/// (déjà existantes, voir
/// `20260823000000_abonnements_restaurants_souvenirs.sql`) et
/// `restaurants_sauvegardes` + fonction `comptes_reseau_etendu` (voir
/// `20260917000000_carte_explorer.sql`).
///
/// Les compteurs et résumés humains ("Emma, Thomas +2 connaissent cette
/// adresse") sont calculés ici, en Dart, jamais dans une fonction
/// PL/pgSQL — Postgres ne fait que les données et le RLS (CLAUDE.md).
/// La seule exception, `comptes_reseau_etendu`, est une requête SQL
/// déclarative (pas de logique procédurale) rendue nécessaire par la
/// confidentialité : RLS empêche ce client de lire les lignes des amis
/// d'amis, donc l'agrégat ne peut être calculé que côté serveur.
class CarteServiceSupabase implements CarteService {
  CarteServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<List<AgregatVille>> agregatsVilles({
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
  }) async {
    if (mode == ModeCarte.envies) {
      final lignes = await _client
          .from('restaurants_sauvegardes')
          .select('restaurants(ville, latitude, longitude)')
          .eq('profil_id', _monId);
      return _agregerParVille(
        lignes
            .map((l) => l['restaurants'] as Map<String, dynamic>?)
            .whereType<Map<String, dynamic>>(),
      );
    }

    final lignes = await _requeteSouvenirs(mode: mode, periode: periode);
    return _agregerParVille(
      lignes
          .map((l) => l['restaurants'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>(),
    );
  }

  List<AgregatVille> _agregerParVille(Iterable<Map<String, dynamic>> restos) {
    final parVille = <String, ({Set<String> ids, double sommeLat, double sommeLng, int avecCoords})>{};

    for (final r in restos) {
      final ville = r['ville'] as String?;
      if (ville == null) continue;
      final id = r['id'] as String? ?? '$ville/${r['nom']}';
      final lat = (r['latitude'] as num?)?.toDouble();
      final lng = (r['longitude'] as num?)?.toDouble();

      final actuel = parVille[ville];
      final ids = <String>{...(actuel?.ids ?? const <String>{}), id};
      final avecCoords = (actuel?.avecCoords ?? 0) + (lat != null && lng != null ? 1 : 0);
      final sommeLat = (actuel?.sommeLat ?? 0) + (lat ?? 0);
      final sommeLng = (actuel?.sommeLng ?? 0) + (lng ?? 0);
      parVille[ville] = (ids: ids, sommeLat: sommeLat, sommeLng: sommeLng, avecCoords: avecCoords);
    }

    final resultat = <AgregatVille>[];
    for (final entree in parVille.entries) {
      final v = entree.value;
      // Une ville dont aucun restaurant n'a de coordonnées ne peut pas
      // être placée sur la carte — limitation connue tant que la
      // publication ne capture pas de position (hors périmètre Bloc 1).
      if (v.avecCoords == 0) continue;
      resultat.add(
        AgregatVille(
          ville: entree.key,
          latitude: v.sommeLat / v.avecCoords,
          longitude: v.sommeLng / v.avecCoords,
          nombreRestaurants: v.ids.length,
        ),
      );
    }
    return resultat;
  }

  @override
  Future<List<RestaurantMarqueur>> restaurantsPourVille({
    required String ville,
    required ModeCarte mode,
    required PorteeSociale portee,
    required PeriodeCarte periode,
    String? amiSelectionneId,
  }) async {
    final lignes = mode == ModeCarte.envies
        ? await _client
            .from('restaurants_sauvegardes')
            .select('restaurants!inner(id, nom, ville, quartier, latitude, longitude)')
            .eq('profil_id', _monId)
            .eq('restaurants.ville', ville)
        : await _requeteSouvenirs(
            mode: mode,
            periode: periode,
            ville: ville,
            amiSelectionneId: amiSelectionneId,
          );

    final restaurantsGardes = await _idsRestaurantsGardes();
    final mesVisites = mode == ModeCarte.envies
        ? const <String>{}
        : await _idsRestaurantsVisitesParMoi(ville: ville);

    if (mode == ModeCarte.envies) {
      return lignes
          .map((l) => l['restaurants'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .where((r) => r['latitude'] != null && r['longitude'] != null)
          .map(
            (r) => RestaurantMarqueur(
              id: r['id'] as String,
              nom: r['nom'] as String,
              ville: r['ville'] as String,
              quartier: r['quartier'] as String?,
              latitude: (r['latitude'] as num).toDouble(),
              longitude: (r['longitude'] as num).toDouble(),
              taille: TailleMarqueur.small,
              procheDirectCompte: 0,
              procheDirectResume: 'Envie enregistrée',
              aDeLaRecurrence: false,
              dejaVisiteParMoi: mesVisites.contains(r['id']),
              dejaGardeParMoi: true,
            ),
          )
          .toList();
    }

    // Regroupe les lignes souvenirs par restaurant.
    final parRestaurant = <String, List<Map<String, dynamic>>>{};
    for (final l in lignes) {
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      if (restaurant == null) continue;
      if (restaurant['latitude'] == null || restaurant['longitude'] == null) {
        continue;
      }
      parRestaurant.putIfAbsent(restaurant['id'] as String, () => []).add(l);
    }

    Map<String, int> reseauEtendu = const {};
    if (portee != PorteeSociale.procheDirect && parRestaurant.isNotEmpty) {
      reseauEtendu = await _comptesReseauEtendu(parRestaurant.keys.toList());
    }

    final resultat = <RestaurantMarqueur>[];
    for (final entree in parRestaurant.entries) {
      final id = entree.key;
      final souvenirsRestaurant = entree.value;
      final restaurant = souvenirsRestaurant.first['restaurants'] as Map<String, dynamic>;

      final auteursNonMoi = <String, String>{}; // id -> pseudo
      var visitesMoi = 0;
      final compteVisitesParAuteur = <String, int>{};
      final emotions = <String>[];

      for (final l in souvenirsRestaurant) {
        final auteurId = l['auteur_id'] as String;
        compteVisitesParAuteur[auteurId] = (compteVisitesParAuteur[auteurId] ?? 0) + 1;
        if (auteurId == _monId) {
          visitesMoi++;
        } else {
          final profil = l['profils'] as Map<String, dynamic>?;
          final pseudo = profil?['pseudo'] as String?;
          if (pseudo != null) auteursNonMoi[auteurId] = pseudo;
        }
        final emotion = l['emotion'] as String?;
        if (emotion != null) emotions.add(emotion);
      }

      final int comptePertinent;
      final String resume;
      final bool recurrence;
      if (mode == ModeCarte.maCarte) {
        comptePertinent = visitesMoi;
        recurrence = visitesMoi >= 2;
        resume = visitesMoi <= 1
            ? 'Vous y êtes déjà allé.'
            : 'Vous y êtes allé $visitesMoi fois';
      } else {
        comptePertinent = auteursNonMoi.length;
        recurrence = compteVisitesParAuteur.entries
            .any((e) => e.key != _monId && e.value >= 2);
        resume = _resumeProches(auteursNonMoi.values.toList());
      }

      resultat.add(
        RestaurantMarqueur(
          id: id,
          nom: restaurant['nom'] as String,
          ville: restaurant['ville'] as String,
          quartier: restaurant['quartier'] as String?,
          latitude: (restaurant['latitude'] as num).toDouble(),
          longitude: (restaurant['longitude'] as num).toDouble(),
          taille: tailleMarqueurDepuisCompte(comptePertinent),
          procheDirectCompte: comptePertinent,
          procheDirectResume: resume,
          reseauEtenduCompte: reseauEtendu[id],
          aDeLaRecurrence: recurrence,
          dejaVisiteParMoi: mesVisites.contains(id) || visitesMoi > 0,
          dejaGardeParMoi: restaurantsGardes.contains(id),
          emotionsRepresentatives: emotions.toSet().take(3).toList(),
        ),
      );
    }
    return resultat;
  }

  @override
  Future<void> basculerGarder(String restaurantId, {required bool garder}) async {
    if (garder) {
      try {
        await _client.from('restaurants_sauvegardes').insert({
          'restaurant_id': restaurantId,
          'profil_id': _monId,
        });
      } on PostgrestException catch (e) {
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

  /// Souvenirs pertinents pour [mode] (RLS restreint déjà `souvenirs` à
  /// moi + mon cercle accepté — "Le cercle" n'a donc rien à filtrer de
  /// plus ; "Ma carte" ajoute le filtre auteur = moi).
  Future<List<Map<String, dynamic>>> _requeteSouvenirs({
    required ModeCarte mode,
    required PeriodeCarte periode,
    String? ville,
    String? amiSelectionneId,
  }) async {
    var requete = _client
        .from('souvenirs')
        .select(
          'restaurant_id, auteur_id, emotion, date_visite, '
          'restaurants!inner(id, nom, ville, quartier, latitude, longitude), '
          'profils!souvenirs_auteur_id_fkey(pseudo)',
        )
        .eq('statut', 'publie');

    if (ville != null) {
      requete = requete.eq('restaurants.ville', ville);
    }
    if (mode == ModeCarte.maCarte) {
      requete = requete.eq('auteur_id', _monId);
    }
    if (amiSelectionneId != null) {
      requete = requete.eq('auteur_id', amiSelectionneId);
    }
    final depuis = periode.depuis(DateTime.now());
    if (depuis != null) {
      requete = requete.gte('date_visite', _formaterDate(depuis));
    }

    return requete;
  }

  Future<Set<String>> _idsRestaurantsGardes() async {
    final lignes = await _client
        .from('restaurants_sauvegardes')
        .select('restaurant_id')
        .eq('profil_id', _monId);
    return lignes.map((l) => l['restaurant_id'] as String).toSet();
  }

  Future<Set<String>> _idsRestaurantsVisitesParMoi({required String ville}) async {
    final lignes = await _client
        .from('souvenirs')
        .select('restaurant_id, restaurants!inner(ville)')
        .eq('auteur_id', _monId)
        .eq('statut', 'publie')
        .eq('restaurants.ville', ville);
    return lignes.map((l) => l['restaurant_id'] as String).toSet();
  }

  /// Appelle `comptes_reseau_etendu` (fonction SQL, voir migration) :
  /// jamais d'identité, seulement un total par restaurant (règle 8, 68).
  Future<Map<String, int>> _comptesReseauEtendu(List<String> restaurantIds) async {
    final lignes = await _client.rpc(
      'comptes_reseau_etendu',
      params: {'ids': restaurantIds},
    );
    final resultat = <String, int>{};
    for (final l in lignes as List) {
      resultat[l['restaurant_id'] as String] = l['compte'] as int;
    }
    return resultat;
  }

  /// "Emma, Thomas +2 connaissent cette adresse" (règle 45) — jamais
  /// composé côté widget.
  String _resumeProches(List<String> pseudos) {
    if (pseudos.isEmpty) return '';
    if (pseudos.length == 1) return '${pseudos[0]} connaît cette adresse';
    if (pseudos.length == 2) {
      return '${pseudos[0]}, ${pseudos[1]} connaissent cette adresse';
    }
    return '${pseudos[0]}, ${pseudos[1]} +${pseudos.length - 2} connaissent cette adresse';
  }

  String _formaterDate(DateTime date) {
    final annee = date.year.toString().padLeft(4, '0');
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    return '$annee-$mois-$jour';
  }
}
