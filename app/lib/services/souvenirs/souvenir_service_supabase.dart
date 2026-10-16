import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurants/lieu_restaurant.dart';
import '../restaurants/registre_restaurants.dart';
import 'audience_souvenir.dart';
import 'commentaire.dart';
import 'emotion.dart';
import 'filtre_reseau.dart';
import 'souvenir_feed.dart';
import 'souvenir_service.dart';

/// Publication adossée à Supabase (bucket Storage `souvenirs`, tables
/// `restaurants`, `souvenirs` et `souvenirs_amis_tagues` — voir les
/// migrations `20260823000000_abonnements_restaurants_souvenirs.sql`,
/// `20260824000000_storage_souvenirs.sql` et
/// `20260828000000_flux_moment_complet.sql`).
class SouvenirServiceSupabase implements SouvenirService {
  SouvenirServiceSupabase(this._client)
    : _restaurants = RegistreRestaurants(_client);

  final SupabaseClient _client;
  final RegistreRestaurants _restaurants;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<String> enregistrerBrouillon({
    required LieuRestaurant lieu,
    required Uint8List photo,
  }) async {
    final cheminPhoto = await _deposerPhoto(photo);
    final restaurantId = await _restaurants.idPour(lieu);
    final maintenant = DateTime.now();

    final cree = await _client
        .from('souvenirs')
        .insert({
          'auteur_id': _monId,
          'restaurant_id': restaurantId,
          'photo_url': cheminPhoto,
          'moment': maintenant.hour < 17 ? 'midi' : 'soir',
          'date_visite': _formaterDate(maintenant),
          'statut': 'brouillon',
        })
        .select('id')
        .single();

    return cree['id'] as String;
  }

  @override
  Future<List<String>> publier({
    required LieuRestaurant lieu,
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
  }) async {
    final cible = audience.normalisee();
    final cheminPhoto = await _deposerPhoto(photo);
    final cheminBoisson = boissonPhoto == null
        ? null
        : await _deposerPhoto(boissonPhoto, suffixe: 'boisson');
    final restaurantId = await _restaurants.idPour(lieu);
    final maintenant = DateTime.now();

    final cree = await _client
        .from('souvenirs')
        .insert({
          'auteur_id': _monId,
          'restaurant_id': restaurantId,
          'photo_url': cheminPhoto,
          'legende': legende,
          'emotion': emotion.emoji,
          'impressions': impressions,
          // Rien demandé à l'utilisateur pour le moment/la date : on
          // capture l'instant, on ne le fait pas remplir un formulaire
          // pour redire ce que l'horloge sait déjà.
          'moment': maintenant.hour < 17 ? 'midi' : 'soir',
          'date_visite': _formaterDate(maintenant),
          'statut': 'publie',
          'visibilite': cible.mode.valeur,
          'boisson_texte': boissonTexte,
          'boisson_photo_url': cheminBoisson,
        })
        .select('id')
        .single();

    final souvenirId = cree['id'] as String;
    if (amisTaguesIds.isNotEmpty) {
      await _client
          .from('souvenirs_amis_tagues')
          .insert([
            for (final profilId in amisTaguesIds)
              {'souvenir_id': souvenirId, 'profil_id': profilId},
          ]);
    }

    await _ecrirePersonnesAudience(souvenirId, cible.personneIds);
    return _associerTables(souvenirId, cible.tableIds.toList());
  }

  @override
  Future<({AudienceSouvenir audience, Set<String> amisTaguesIds})>
  audienceActuelle(String souvenirId) async {
    final resultats = await Future.wait<Object>([
      _client
          .from('souvenirs')
          .select('visibilite')
          .eq('id', souvenirId)
          .single(),
      _client
          .from('associations_experience_table')
          .select('table_id')
          .eq('souvenir_id', souvenirId),
      _client
          .from('souvenirs_audience')
          .select('profil_id')
          .eq('souvenir_id', souvenirId),
      _client
          .from('souvenirs_amis_tagues')
          .select('profil_id')
          .eq('souvenir_id', souvenirId),
    ]);
    final souvenir = resultats[0] as Map<String, dynamic>;
    Set<String> ids(Object lignes, String colonne) =>
        (lignes as List).map((l) => l[colonne] as String).toSet();

    final mode = ModeAudience.depuisValeur(souvenir['visibilite'] as String?);
    return (
      audience: AudienceSouvenir(
        mode: mode,
        // Une ancienne publication "Tout le monde" peut encore être
        // associée à des Tables : elles ne s'affichent qu'en "Seulement…".
        tableIds: mode == ModeAudience.seulement
            ? ids(resultats[1], 'table_id')
            : const {},
        personneIds: ids(resultats[2], 'profil_id'),
      ),
      amisTaguesIds: ids(resultats[3], 'profil_id'),
    );
  }

