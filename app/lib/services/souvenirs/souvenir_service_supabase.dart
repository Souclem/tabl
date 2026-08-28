import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'commentaire.dart';
import 'souvenir_feed.dart';
import 'souvenir_service.dart';

/// Publication adossée à Supabase (bucket Storage `souvenirs`, tables
/// `restaurants` et `souvenirs` — voir les migrations
/// `20260823000000_abonnements_restaurants_souvenirs.sql` et
/// `20260824000000_storage_souvenirs.sql`).
class SouvenirServiceSupabase implements SouvenirService {
  SouvenirServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<void> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    String? legende,
  }) async {
    final cheminPhoto = await _deposerPhoto(photo);
    final restaurantId = await _idRestaurant(nomRestaurant, ville);

    final maintenant = DateTime.now();
    await _client.from('souvenirs').insert({
      'auteur_id': _monId,
      'restaurant_id': restaurantId,
      'photo_url': cheminPhoto,
      'legende': legende,
      // Rien demandé à l'utilisateur : on capture l'instant, on ne le
      // fait pas remplir un formulaire pour redire ce que l'horloge sait
      // déjà.
      'moment': maintenant.hour < 17 ? 'midi' : 'soir',
      'date_visite': _formaterDate(maintenant),
    });
  }

  @override
  Future<List<SouvenirFeed>> feed() async {
    final lignes = await _client
        .from('souvenirs')
        .select(
          'id, photo_url, legende, moment, date_visite, '
          'restaurants(nom, ville), profils!souvenirs_auteur_id_fkey(pseudo)',
        )
        .order('date_visite', ascending: false)
        .order('cree_le', ascending: false);

    final ids = lignes.map((l) => l['id'] as String).toList();

    final urlParChemin = await _resoudreUrlsPhotos(
      lignes
          .map((l) => l['photo_url'] as String?)
          .whereType<String>()
          .toList(),
    );
    final reactions = await _reactionsParSouvenir(ids);
    final nombreCommentaires = await _nombreCommentairesParSouvenir(ids);

    return lignes.map((l) {
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      final auteur = l['profils'] as Map<String, dynamic>?;
      final chemin = l['photo_url'] as String?;
      final id = l['id'] as String;
      final (nombreReactions, jaiReagi) = reactions[id] ?? (0, false);
      return SouvenirFeed(
        id: id,
        photoUrl: chemin == null ? null : urlParChemin[chemin],
        legende: l['legende'] as String?,
        restaurantNom: restaurant?['nom'] as String? ?? '',
        ville: restaurant?['ville'] as String? ?? '',
        moment: l['moment'] as String? ?? '',
        dateVisite: DateTime.parse(l['date_visite'] as String),
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        nombreReactions: nombreReactions,
        jaiReagi: jaiReagi,
        nombreCommentaires: nombreCommentaires[id] ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) async {
    if (reagir) {
      try {
        await _client.from('reactions').insert({
          'souvenir_id': souvenirId,
          'profil_id': _monId,
        });
      } on PostgrestException catch (e) {
        // Déjà réagi (double-tap rapide) : pas une vraie erreur, on
        // considère juste que l'état voulu est déjà atteint.
        if (e.code != '23505') rethrow;
      }
    } else {
      await _client
          .from('reactions')
          .delete()
          .eq('souvenir_id', souvenirId)
          .eq('profil_id', _monId);
    }
  }

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) async {
    final lignes = await _client
        .from('commentaires')
        .select('id, texte, cree_le, auteur_id, profils(pseudo)')
        .eq('souvenir_id', souvenirId)
        .order('cree_le');

    return lignes.map((l) {
      final auteur = l['profils'] as Map<String, dynamic>?;
      return Commentaire(
        id: l['id'] as String,
        texte: l['texte'] as String,
        creeLe: DateTime.parse(l['cree_le'] as String),
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        estLeMien: l['auteur_id'] == _monId,
      );
    }).toList();
  }

  @override
  Future<void> commenter(String souvenirId, String texte) async {
    await _client.from('commentaires').insert({
      'souvenir_id': souvenirId,
      'auteur_id': _monId,
      'texte': texte.trim(),
    });
  }

  @override
  Future<void> supprimerCommentaire(String commentaireId) async {
    await _client.from('commentaires').delete().eq('id', commentaireId);
  }

  /// Réactions des souvenirs donnés, regroupées : pour chaque souvenir,
  /// (nombre total, ai-je réagi). Une seule requête plutôt qu'une par
  /// souvenir affiché.
  Future<Map<String, (int, bool)>> _reactionsParSouvenir(
    List<String> souvenirIds,
  ) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('reactions')
        .select('souvenir_id, profil_id')
        .inFilter('souvenir_id', souvenirIds);

    final comptes = <String, int>{};
    final mesReactions = <String>{};
    for (final l in lignes) {
      final id = l['souvenir_id'] as String;
      comptes[id] = (comptes[id] ?? 0) + 1;
      if (l['profil_id'] == _monId) mesReactions.add(id);
    }

    return {
      for (final id in souvenirIds)
        id: (comptes[id] ?? 0, mesReactions.contains(id)),
    };
  }

  /// Même principe que [_reactionsParSouvenir], pour le nombre de
  /// commentaires — pas besoin du contenu ici, juste le total.
  Future<Map<String, int>> _nombreCommentairesParSouvenir(
    List<String> souvenirIds,
  ) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('commentaires')
        .select('souvenir_id')
        .inFilter('souvenir_id', souvenirIds);

    final comptes = <String, int>{};
    for (final l in lignes) {
      final id = l['souvenir_id'] as String;
      comptes[id] = (comptes[id] ?? 0) + 1;
    }
    return comptes;
  }

  /// Résout des chemins de bucket en URLs signées (valables 1h) — le
  /// bucket est privé, une URL directe ne fonctionnerait pas.
  Future<Map<String, String>> _resoudreUrlsPhotos(List<String> chemins) async {
    if (chemins.isEmpty) return {};

    final resultats = await _client.storage
        .from('souvenirs')
        .createSignedUrlsResult(chemins, 3600);

    final urlParChemin = <String, String>{};
    for (final resultat in resultats) {
      if (resultat is SignedUrlSuccess) {
        urlParChemin[resultat.path] = resultat.signedUrl;
      }
    }
    return urlParChemin;
  }

  /// Dépose la photo dans le bucket, sous son propre dossier
  /// (`{monId}/...`) — c'est ce chemin que les policies RLS du bucket
  /// vérifient pour la visibilité. Retourne le chemin déposé (pas une
  /// URL signée, qui expirerait) ; la résolution en URL affichable se
  /// fait au moment de l'affichage, pas ici.
  Future<String> _deposerPhoto(Uint8List photo) async {
    final chemin = '$_monId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _client.storage
        .from('souvenirs')
        .uploadBinary(
          chemin,
          photo,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return chemin;
  }

  /// Trouve un restaurant existant (nom+ville, comparaison insensible à
  /// la casse), sinon en crée un. Pas de déduplication plus poussée pour
  /// l'instant — ça restera dans ce service, pas en trigger SQL.
  Future<String> _idRestaurant(String nom, String ville) async {
    final nomTrim = nom.trim();
    final villeTrim = ville.trim();

    final existant = await _client
        .from('restaurants')
        .select('id')
        .ilike('nom', _echapperJokers(nomTrim))
        .ilike('ville', _echapperJokers(villeTrim))
        .maybeSingle();

    if (existant != null) return existant['id'] as String;

    final cree = await _client
        .from('restaurants')
        .insert({'nom': nomTrim, 'ville': villeTrim, 'cree_par': _monId})
        .select('id')
        .single();

    return cree['id'] as String;
  }

  /// `ilike` traite `%` et `_` comme des jokers : sans échappement, un nom
  /// de restaurant contenant l'un de ces caractères (ex. « 50% Chef »)
  /// élargirait la comparaison au lieu de chercher une correspondance
  /// exacte, et `.maybeSingle()` planterait si plusieurs lignes matchent.
  String _echapperJokers(String valeur) {
    return valeur
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  String _formaterDate(DateTime date) {
    final annee = date.year.toString().padLeft(4, '0');
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    return '$annee-$mois-$jour';
  }
}
