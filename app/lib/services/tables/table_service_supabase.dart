import 'package:supabase_flutter/supabase_flutter.dart';

import '../souvenirs/emotion.dart';
import 'candidat_date_proposition.dart';
import 'confirmation_proposition.dart';
import 'decouverte_table.dart';
import 'detail_proposition.dart';
import 'experience_histoire_table.dart';
import 'groupe_table.dart';
import 'membre_table.dart';
import 'message_organisation.dart';
import 'mosaique_table.dart';
import 'proposition_table.dart';
import 'resume_table.dart';
import 'statut_membre_table.dart';
import 'table_service.dart';

/// Tables adossées à Supabase (voir la migration
/// `20260917010000_tables_groupes.sql` pour le schéma et les policies
/// RLS). Depuis `20260917030000_visibilite_experience_centralisee.sql`
/// (megaprompt Bloc 5), la policy `souvenirs` elle-même accorde l'accès
/// aux membres actifs d'une Table associée — "Notre histoire" lit donc
/// `souvenirs` directement, sans passer par une fonction à part.
class TableServiceSupabase implements TableService {
  TableServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async {
    if (tableIds.isEmpty) return {};
    final lignes = await _client
        .from('membres_table')
        .select('table_id, profil_id')
        .inFilter('table_id', tableIds)
        .eq('statut', 'active')
        .neq('profil_id', _monId);
    final membres = <String, Set<String>>{for (final id in tableIds) id: {}};
    for (final l in lignes) {
      membres[l['table_id'] as String]!.add(l['profil_id'] as String);
    }
    return membres;
  }

  @override
  Future<List<ResumeTable>> mesTables() async {
    final mesMembership = await _client
        .from('membres_table')
        .select('table_id')
        .eq('profil_id', _monId)
        .eq('statut', 'active');
    final tableIds = mesMembership.map((l) => l['table_id'] as String).toList();
    if (tableIds.isEmpty) return [];

    final tablesRows = await _client
        .from('tables')
        .select('id, nom, emoji, couverture_photo_url')
        .inFilter('id', tableIds);

    final membresActifs = await _client
        .from('membres_table')
        .select('table_id')
        .inFilter('table_id', tableIds)
        .eq('statut', 'active');
    final nombreMembresParTable = <String, int>{};
    for (final l in membresActifs) {
      final id = l['table_id'] as String;
      nombreMembresParTable[id] = (nombreMembresParTable[id] ?? 0) + 1;
    }

    final propositionsActives = await _client
        .from('table_propositions')
        .select('id, table_id')
        .inFilter('table_id', tableIds)
        .eq('etat', 'active');
    final propIds = propositionsActives.map((l) => l['id'] as String).toList();

    final mesInterets = propIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('interets_proposition')
              .select('proposition_id')
              .eq('profil_id', _monId)
              .inFilter('proposition_id', propIds);
    final propositionsRepondues = mesInterets
        .map((l) => l['proposition_id'] as String)
        .toSet();

    final propositionsActivesParTable = <String, List<String>>{};
    for (final l in propositionsActives) {
      final tableId = l['table_id'] as String;
      propositionsActivesParTable.putIfAbsent(tableId, () => []).add(l['id'] as String);
    }

    // Mosaïque : une expérience récente par Table suffit pour la row
    // compacte de la home (règle 84 : ne charger que le nécessaire, pas
    // toute l'histoire).
    final photosChemins = await Future.wait(
      tableIds.map((id) => _cheminsPhotosRecents(id, limite: 6)),
    );
    final photosChaminsParTable = Map.fromIterables(tableIds, photosChemins);

    final tousChemins = <String>{
      for (final l in tablesRows)
        if (l['couverture_photo_url'] != null) l['couverture_photo_url'] as String,
      for (final chemins in photosChemins) ...chemins,
    }.toList();
    final urlParChemin = await _resoudreUrlsPhotos(tousChemins);

    final resultats = tablesRows.map((l) {
      final id = l['id'] as String;
      final nombreMembres = nombreMembresParTable[id] ?? 0;
      final propositionsTable = propositionsActivesParTable[id] ?? const [];
      final enAttenteDeMoi = propositionsTable
          .any((p) => !propositionsRepondues.contains(p));

      final String etatTexte;
      final bool actionRequise;
      if (enAttenteDeMoi) {
        etatTexte = 'À vous de voter';
        actionRequise = true;
      } else if (propositionsTable.isNotEmpty) {
        etatTexte = propositionsTable.length == 1
            ? '1 proposition'
            : '${propositionsTable.length} propositions';
        actionRequise = false;
      } else if (nombreMembres <= 1) {
        etatTexte = 'En attente de votre premier membre.';
        actionRequise = false;
      } else {
        etatTexte = 'Rien de nouveau';
        actionRequise = false;
      }

      final chemin = l['couverture_photo_url'] as String?;
      final mosaique = (photosChaminsParTable[id] ?? const [])
          .map((c) => urlParChemin[c])
          .whereType<String>()
          .toList();

      return (
        resume: ResumeTable(
          id: id,
          nom: l['nom'] as String,
          emoji: l['emoji'] as String?,
          couverturePhotoUrl: chemin == null ? null : urlParChemin[chemin],
          mosaiquePhotosUrls: selectionnerMosaique(mosaique),
          nombreMembres: nombreMembres,
          etatTexte: etatTexte,
          actionRequise: actionRequise,
        ),
        prioriteTri: (
          enAttenteDeMoi ? 0 : 1,
          -propositionsTable.length,
        ),
      );
    }).toList();

    resultats.sort((a, b) {
      final cmpAction = a.prioriteTri.$1.compareTo(b.prioriteTri.$1);
      if (cmpAction != 0) return cmpAction;
      return a.prioriteTri.$2.compareTo(b.prioriteTri.$2);
    });

    return resultats.map((r) => r.resume).toList();
  }