  @override
  Future<List<String>> modifierAudience(
    String souvenirId,
    AudienceSouvenir audience,
  ) async {
    final cible = audience.normalisee();
    // Une simple mise à jour de colonne : la date d'origine et la place
    // dans le Feed ne bougent pas (règle 40-41, 65). RLS restreint déjà
    // ça à l'auteur.
    await _client
        .from('souvenirs')
        .update({'visibilite': cible.mode.valeur})
        .eq('id', souvenirId);
    await _ecrirePersonnesAudience(souvenirId, cible.personneIds);

    final actuelles = await _client
        .from('associations_experience_table')
        .select('table_id')
        .eq('souvenir_id', souvenirId);
    final idsActuels = (actuelles as List)
        .map((l) => l['table_id'] as String)
        .toSet();

    final aRetirer = idsActuels.difference(cible.tableIds);
    if (aRetirer.isNotEmpty) {
      await _client
          .from('associations_experience_table')
          .delete()
          .eq('souvenir_id', souvenirId)
          .inFilter('table_id', aRetirer.toList());
    }

    return _associerTables(
      souvenirId,
      cible.tableIds.difference(idsActuels).toList(),
    );
  }

  /// Remplace la liste des personnes choisies (autorisées ou exclues
  /// selon le mode) par [personneIds].
  Future<void> _ecrirePersonnesAudience(
    String souvenirId,
    Set<String> personneIds,
  ) async {
    await _client
        .from('souvenirs_audience')
        .delete()
        .eq('souvenir_id', souvenirId);
    if (personneIds.isEmpty) return;
    await _client.from('souvenirs_audience').insert([
      for (final profilId in personneIds)
        {'souvenir_id': souvenirId, 'profil_id': profilId},
    ]);
  }

  /// Associe [souvenirId] à chaque Table de [tableIds] (règle 26-28,
  /// 39) — un insert par Table plutôt qu'une transaction unique
  /// (l'architecture cliente Supabase ne permet pas de transaction
  /// multi-lignes explicite ici, voir plan Bloc 5). Best-effort
  /// délibéré : le souvenir existe déjà à ce stade, un échec partiel ne
  /// doit jamais faire disparaître les Tables qui ont réussi
  /// (règle 51). Retourne les identifiants de Table qui ont échoué —
  /// jamais d'exception silencieuse.
  Future<List<String>> _associerTables(
    String souvenirId,
    List<String> tableIds,
  ) async {
    final echecs = <String>[];
    for (final tableId in tableIds) {
      try {
        await _client.from('associations_experience_table').insert({
          'souvenir_id': souvenirId,
          'table_id': tableId,
          'ajoute_par': _monId,
        });
      } on PostgrestException catch (e) {
        // Déjà associée (double tap, règle 55) : l'état voulu est déjà
        // atteint, pas une vraie erreur. Sinon (membership perdue entre
        // la sélection et l'envoi, Table supprimée...) : on continue les
        // autres Tables plutôt que de tout annuler (règle 51).
        if (e.code != '23505') echecs.add(tableId);
      }
    }
    return echecs;
  }

