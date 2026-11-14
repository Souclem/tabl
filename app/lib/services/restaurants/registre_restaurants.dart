import 'package:supabase_flutter/supabase_flutter.dart';

import 'categories_lieu.dart';
import 'lieu_restaurant.dart';

/// Retrouve ou crée la ligne `restaurants` d'un lieu choisi — le seul
/// endroit où un restaurant entre dans Tabl, partagé par la publication
/// et les propositions de Table (avant, deux copies de la même logique).
///
/// Un lieu de l'annuaire entre dans Tabl la première fois qu'il sert ;
/// les fois suivantes, `fsq_place_id` ramène toujours la même ligne.
class RegistreRestaurants {
  RegistreRestaurants(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  Future<String> idPour(LieuRestaurant lieu) async {
    final dejaDansTabl = lieu.restaurantId;
    if (dejaDansTabl != null) return dejaDansTabl;

    if (lieu.personnel) return _lieuPersonnel(lieu);

    final fsqId = lieu.fsqPlaceId;
    if (fsqId != null) {
      final existant = await _parFsqId(fsqId);
      if (existant != null) return existant;
      try {
        return await _creer(lieu);
      } on PostgrestException catch (e) {
        // Deux personnes ont choisi ce lieu au même instant : l'autre
        // l'a créé entre-temps, on réutilise sa ligne.
        if (e.code != '23505') rethrow;
        return (await _parFsqId(fsqId))!;
      }
    }

    // Saisi à la main : même nom et même ville = même restaurant.
    final nom = lieu.nom.trim();
    final ville = lieu.ville.trim();
    final existant = await _client
        .from('restaurants')
        .select('id')
        .isFilter('fsq_place_id', null)
        .eq('prive', false)
        .ilike('nom', _echapperJokers(nom))
        .ilike('ville', _echapperJokers(ville))
        .limit(1)
        .maybeSingle();
    if (existant != null) return existant['id'] as String;
    return _creer(lieu);
  }

  /// Le sien, ou un nouveau : jamais celui d'un autre. « Chez moi » est
  /// unique ; chez une personne de Tabl, une ligne par personne ; sinon,
  /// même genre et même nom = même lieu. Jamais d'adresse ni de position
  /// (la base le refuserait de toute façon).
  Future<String> _lieuPersonnel(LieuRestaurant lieu) async {
    final hote = lieu.hoteId;
    final nom = switch (lieu.genre) {
      GenreLieu.domicile => nomDomicile,
      GenreLieu.chez when hote != null => nomChezQuelquun,
      _ => lieu.nom.trim(),
    };
    var existant = _client
        .from('restaurants')
        .select('id')
        .eq('prive', true)
        .eq('cree_par', _monId);
    existant = switch (lieu.genre) {
      GenreLieu.domicile => existant.eq('genre', 'domicile'),
      GenreLieu.chez when hote != null => existant.eq('hote_id', hote),
      // Les lieux personnels d'avant les genres sont « chez ».
      GenreLieu.chez =>
        existant
            .or('genre.eq.chez,genre.is.null')
            .isFilter('hote_id', null)
            .ilike('nom', _echapperJokers(nom)),
      _ =>
        existant
            .eq('genre', lieu.genre.name)
            .ilike('nom', _echapperJokers(nom)),
    };
    final trouve = await existant.limit(1).maybeSingle();
    if (trouve != null) return trouve['id'] as String;
    final cree = await _client
        .from('restaurants')
        .insert({
          'nom': nom,
          'ville': '',
          'nom_recherche': normaliserPourRecherche(nom),
          'cree_par': _monId,
          'prive': true,
          'genre': lieu.genre.enBase,
          'hote_id': hote,
        })
        .select('id')
        .single();
    return cree['id'] as String;
  }

  Future<String?> _parFsqId(String fsqId) async {
    final ligne = await _client
        .from('restaurants')
        .select('id')
        .eq('fsq_place_id', fsqId)
        .maybeSingle();
    return ligne?['id'] as String?;
  }

  Future<String> _creer(LieuRestaurant lieu) async {
    final nom = lieu.nom.trim();
    final cree = await _client
        .from('restaurants')
        .insert({
          'nom': nom,
          'ville': lieu.ville.trim(),
          'adresse': lieu.adresse,
          'latitude': lieu.latitude,
          'longitude': lieu.longitude,
          'categories': lieu.categories,
          'fsq_place_id': lieu.fsqPlaceId,
          'nom_recherche': normaliserPourRecherche(nom),
          'cree_par': _monId,
        })
        .select('id')
        .single();
    return cree['id'] as String;
  }

  /// `ilike` traite `%` et `_` comme des jokers : sans échappement, un nom
  /// comme « 50% Chef » élargirait la comparaison au lieu de chercher une
  /// correspondance exacte.
  String _echapperJokers(String valeur) {
    return valeur
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