  @override
  Future<List<ResumeTable>> mesInvitations() async {
    final invitations = await _client
        .from('membres_table')
        .select('table_id, tables(id, nom, emoji)')
        .eq('profil_id', _monId)
        .eq('statut', 'en_attente');

    return invitations.map((l) {
      final table = l['tables'] as Map<String, dynamic>;
      return ResumeTable(
        id: table['id'] as String,
        nom: table['nom'] as String,
        emoji: table['emoji'] as String?,
        nombreMembres: 0,
        etatTexte: 'Invitation en attente',
        actionRequise: true,
      );
    }).toList();
  }

  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) async {
    final cree = await _client
        .from('tables')
        .insert({'nom': nom.trim(), 'emoji': emoji, 'cree_par': _monId})
        .select('id')
        .single();
    final tableId = cree['id'] as String;

    await _client.from('membres_table').insert({
      'table_id': tableId,
      'profil_id': _monId,
      'statut': 'active',
      'est_admin': true,
    });

    if (membresInvitesIds.isNotEmpty) {
      await _client.from('membres_table').insert([
        for (final profilId in membresInvitesIds)
          {
            'table_id': tableId,
            'profil_id': profilId,
            'statut': 'en_attente',
            'est_admin': false,
          },
      ]);
    }

    return table(tableId);
  }

  @override
  Future<GroupeTable> table(String tableId) async {
    final ligne = await _client
        .from('tables')
        .select('id, nom, emoji, signature, couverture_photo_url, cree_par')
        .eq('id', tableId)
        .single();

    final membresRows = await _client
        .from('membres_table')
        .select('profil_id, statut, est_admin, profils(pseudo)')
        .eq('table_id', tableId);

    final membres = membresRows.map((l) {
      final profil = l['profils'] as Map<String, dynamic>?;
      return MembreTable(
        profilId: l['profil_id'] as String,
        pseudo: profil?['pseudo'] as String? ?? '',
        statut: StatutMembreTable.depuisValeur(l['statut'] as String),
        estAdmin: l['est_admin'] as bool,
      );
    }).toList();

    final cheminsRecents = await _cheminsPhotosRecents(tableId, limite: 6);
    final couvertureChemin = ligne['couverture_photo_url'] as String?;
    final urlParChemin = await _resoudreUrlsPhotos([
      ?couvertureChemin,
      ...cheminsRecents,
    ]);

    MembreTable? moi;
    for (final m in membres) {
      if (m.profilId == _monId) {
        moi = m;
        break;
      }
    }

    return GroupeTable(
      id: ligne['id'] as String,
      nom: ligne['nom'] as String,
      emoji: ligne['emoji'] as String?,
      signature: ligne['signature'] as String?,
      couverturePhotoUrl: couvertureChemin == null ? null : urlParChemin[couvertureChemin],
      mosaiquePhotosUrls: selectionnerMosaique(
        cheminsRecents.map((c) => urlParChemin[c]).whereType<String>().toList(),
      ),
      creeParMoi: ligne['cree_par'] == _monId,
      jeSuisAdmin: moi?.estAdmin ?? false,
      membres: membres,
    );
  }

  @override
  Future<void> accepterInvitation(String tableId) async {
    await _client
        .from('membres_table')
        .update({'statut': 'active'})
        .eq('table_id', tableId)
        .eq('profil_id', _monId);
  }

  @override
  Future<void> refuserInvitation(String tableId) async {
    await _client
        .from('membres_table')
        .update({'statut': 'parti'})
        .eq('table_id', tableId)
        .eq('profil_id', _monId);
  }

  @override
  Future<void> inviter(String tableId, String profilId) async {
    await _client.from('membres_table').insert({
      'table_id': tableId,
      'profil_id': profilId,
      'statut': 'en_attente',
      'est_admin': false,
    });
  }

  @override
  Future<void> quitter(String tableId) async {
    await _client
        .from('membres_table')
        .update({'statut': 'parti'})
        .eq('table_id', tableId)
        .eq('profil_id', _monId);
  }

  @override
  Future<void> retirerMembre(String tableId, String profilId) async {
    await _client
        .from('membres_table')
        .update({'statut': 'retire'})
        .eq('table_id', tableId)
        .eq('profil_id', profilId);
  }

  @override
  Future<void> renommer(String tableId, String nom) async {
    await _client
        .from('tables')
        .update({'nom': nom.trim(), 'maj_le': DateTime.now().toIso8601String()})
        .eq('id', tableId);
  }

  @override
  Future<void> supprimer(String tableId) async {
    // Les associations/memberships/propositions partent en cascade
    // (contraintes FK) — jamais les souvenirs eux-mêmes (règle 59).
    await _client.from('tables').delete().eq('id', tableId);
  }

  @override
  Future<
    ({
      List<ExperienceHistoireTable> experiences,
      List<RecurrenceTable> laOuOnRevient,
    })
  >
  histoire(String tableId) async {
    final lignes = await _lignesHistoire(tableId);

    final chemins = lignes
        .map((l) => (l['souvenirs'] as Map<String, dynamic>)['photo_url'] as String?)
        .whereType<String>()
        .toList();
    final urlParChemin = await _resoudreUrlsPhotos(chemins);

    final experiences = lignes.map((l) {
      final s = l['souvenirs'] as Map<String, dynamic>;
      final chemin = s['photo_url'] as String?;
      final restaurant = s['restaurants'] as Map<String, dynamic>?;
      final auteur = s['profils'] as Map<String, dynamic>?;
      return ExperienceHistoireTable(
        id: s['id'] as String,
        photoUrl: chemin == null ? null : urlParChemin[chemin],
        restaurantNom: restaurant?['nom'] as String? ?? '',
        ville: restaurant?['ville'] as String? ?? '',
        dateVisite: DateTime.parse(s['date_visite'] as String),
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        emotion: Emotion.depuisEmoji(s['emotion'] as String?),
      );
    }).toList();

    final comptesParRestaurant = <String, int>{};
    for (final e in experiences) {
      comptesParRestaurant[e.restaurantNom] =
          (comptesParRestaurant[e.restaurantNom] ?? 0) + 1;
    }
    // Une vraie récurrence (règle 21), pas une avec une seule visite.
    final laOuOnRevient = comptesParRestaurant.entries
        .where((e) => e.value >= 2)
        .map((e) => RecurrenceTable(restaurantNom: e.key, nombreFois: e.value))
        .toList()
      ..sort((a, b) => b.nombreFois.compareTo(a.nombreFois));

    return (experiences: experiences, laOuOnRevient: laOuOnRevient);
  }

  @override
  Future<List<PropositionTable>> propositions(String tableId) async {
    final lignes = await _client
        .from('table_propositions')
        .select(
          'id, restaurant_id, cree_par, etat, '
          'restaurants(nom, ville), '
          'profils!table_propositions_cree_par_fkey(pseudo)',
        )
        .eq('table_id', tableId)
        .order('cree_le', ascending: false);

    final ids = lignes.map((l) => l['id'] as String).toList();
    final interets = ids.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('interets_proposition')
              .select('proposition_id, profil_id, interet')
              .inFilter('proposition_id', ids);

    final nombreGoParProposition = <String, int>{};
    final monInteretParProposition = <String, bool>{};
    for (final l in interets) {
      final id = l['proposition_id'] as String;
      final estGo = l['interet'] == 'go';
      if (estGo) nombreGoParProposition[id] = (nombreGoParProposition[id] ?? 0) + 1;
      if (l['profil_id'] == _monId) monInteretParProposition[id] = estGo;
    }

    return lignes.map((l) {
      final id = l['id'] as String;
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      final auteur = l['profils'] as Map<String, dynamic>?;
      final etat = l['etat'] as String;
      final monInteret = monInteretParProposition[id];
      return PropositionTable(
        id: id,
        restaurantId: l['restaurant_id'] as String,
        restaurantNom: restaurant?['nom'] as String? ?? '',
        ville: restaurant?['ville'] as String? ?? '',
        proposePar: auteur?['pseudo'] as String? ?? '',
        parMoi: l['cree_par'] == _monId,
        etatTexte: _etatPropositionTexte(etat, monInteret),
        active: _etatEstActif(etat),
        nombreGo: nombreGoParProposition[id] ?? 0,
        monInteret: monInteret,
      );
    }).toList();
  }

  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async {
    final restaurantId = await _idRestaurant(nomRestaurant, ville);

    final existante = await _client
        .from('table_propositions')
        .select('id')
        .eq('table_id', tableId)
        .eq('restaurant_id', restaurantId)
        .inFilter('etat', ['active', 'polling', 'date_selection', 'confirmed'])
        .maybeSingle();

    if (existante != null) {
      final toutes = await propositions(tableId);
      final trouvee = toutes.firstWhere((p) => p.id == existante['id']);
      return (proposition: trouvee, dejaExistante: true);
    }

    final cree = await _client
        .from('table_propositions')
        .insert({
          'table_id': tableId,
          'restaurant_id': restaurantId,
          'cree_par': _monId,
        })
        .select('id')
        .single();

    return (
      proposition: PropositionTable(
        id: cree['id'] as String,
        restaurantId: restaurantId,
        restaurantNom: nomRestaurant.trim(),
        ville: ville.trim(),
        proposePar: '',
        parMoi: true,
        etatTexte: 'Proposé',
        active: true,
        nombreGo: 0,
        monInteret: null,
      ),
      dejaExistante: false,
    );
  }

  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {
    await _client.from('interets_proposition').upsert({
      'proposition_id': propositionId,
      'profil_id': _monId,
      'interet': go ? 'go' : 'passe',
      'maj_le': DateTime.now().toIso8601String(),
    }, onConflict: 'proposition_id,profil_id');
  }

  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) async {
    final autresMembres = await _client
        .from('membres_table')
        .select('profil_id')
        .eq('table_id', tableId)
        .eq('statut', 'active')
        .neq('profil_id', _monId);
    final autresIds = autresMembres.map((l) => l['profil_id'] as String).toList();
    if (autresIds.isEmpty) return [];

    final mesVisites = await _client
        .from('souvenirs')
        .select('restaurant_id')
        .eq('auteur_id', _monId)
        .eq('statut', 'publie');
    final restaurantsVisitesParMoi = mesVisites
        .map((l) => l['restaurant_id'] as String)
        .toSet();

    // RLS de `souvenirs` filtre déjà à ce qui m'est légitimement visible
    // (moi-même exclu ici, ou cercle accepté) — pas besoin de revérifier
    // la privacy ici, elle est déjà appliquée par la base (règle 40).
    final souvenirsAutres = await _client
        .from('souvenirs')
        .select(
          'restaurant_id, emotion, '
          'restaurants(nom, ville, quartier), '
          'profils!souvenirs_auteur_id_fkey(pseudo)',
        )
        .inFilter('auteur_id', autresIds)
        .eq('statut', 'publie');

    final parRestaurant = <String, ({
      String nom,
      String ville,
      String? quartier,
      Set<String> pseudos,
      Set<String> emotions,
    })>{};
    for (final l in souvenirsAutres) {
      final restaurantId = l['restaurant_id'] as String;
      if (restaurantsVisitesParMoi.contains(restaurantId)) continue;
      final restaurant = l['restaurants'] as Map<String, dynamic>?;
      final auteur = l['profils'] as Map<String, dynamic>?;
      final pseudo = auteur?['pseudo'] as String?;
      final emotion = l['emotion'] as String?;

      final existant = parRestaurant[restaurantId];
      parRestaurant[restaurantId] = (
        nom: restaurant?['nom'] as String? ?? '',
        ville: restaurant?['ville'] as String? ?? '',
        quartier: restaurant?['quartier'] as String?,
        pseudos: {...(existant?.pseudos ?? {}), ?pseudo},
        emotions: {...(existant?.emotions ?? {}), ?emotion},
      );
    }

    if (parRestaurant.isEmpty) return [];

    final gardes = await _client
        .from('restaurants_sauvegardes')
        .select('restaurant_id')
        .eq('profil_id', _monId)
        .inFilter('restaurant_id', parRestaurant.keys.toList());
    final restaurantsGardes = gardes.map((l) => l['restaurant_id'] as String).toSet();

    final resultats = parRestaurant.entries
        .map(
          (e) => DecouverteTable(
            restaurantId: e.key,
            restaurantNom: e.value.nom,
            ville: e.value.ville,
            quartier: e.value.quartier,
            pseudosConnaisseurs: e.value.pseudos.toList(),
            emotionsRepresentatives: e.value.emotions.toList(),
            dejaGardeParMoi: restaurantsGardes.contains(e.key),
          ),
        )
        .toList();
    // Règle 39 : plusieurs membres qui connaissent d'abord, discrètement
    // — jamais un score affiché à l'utilisateur.
    resultats.sort(
      (a, b) => b.pseudosConnaisseurs.length.compareTo(a.pseudosConnaisseurs.length),
    );
    return resultats;
  }

  @override
  Future<DetailProposition> detailProposition(String propositionId) async {
    final ligne = await _client
        .from('table_propositions')
        .select(
          'id, cree_par, etat, '
          'restaurants(nom, ville), '
          'profils!table_propositions_cree_par_fkey(pseudo)',
        )
        .eq('id', propositionId)
        .single();

    final interets = await _client
        .from('interets_proposition')
        .select('profil_id, interet')
        .eq('proposition_id', propositionId);
    var nombreGo = 0;
    bool? monInteret;
    for (final l in interets) {
      final estGo = l['interet'] == 'go';
      if (estGo) nombreGo++;
      if (l['profil_id'] == _monId) monInteret = estGo;
    }

    final candidatsRows = await _client
        .from('dates_candidates_proposition')
        .select('id, date_locale')
        .eq('proposition_id', propositionId)
        .order('date_locale');
    final candidatIds = candidatsRows.map((l) => l['id'] as String).toList();

    final resultatsRows =
        await _client.rpc('resultats_disponibilite', params: {'p_proposition_id': propositionId})
            as List;
    final resultatParId = <String, Map<String, dynamic>>{
      for (final r in resultatsRows) r['date_candidate_id'] as String: r as Map<String, dynamic>,
    };

    final mesDisponibilites = candidatIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('disponibilites_proposition')
              .select('date_candidate_id')
              .eq('profil_id', _monId)
              .inFilter('date_candidate_id', candidatIds);
    final mesIdsDisponibles = mesDisponibilites
        .map((l) => l['date_candidate_id'] as String)
        .toSet();

    final aujourdhui = DateTime.now();
    final aujourdhuiSansHeure = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
    final candidats = candidatsRows.map((l) {
      final id = l['id'] as String;
      final date = DateTime.parse(l['date_locale'] as String);
      final resultat = resultatParId[id];
      return CandidatDateProposition(
        id: id,
        date: date,
        disponibles: resultat?['disponibles'] as int? ?? 0,
        eligibles: resultat?['eligibles'] as int? ?? 0,
        moiDisponible: mesIdsDisponibles.contains(id),
        passee: date.isBefore(aujourdhuiSansHeure),
      );
    }).toList();

    final moiASoumis = await _client
        .from('disponibilites_soumises')
        .select('profil_id')
        .eq('proposition_id', propositionId)
        .eq('profil_id', _monId)
        .maybeSingle();

    final progressionRows =
        await _client.rpc('progression_disponibilite', params: {'p_proposition_id': propositionId})
            as List;
    final progressionSoumis = progressionRows.isEmpty ? 0 : progressionRows.first['soumis'] as int;
    final progressionEligibles =
        progressionRows.isEmpty ? 0 : progressionRows.first['eligibles'] as int;

    final confirmationRow = await _client
        .from('confirmations_proposition')
        .select('date_confirmee, heure_confirmee, fuseau_horaire')
        .eq('proposition_id', propositionId)
        .maybeSingle();
    final confirmation = confirmationRow == null
        ? null
        : ConfirmationProposition(
            date: DateTime.parse(confirmationRow['date_confirmee'] as String),
            heure: (confirmationRow['heure_confirmee'] as String?)?.substring(0, 5),
            fuseauHoraire: confirmationRow['fuseau_horaire'] as String,
          );

    final creePar = ligne['cree_par'] as String;
    final parMoi = creePar == _monId;
    // Règle 41 : creator, ou participant actif ayant répondu GO.
    final peutAccederChat = parMoi || monInteret == true;

    var nombreMessages = 0;
    if (peutAccederChat) {
      final messages = await _client
          .from('messages_organisation')
          .select('id')
          .eq('proposition_id', propositionId);
      nombreMessages = messages.length;
    }

    final restaurant = ligne['restaurants'] as Map<String, dynamic>?;
    final auteur = ligne['profils'] as Map<String, dynamic>?;
    final etat = ligne['etat'] as String;

    return DetailProposition(
      id: propositionId,
      restaurantNom: restaurant?['nom'] as String? ?? '',
      ville: restaurant?['ville'] as String? ?? '',
      proposePar: auteur?['pseudo'] as String? ?? '',
      parMoi: parMoi,
      active: _etatEstActif(etat),
      etatTexte: _etatPropositionTexte(etat, monInteret),
      nombreGo: nombreGo,
      monInteret: monInteret,
      candidats: candidats,
      progressionSoumis: progressionSoumis,
      progressionEligibles: progressionEligibles,
      moiAiSoumisReponse: moiASoumis != null,
      confirmation: confirmation,
      peutAccederChat: peutAccederChat,
      nombreMessages: nombreMessages,
    );
  }

  @override
  Future<void> definirDatesCandidates(
    String propositionId,
    List<DateTime> datesLocales,
  ) async {
    final existantes = await _client
        .from('dates_candidates_proposition')
        .select('id, date_locale')
        .eq('proposition_id', propositionId);
    final joursVoulus = datesLocales.map(_dateSeule).toSet();
    final idParJourExistant = <String, String>{
      for (final l in existantes) l['date_locale'] as String: l['id'] as String,
    };

    // Règle 31 : retirer une date supprime ses disponibilités liées —
    // délégué à `on delete cascade` sur `disponibilites_proposition`.
    final idsASupprimer = [
      for (final entry in idParJourExistant.entries)
        if (!joursVoulus.contains(entry.key)) entry.value,
    ];
    if (idsASupprimer.isNotEmpty) {
      await _client.from('dates_candidates_proposition').delete().inFilter('id', idsASupprimer);
    }

    // Règle 32 : une date nouvellement ajoutée démarre sans réponse,
    // les réponses déjà données pour les autres dates restent valides.
    final joursAAjouter = joursVoulus.where((j) => !idParJourExistant.containsKey(j)).toList();
    if (joursAAjouter.isNotEmpty) {
      await _client.from('dates_candidates_proposition').insert([
        for (final jour in joursAAjouter)
          {'proposition_id': propositionId, 'date_locale': jour},
      ]);
    }

    await _client
        .from('table_propositions')
        .update({'etat': 'polling', 'maj_le': DateTime.now().toIso8601String()})
        .eq('id', propositionId)
        .eq('cree_par', _monId);
  }

  @override
  Future<void> soumettreDisponibilites(
    String propositionId,
    List<String> dateCandidateIds,
  ) async {
    final mesDatesPourCetteProposition = await _client
        .from('dates_candidates_proposition')
        .select('id')
        .eq('proposition_id', propositionId);
    final idsDeLaProposition = mesDatesPourCetteProposition.map((l) => l['id'] as String).toList();

    // Règle 12 : "modifier mes disponibilités" remplace, ne duplique
    // jamais — suppression de mon ancienne sélection avant réinsertion.
    if (idsDeLaProposition.isNotEmpty) {
      await _client
          .from('disponibilites_proposition')
          .delete()
          .eq('profil_id', _monId)
          .inFilter('date_candidate_id', idsDeLaProposition);
    }
    if (dateCandidateIds.isNotEmpty) {
      await _client.from('disponibilites_proposition').insert([
        for (final id in dateCandidateIds) {'date_candidate_id': id, 'profil_id': _monId},
      ]);
    }

    await _client.from('disponibilites_soumises').upsert({
      'proposition_id': propositionId,
      'profil_id': _monId,
      'soumis_le': DateTime.now().toIso8601String(),
    }, onConflict: 'proposition_id,profil_id');
  }

  @override
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  }) async {
    final candidat = await _client
        .from('dates_candidates_proposition')
        .select('date_locale')
        .eq('id', dateCandidateId)
        .single();

    await _client.from('confirmations_proposition').insert({
      'proposition_id': propositionId,
      'date_confirmee': candidat['date_locale'],
      'fuseau_horaire': fuseauHoraire,
      'confirme_par': _monId,
    });
    await _client
        .from('table_propositions')
        .update({'etat': 'confirmed', 'maj_le': DateTime.now().toIso8601String()})
        .eq('id', propositionId);

    final date = DateTime.parse(candidat['date_locale'] as String);
    await _messageSysteme(propositionId, 'Date confirmée : ${_jourMoisLisible(date)}.');
  }

  @override
  Future<void> ajouterHeure(String propositionId, String heure) async {
    await _client
        .from('confirmations_proposition')
        .update({'heure_confirmee': '$heure:00'})
        .eq('proposition_id', propositionId);
    await _messageSysteme(propositionId, 'Heure fixée : ${heure.replaceFirst(':', 'h')}.');
  }

  @override
  Future<void> replanifier(String propositionId) async {
    // Règle 52 : réouvre une nouvelle phase de dates sur la même
    // proposition, ne crée jamais une nouvelle publication.
    await _client.from('confirmations_proposition').delete().eq('proposition_id', propositionId);
    await _client
        .from('dates_candidates_proposition')
        .delete()
        .eq('proposition_id', propositionId);
    await _client
        .from('table_propositions')
        .update({'etat': 'polling', 'maj_le': DateTime.now().toIso8601String()})
        .eq('id', propositionId);

    final pseudo = await _monPseudo();
    await _messageSysteme(propositionId, '$pseudo a lancé une nouvelle recherche de dates.');
  }

  @override
  Future<void> annulerProposition(String propositionId) async {
    await _client
        .from('table_propositions')
        .update({'etat': 'cancelled', 'maj_le': DateTime.now().toIso8601String()})
        .eq('id', propositionId);
    await _messageSysteme(propositionId, 'La sortie a été annulée.');
  }

  @override
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) async {
    final lignes = await _client
        .from('messages_organisation')
        .select('id, auteur_id, contenu, cree_le, profils(pseudo)')
        .eq('proposition_id', propositionId)
        .order('cree_le');

    return lignes.map((l) {
      final auteur = l['profils'] as Map<String, dynamic>?;
      return MessageOrganisation(
        id: l['id'] as String,
        auteurId: l['auteur_id'] as String,
        auteurPseudo: auteur?['pseudo'] as String? ?? '',
        contenu: l['contenu'] as String,
        creeLe: DateTime.parse(l['cree_le'] as String),
        parMoi: l['auteur_id'] == _monId,
      );
    }).toList();
  }

  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) async {
    final texte = contenu.trim();
    if (texte.isEmpty) return;
    await _client.from('messages_organisation').insert({
      'proposition_id': propositionId,
      'auteur_id': _monId,
      'contenu': texte,
    });
  }

  @override
  Future<void> supprimerMessageOrganisation(String messageId) async {
    await _client.from('messages_organisation').delete().eq('id', messageId);
  }

  /// Message système (règle 45) — inséré comme un message ordinaire
  /// avec moi comme auteur : `messages_organisation` n'a pas de notion
  /// de message système séparée, seul le contenu le distingue.
  Future<void> _messageSysteme(String propositionId, String contenu) async {
    await _client.from('messages_organisation').insert({
      'proposition_id': propositionId,
      'auteur_id': _monId,
      'contenu': contenu,
    });
  }

  Future<String> _monPseudo() async {
    final ligne = await _client.from('profils').select('pseudo').eq('id', _monId).single();
    return ligne['pseudo'] as String;
  }

  static const _joursAbreges = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
  ];

  String _jourMoisLisible(DateTime date) => '${_joursAbreges[date.weekday - 1]} ${date.day}';

  String _dateSeule(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Chemins de photo des expériences les plus récentes de la Table,
  /// pour la mosaïque — pas la liste complète (règle 84).
  Future<List<String>> _cheminsPhotosRecents(String tableId, {required int limite}) async {
    final lignes = await _lignesHistoire(tableId);
    return lignes
        .map((l) => (l['souvenirs'] as Map<String, dynamic>)['photo_url'] as String?)
        .whereType<String>()
        .take(limite)
        .toList();
  }

  /// Les expériences associées à une Table, plus récentes d'abord — une
  /// requête normale sur `souvenirs` (via la relation
  /// `associations_experience_table`), plus besoin de la fonction
  /// `experiences_table` : la policy `souvenirs` accorde déjà l'accès
  /// (voir la migration `20260917030000...`).
  Future<List<Map<String, dynamic>>> _lignesHistoire(String tableId) async {
    final lignes = await _client
        .from('associations_experience_table')
        .select(
          'souvenirs!inner(id, photo_url, date_visite, emotion, '
          'restaurants(nom, ville), '
          'profils!souvenirs_auteur_id_fkey(pseudo))',
        )
        .eq('table_id', tableId)
        .eq('souvenirs.statut', 'publie')
        .order('date_visite', referencedTable: 'souvenirs', ascending: false);
    return (lignes as List).cast<Map<String, dynamic>>();
  }

  String _etatPropositionTexte(String etat, bool? monInteret) {
    switch (etat) {
      case 'active':
        if (monInteret == null) return 'À vous de voter';
        return monInteret ? 'Vous êtes partant' : 'Vous avez dit non';
      case 'cancelled':
        return 'Annulée';
      case 'declined':
        return 'Déclinée';
      case 'expired':
        return 'Expirée';
      case 'confirmed':
        return 'Confirmée';
      case 'completed':
        return 'Passé';
      default:
        // polling / date_selection : détail précis au Bloc 4.
        return 'Choisissez vos dates';
    }
  }

  bool _etatEstActif(String etat) {
    return etat == 'active' ||
        etat == 'polling' ||
        etat == 'date_selection' ||
        etat == 'confirmed';
  }

  Future<Map<String, String>> _resoudreUrlsPhotos(List<String> chemins) async {
    if (chemins.isEmpty) return {};
    final uniques = chemins.toSet().toList();
    final resultats = await _client.storage
        .from('souvenirs')
        .createSignedUrlsResult(uniques, 3600);

    final urlParChemin = <String, String>{};
    for (final resultat in resultats) {
      if (resultat is SignedUrlSuccess) {
        urlParChemin[resultat.path] = resultat.signedUrl;
      }
    }
    return urlParChemin;
  }

  /// Même logique find-or-create que `SouvenirServiceSupabase._idRestaurant`
  /// — dupliquée volontairement plutôt que partagée : toucher aux
  /// fichiers `souvenirs/` est hors périmètre du Bloc 3 (SURGICAL).
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

  String _echapperJokers(String valeur) {
    return valeur
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }
}