  @override
  Future<List<SouvenirFeed>> feed() => _souvenirsPublies();

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) =>
      _souvenirsPublies(auteurId: auteurId);

  /// Requête commune au Feed et aux pages de profil : seule la
  /// restriction des auteurs change, tout le reste (réactions,
  /// commentaires, URLs signées) est résolu de la même façon.
  Future<List<SouvenirFeed>> _souvenirsPublies({String? auteurId}) async {
    var requete = _client
        .from('souvenirs')
        .select(
          'id, auteur_id, photo_url, legende, emotion, moment, date_visite, '
          'impressions, visibilite, '
          'restaurants(nom, ville), profils!souvenirs_auteur_id_fkey(pseudo)',
        )
        .eq('statut', 'publie');
    if (auteurId != null) {
      requete = requete.eq('auteur_id', auteurId);
    } else {
      requete = requete.or(
        await conditionSouvenirsDuReseau(_client, _monId),
      );
    }
    final lignes = await requete
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
    final amisTagues = await _amisTaguesParSouvenir(ids);

    return lignes.map((l) {
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      final auteur = l['profils'] as Map<String, dynamic>?;
      final chemin = l['photo_url'] as String?;
      final id = l['id'] as String;
      final donneesReactions =
          reactions[id] ?? (nombre: 0, jaiReagi: false, pseudos: <String>[]);
      return SouvenirFeed(
        id: id,
        photoUrl: chemin == null ? null : urlParChemin[chemin],
        legende: l['legende'] as String?,
        restaurantNom: restaurant?['nom'] as String? ?? '',
        ville: restaurant?['ville'] as String? ?? '',
        moment: l['moment'] as String? ?? '',
        dateVisite: DateTime.parse(l['date_visite'] as String),
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        nombreReactions: donneesReactions.nombre,
        jaiReagi: donneesReactions.jaiReagi,
        nombreCommentaires: nombreCommentaires[id] ?? 0,
        emotion: Emotion.depuisEmoji(l['emotion'] as String?),
        premieresReactions: donneesReactions.pseudos,
        amisTagues: amisTagues[id] ?? const [],
        impressions: (l['impressions'] as List?)?.cast<String>() ?? const [],
        estAMoi: l['auteur_id'] == _monId,
        audienceRestreinte:
            l['auteur_id'] == _monId && l['visibilite'] != 'tout_le_monde',
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
  /// le nombre total, si j'ai réagi, et les pseudos des 3 dernières
  /// réactions (pour l'affichage "Martin, Sarah et 12 autres").
  Future<Map<String, ({int nombre, bool jaiReagi, List<String> pseudos})>>
  _reactionsParSouvenir(List<String> souvenirIds) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('reactions')
        .select('souvenir_id, profil_id, cree_le, profils(pseudo)')
        .inFilter('souvenir_id', souvenirIds)
        .order('cree_le', ascending: false);

    final comptes = <String, int>{};
    final mesReactions = <String>{};
    final pseudosParSouvenir = <String, List<String>>{};
    for (final l in lignes) {
      final id = l['souvenir_id'] as String;
      comptes[id] = (comptes[id] ?? 0) + 1;
      if (l['profil_id'] == _monId) mesReactions.add(id);

      final pseudos = pseudosParSouvenir.putIfAbsent(id, () => []);
      if (pseudos.length < 3) {
        final profil = l['profils'] as Map<String, dynamic>?;
        final pseudo = profil?['pseudo'] as String?;
        if (pseudo != null) pseudos.add(pseudo);
      }
    }

    return {
      for (final id in souvenirIds)
        id: (
          nombre: comptes[id] ?? 0,
          jaiReagi: mesReactions.contains(id),
          pseudos: pseudosParSouvenir[id] ?? const [],
        ),
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

  /// Pseudos des amis tagués, regroupés par souvenir.
  Future<Map<String, List<String>>> _amisTaguesParSouvenir(
    List<String> souvenirIds,
  ) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('souvenirs_amis_tagues')
        .select('souvenir_id, profils(pseudo)')
        .inFilter('souvenir_id', souvenirIds);

    final pseudosParSouvenir = <String, List<String>>{};
    for (final l in lignes) {
      final id = l['souvenir_id'] as String;
      final profil = l['profils'] as Map<String, dynamic>?;
      final pseudo = profil?['pseudo'] as String?;
      if (pseudo == null) continue;
      pseudosParSouvenir.putIfAbsent(id, () => []).add(pseudo);
    }
    return pseudosParSouvenir;
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

  /// Dépose une photo dans le bucket, sous son propre dossier
  /// (`{monId}/...`) — c'est ce chemin que les policies RLS du bucket
  /// vérifient pour la visibilité. Retourne le chemin déposé (pas une
  /// URL signée, qui expirerait) ; la résolution en URL affichable se
  /// fait au moment de l'affichage, pas ici. [suffixe] distingue la
  /// photo de la boisson de celle du plat sans les faire s'écraser l'une
  /// l'autre si déposées à la même milliseconde.
  Future<String> _deposerPhoto(Uint8List photo, {String? suffixe}) async {
    final nomFichier = suffixe == null
        ? '${DateTime.now().millisecondsSinceEpoch}.jpg'
        : '${DateTime.now().millisecondsSinceEpoch}-$suffixe.jpg';
    final chemin = '$_monId/$nomFichier';
    await _client.storage
        .from('souvenirs')
        .uploadBinary(
          chemin,
          photo,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return chemin;
  }

  String _formaterDate(DateTime date) {
    final annee = date.year.toString().padLeft(4, '0');
    final mois = date.month.toString().padLeft(2, '0');
    final jour = date.day.toString().padLeft(2, '0');
    return '$annee-$mois-$jour';
  }
}
