import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notifications_systeme.dart';
import '../restaurants/lieu_restaurant.dart';
import '../restaurants/envies_restaurants.dart';
import '../restaurants/registre_restaurants.dart';
import 'audience_souvenir.dart';
import 'commentaire.dart';
import 'depot_publication_supabase.dart';
import '../social/photo_profil.dart';
import '../stockage/liens_signes.dart';
import '../stockage/sans_metadonnees.dart';
import 'emotion.dart';
import 'filtre_reseau.dart';
import 'moment_modifiable.dart';
import 'nouveau_souvenir.dart';
import 'personne_presente.dart';
import 'personne_qui_aime.dart';
import 'precompletion_souvenir.dart';
import 'souvenir_feed.dart';
import 'souvenir_service.dart';

/// Publication adossée à Supabase (bucket Storage `souvenirs`, tables
/// `restaurants`, `souvenirs` et `souvenirs_amis_tagues` — voir les
/// migrations `20260823000000_abonnements_restaurants_souvenirs.sql`,
/// `20260824000000_storage_souvenirs.sql` et
/// `20260828000000_flux_moment_complet.sql`).
/// Nombre de souvenirs chargés d'un coup (Feed, page de profil).
const nombreMaxSouvenirsCharges = 50;

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
          'moment': momentDuJour(maintenant),
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
    required List<Uint8List> photos,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> empreintes = const [],
  }) async {
    final maintenant = DateTime.now();
    return _creer(
      lieu: lieu,
      photos: photos,
      audience: audience,
      empreintes: empreintes,
      amisTaguesIds: amisTaguesIds,
      colonnes: {
        'legende': legende,
        'emotion': emotion.emoji,
        'impressions': impressions,
        // Rien demandé à l'utilisateur pour le moment/la date : on
        // capture l'instant, on ne le fait pas remplir un formulaire
        // pour redire ce que l'horloge sait déjà.
        'moment': momentDuJour(maintenant),
        'date_visite': _formaterDate(maintenant),
        'boisson_texte': boissonTexte,
        'boisson_photo_url': boissonPhoto == null
            ? null
            : await _deposerPhoto(boissonPhoto, suffixe: 'boisson'),
      },
    );
  }

  @override
  Future<List<String>> ajouterSouvenir(NouveauSouvenir souvenir) {
    return _creer(
      lieu: souvenir.lieu,
      photos: souvenir.photos,
      audience: souvenir.audience,
      empreintes: souvenir.empreintes,
      colonnes: {
        'legende': souvenir.legende,
        'emotion': souvenir.emotion?.emoji,
        'moment': souvenir.moment,
        'date_visite': _formaterDate(souvenir.date.date),
        'jour_connu': souvenir.date.jour != null,
        'est_souvenir': true,
      },
    );
  }

  /// Crée un moment ou un souvenir, publié : ses photos déposées toutes
  /// ensemble (la première est la principale, les autres dans
  /// `souvenirs_photos`), la ligne `souvenirs` avec ses [colonnes] propres,
  /// puis les empreintes, les amis tagués et l'audience. Retourne les
  /// Tables dont l'association a échoué.
  Future<List<String>> _creer({
    required LieuRestaurant lieu,
    required List<Uint8List> photos,
    required AudienceSouvenir audience,
    required Map<String, Object?> colonnes,
    List<String> empreintes = const [],
    List<String> amisTaguesIds = const [],
  }) async {
    final cible = audience.normalisee();
    // Toutes ensemble : dix photos l'une après l'autre feraient attendre.
    final chemins = await Future.wait([
      for (var i = 0; i < photos.length; i++)
        _deposerPhoto(photos[i], suffixe: '$i'),
    ]);
    final restaurantId = await _restaurants.idPour(lieu);

    final cree = await _client
        .from('souvenirs')
        .insert({
          'auteur_id': _monId,
          'restaurant_id': restaurantId,
          'photo_url': chemins.firstOrNull,
          'statut': 'publie',
          'visibilite': cible.mode.valeur,
          ...colonnes,
        })
        .select('id')
        .single();

    final souvenirId = cree['id'] as String;
    final empreintesUniques = empreintes.toSet();
    await (
      chemins.length > 1
          ? _client.from('souvenirs_photos').insert([
              for (var rang = 1; rang < chemins.length; rang++)
                {
                  'souvenir_id': souvenirId,
                  'rang': rang,
                  'chemin': chemins[rang],
                },
            ])
          : Future<void>.value(),
      empreintesUniques.isNotEmpty
          ? _client.from('souvenirs_empreintes').insert([
              for (final e in empreintesUniques)
                {'souvenir_id': souvenirId, 'empreinte': e},
            ])
          : Future<void>.value(),
      amisTaguesIds.isNotEmpty
          ? _client.from('souvenirs_amis_tagues').insert([
              for (final profilId in amisTaguesIds)
                {'souvenir_id': souvenirId, 'profil_id': profilId},
            ])
          : Future<void>.value(),
    ).wait;

    await _ecrirePersonnesAudience(souvenirId, cible.personneIds);
    return _associerTables(souvenirId, cible.tableIds.toList());
  }

  @override
  Future<Set<String>> empreintesImportees() async {
    // La RLS ne laisse lire que celles de ses propres souvenirs.
    final lignes = await _client
        .from('souvenirs_empreintes')
        .select('empreinte');
    return {for (final l in lignes) l['empreinte'] as String};
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
  Future<MomentModifiable> momentModifiable(String souvenirId) async {
    final (ligne, actuelle) = await (
      _client
          .from('souvenirs')
          .select(
            'legende, emotion, impressions, boisson_texte, restaurant_id, '
            'restaurants(nom, ville, categories, prive)',
          )
          .eq('id', souvenirId)
          .single(),
      audienceActuelle(souvenirId),
    ).wait;
    final restaurant = ligne['restaurants'] as Map<String, dynamic>?;
    final nom = restaurant?['nom'] as String? ?? '';
    final restaurantId = ligne['restaurant_id'] as String?;
    return MomentModifiable(
      lieu: restaurant?['prive'] == true
          ? LieuRestaurant.personnel(nom: nom, restaurantId: restaurantId)
          : LieuRestaurant(
              nom: nom,
              ville: restaurant?['ville'] as String? ?? '',
              restaurantId: restaurantId,
              categories:
                  (restaurant?['categories'] as List?)?.cast<String>() ??
                  const [],
            ),
      emotion: Emotion.depuisEmoji(ligne['emotion'] as String?),
      legende: ligne['legende'] as String?,
      amisTaguesIds: actuelle.amisTaguesIds,
      impressions: (ligne['impressions'] as List?)?.cast<String>() ?? const [],
      boissonTexte: ligne['boisson_texte'] as String?,
      audience: actuelle.audience,
    );
  }

  @override
  Future<List<String>> modifier(
    String souvenirId,
    MomentModifiable moment,
  ) async {
    final restaurantId = await _restaurants.idPour(moment.lieu);
    await _client
        .from('souvenirs')
        .update({
          'restaurant_id': restaurantId,
          'emotion': moment.emotion?.emoji,
          'legende': moment.legende,
          'impressions': moment.impressions,
          'boisson_texte': moment.boissonTexte,
        })
        .eq('id', souvenirId);

    // Les personnes taguées : seulement ce qui change, pour ne pas
    // retirer puis remettre ceux qui restent.
    final lignes = await _client
        .from('souvenirs_amis_tagues')
        .select('profil_id')
        .eq('souvenir_id', souvenirId);
    final avant = {for (final l in lignes) l['profil_id'] as String};
    final retires = avant.difference(moment.amisTaguesIds);
    final ajoutes = moment.amisTaguesIds.difference(avant);
    await (
      retires.isEmpty
          ? Future<void>.value()
          : _client
                .from('souvenirs_amis_tagues')
                .delete()
                .eq('souvenir_id', souvenirId)
                .inFilter('profil_id', retires.toList()),
      ajoutes.isEmpty
          ? Future<void>.value()
          : _client.from('souvenirs_amis_tagues').insert([
              for (final profilId in ajoutes)
                {'souvenir_id': souvenirId, 'profil_id': profilId},
            ]),
    ).wait;

    return modifierAudience(souvenirId, moment.audience);
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

  Future<void> _ecrirePersonnesAudience(
    String souvenirId,
    Set<String> personneIds,
  ) => ecrirePersonnesAudience(_client, souvenirId, personneIds);

  Future<List<String>> _associerTables(
    String souvenirId,
    List<String> tableIds,
  ) => associerTablesAuMoment(_client, souvenirId, tableIds);

  @override
  Future<List<SouvenirFeed>> feed() => _souvenirsPublies(sansSouvenirs: true);

  @override
  Future<SouvenirFeed?> souvenir(String souvenirId) async =>
      (await _souvenirsPublies(id: souvenirId)).firstOrNull;

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) =>
      _souvenirsPublies(auteurId: auteurId);

  @override
  Future<List<SouvenirFeed>> mesMomentsAvec(String profilId) =>
      _souvenirsPublies(auteurId: _monId, avecPresent: profilId);

  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) =>
      _souvenirsPublies(restaurantId: restaurantId);

  /// Requête commune au Feed et aux pages de profil : seule la
  /// restriction des auteurs change, tout le reste (réactions,
  /// commentaires, URLs signées) est résolu de la même façon.
  /// [avecPresent] : seulement les moments où cette personne est taguée.
  /// [sansSouvenirs] : sans les repas passés ajoutés après coup (Feed).
  Future<List<SouvenirFeed>> _souvenirsPublies({
    String? auteurId,
    String? restaurantId,
    String? avecPresent,
    bool sansSouvenirs = false,
    String? id,
  }) async {
    // Le réseau filtre le Feed, et dit qui nommer sous chaque moment.
    final futurSuivis = mesSuivis(_client, _monId);
    final presentsFiltres = avecPresent == null
        ? ''
        : ', souvenirs_amis_tagues!inner(profil_id)';
    var requete = _client
        .from('souvenirs')
        .select(
          'id, auteur_id, photo_url, legende, emotion, moment, date_visite, '
          'impressions, visibilite, restaurant_id, est_souvenir, jour_connu, '
          'restaurants(nom, ville, categories, prive), '
          'souvenirs_photos(rang, chemin), '
          'profils!souvenirs_auteur_id_fkey(pseudo, photo_url)'
          '$presentsFiltres',
        )
        .eq('statut', 'publie');
    if (sansSouvenirs) requete = requete.eq('est_souvenir', false);
    if (id != null) requete = requete.eq('id', id);
    if (restaurantId != null) {
      requete = requete.eq('restaurant_id', restaurantId);
    }
    if (avecPresent != null) {
      requete = requete.eq('souvenirs_amis_tagues.profil_id', avecPresent);
    }
    if (auteurId != null) {
      requete = requete.eq('auteur_id', auteurId);
    } else if (id == null) {
      requete = requete.or(
        conditionSouvenirsDuReseau(_monId, await futurSuivis),
      );
    }
    // Les plus récents seulement : au-delà, les requêtes groupées qui
    // suivent (réactions, commentaires...) dépasseraient la longueur
    // d'adresse acceptée par l'API. Le chargement au fil du défilement
    // viendra prendre le relais.
    final lignes = await requete
        .order('date_visite', ascending: false)
        .order('cree_le', ascending: false)
        .limit(nombreMaxSouvenirsCharges);

    final ids = lignes.map((l) => l['id'] as String).toList();
    // Les photos après la principale, dans leur ordre.
    final autresChemins = {
      for (final l in lignes)
        l['id'] as String: [
          for (final p in [
            ...?l['souvenirs_photos'] as List?,
          ]..sort((a, b) => (a['rang'] as int).compareTo(b['rang'] as int)))
            p['chemin'] as String,
        ],
    };

    // Indépendantes les unes des autres : envoyées ensemble, on n'attend
    // que la plus lente au lieu de la somme des cinq.
    final (
      urlParChemin,
      reactions,
      nombreCommentaires,
      presents,
      envies,
      monVisage,
    ) = await (
      liensSignes(_client, 'souvenirs', [
        ...lignes.map((l) => l['photo_url'] as String?).whereType<String>(),
        for (final chemins in autresChemins.values) ...chemins,
      ]),
      futurSuivis.then((suivis) => _reactionsParSouvenir(ids, suivis)),
      _nombreCommentairesParSouvenir(ids),
      _presentsParSouvenir(ids),
      EnviesRestaurants(_client).mesEnviesIds(),
      _monVisage(),
    ).wait;

    return lignes.map((l) {
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      final auteur = l['profils'] as Map<String, dynamic>?;
      final chemin = l['photo_url'] as String?;
      final id = l['id'] as String;
      final donneesReactions =
          reactions[id] ??
          (nombre: 0, jaiReagi: false, nommees: const <PersonneQuiAime>[]);
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
        premieresReactions: donneesReactions.nommees,
        monVisage: monVisage,
        presents: presents[id] ?? const [],
        categories:
            (restaurant?['categories'] as List?)?.cast<String>() ?? const [],
        impressions: (l['impressions'] as List?)?.cast<String>() ?? const [],
        estAMoi: l['auteur_id'] == _monId,
        audienceRestreinte:
            l['auteur_id'] == _monId && l['visibilite'] != 'tout_le_monde',
        restaurantId: l['restaurant_id'] as String?,
        auteurId: l['auteur_id'] as String?,
        auteurPhotoUrl: urlPhotoProfil(
          _client,
          auteur?['photo_url'] as String?,
          miniature: true,
        ),
        estEnvie: envies.contains(l['restaurant_id']),
        autresPhotosUrls: [
          for (final c in autresChemins[id] ?? const <String>[])
            ?urlParChemin[c],
        ],
        estSouvenir: l['est_souvenir'] as bool? ?? false,
        jourConnu: l['jour_connu'] as bool? ?? true,
        lieuPersonnel: restaurant?['prive'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) =>
      EnviesRestaurants(_client).basculer(restaurantId, envie: envie);

  @override
  Future<void> supprimer(String souvenirId) async {
    // Les fichiers sont repérés avant : une fois la ligne partie, plus
    // rien ne dirait lesquels étaient les siens.
    final (ligne, instants) = await (
      _client
          .from('souvenirs')
          .select('photo_url, boisson_photo_url, souvenirs_photos(chemin)')
          .eq('id', souvenirId)
          .single(),
      _client
          .from('instants')
          .select('media_url')
          .eq('parent_experience_id', souvenirId)
          .eq('owner_user_id', _monId),
    ).wait;

    // Les lignes liées (réactions, commentaires, Instants…) suivent.
    await _client.from('souvenirs').delete().eq('id', souvenirId);

    // Seuls ses propres fichiers (son dossier) : les photos de
    // démonstration ou les Instants des autres ne sont pas à lui. Un
    // échec ici n'annule rien — plus aucune ligne ne rend ces fichiers
    // visibles.
    bool aMoi(String? chemin) => chemin?.startsWith('$_monId/') ?? false;
    final photos = [
      ligne['photo_url'] as String?,
      ligne['boisson_photo_url'] as String?,
      for (final p in (ligne['souvenirs_photos'] as List?) ?? const [])
        p['chemin'] as String?,
    ].where(aMoi).cast<String>().toList();
    final medias = [for (final i in instants) i['media_url'] as String?]
        .where(aMoi)
        .cast<String>()
        .toList();
    try {
      await (
        photos.isEmpty
            ? Future.value(const <FileObject>[])
            : _client.storage.from('souvenirs').remove(photos),
        medias.isEmpty
            ? Future.value(const <FileObject>[])
            : _client.storage.from('instants').remove(medias),
      ).wait;
    } catch (e) {
      debugPrint('SouvenirServiceSupabase: fichiers de $souvenirId : $e');
    }
  }

  @override
  Future<void> basculerReaction(
    String souvenirId, {
    required bool reagir,
  }) async {
    if (reagir) {
      try {
        await _client.from('reactions').insert({
          'souvenir_id': souvenirId,
          'profil_id': _monId,
        });
        prevenir(_client, {'evenement': 'reaction', 'souvenir': souvenirId});
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
    // Les profils par le lien de l'auteur : par les j'aime, un
    // commentaire en a d'autres.
    final lignes = await _client
        .from('commentaires')
        .select(
          'id, texte, cree_le, auteur_id, parent_id, '
          'profils!commentaires_auteur_id_fkey(pseudo, photo_url), '
          'commentaires_reactions(profil_id)',
        )
        .eq('souvenir_id', souvenirId)
        .order('cree_le');

    return lignes.map((l) {
      final auteur = l['profils'] as Map<String, dynamic>?;
      final jaime = [
        for (final r in (l['commentaires_reactions'] as List?) ?? const [])
          r['profil_id'] as String,
      ];
      return Commentaire(
        id: l['id'] as String,
        texte: l['texte'] as String,
        creeLe: DateTime.parse(l['cree_le'] as String),
        auteurId: l['auteur_id'] as String?,
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        auteurPhotoUrl: urlPhotoProfil(
          _client,
          auteur?['photo_url'] as String?,
          miniature: true,
        ),
        estLeMien: l['auteur_id'] == _monId,
        parentId: l['parent_id'] as String?,
        nombreJaime: jaime.length,
        jaiAime: jaime.contains(_monId),
      );
    }).toList();
  }

  @override
  Future<void> commenter(
    String souvenirId,
    String texte, {
    String? parentId,
  }) async {
    final commentaire = await _client
        .from('commentaires')
        .insert({
          'souvenir_id': souvenirId,
          'auteur_id': _monId,
          'texte': texte.trim(),
          'parent_id': ?parentId,
        })
        .select('id')
        .single();
    prevenir(_client, {
      'evenement': 'commentaire',
      'commentaire': commentaire['id'],
    });
  }

  @override
  Future<void> basculerJaimeCommentaire(
    String commentaireId, {
    required bool aimer,
  }) async {
    if (!aimer) {
      await _client
          .from('commentaires_reactions')
          .delete()
          .eq('commentaire_id', commentaireId)
          .eq('profil_id', _monId);
      return;
    }
    try {
      await _client.from('commentaires_reactions').insert({
        'commentaire_id': commentaireId,
        'profil_id': _monId,
      });
      prevenir(_client, {
        'evenement': 'reaction_commentaire',
        'commentaire': commentaireId,
      });
    } on PostgrestException catch (e) {
      // Déjà aimé (double tap rapide) : l'état voulu est atteint.
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> supprimerCommentaire(String commentaireId) async {
    await _client.from('commentaires').delete().eq('id', commentaireId);
  }

  /// Réactions des souvenirs donnés, regroupées : pour chaque souvenir,
  /// le nombre total, si j'ai réagi, et les personnes à nommer
  /// ("Martin, Sarah et 12 autres"), celles que je [suivis] d'abord.
  Future<
    Map<String, ({int nombre, bool jaiReagi, List<PersonneQuiAime> nommees})>
  >
  _reactionsParSouvenir(List<String> souvenirIds, Set<String> suivis) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('reactions')
        .select('souvenir_id, profil_id, cree_le, profils(pseudo, photo_url)')
        .inFilter('souvenir_id', souvenirIds)
        .order('cree_le', ascending: false);

    final comptes = <String, int>{};
    final mesReactions = <String>{};
    final parSouvenir =
        <String, List<({String id, String pseudo, String? photoUrl})>>{};
    for (final l in lignes) {
      final id = l['souvenir_id'] as String;
      final profilId = l['profil_id'] as String;
      comptes[id] = (comptes[id] ?? 0) + 1;
      if (profilId == _monId) mesReactions.add(id);

      final profil = l['profils'] as Map<String, dynamic>?;
      final pseudo = profil?['pseudo'] as String?;
      if (pseudo == null) continue;
      parSouvenir.putIfAbsent(id, () => []).add((
        id: profilId,
        pseudo: pseudo,
        photoUrl: urlPhotoProfil(
          _client,
          profil?['photo_url'] as String?,
          miniature: true,
        ),
      ));
    }

    return {
      for (final id in souvenirIds)
        id: (
          nombre: comptes[id] ?? 0,
          jaiReagi: mesReactions.contains(id),
          nommees: personnesNommees(
            parSouvenir[id] ?? const [],
            suivis: suivis,
            monId: _monId,
          ),
        ),
    };
  }

  /// Ma tête, pour la montrer parmi ceux qui ont aimé.
  Future<PersonneQuiAime?> _monVisage() async {
    final profil = await _client
        .from('profils')
        .select('pseudo, photo_url')
        .eq('id', _monId)
        .maybeSingle();
    final pseudo = profil?['pseudo'] as String?;
    if (pseudo == null) return null;
    return PersonneQuiAime(
      pseudo: pseudo,
      photoUrl: urlPhotoProfil(
        _client,
        profil?['photo_url'] as String?,
        miniature: true,
      ),
    );
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

  /// Les personnes taguées comme présentes, regroupées par souvenir.
  Future<Map<String, List<PersonnePresente>>> _presentsParSouvenir(
    List<String> souvenirIds,
  ) async {
    if (souvenirIds.isEmpty) return {};

    final lignes = await _client
        .from('souvenirs_amis_tagues')
        .select('souvenir_id, profil_id, profils(pseudo, photo_url)')
        .inFilter('souvenir_id', souvenirIds);

    final parSouvenir = <String, List<PersonnePresente>>{};
    for (final l in lignes) {
      final profil = l['profils'] as Map<String, dynamic>?;
      final pseudo = profil?['pseudo'] as String?;
      if (pseudo == null) continue;
      final profilId = l['profil_id'] as String;
      parSouvenir
          .putIfAbsent(l['souvenir_id'] as String, () => [])
          .add(
            PersonnePresente(
              id: profilId,
              pseudo: pseudo,
              photoUrl: urlPhotoProfil(
                _client,
                profil?['photo_url'] as String?,
                miniature: true,
              ),
              estMoi: profilId == _monId,
            ),
          );
    }
    return parSouvenir;
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
          sansMetadonnees(photo),
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
