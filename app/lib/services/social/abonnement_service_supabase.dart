import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'abonnement_service.dart';
import 'photo_profil.dart';
import 'profil_public.dart';

/// Graphe social adossé à Supabase (table `abonnements`, voir migration
/// `20260823000000_abonnements_restaurants_souvenirs.sql`).
///
/// `abonnements` a deux clés étrangères vers `profils` (suiveur et
/// suivi), ce qui rend un embed PostgREST ambigu sans jouer avec le nom
/// de contrainte. Plus simple et plus robuste : deux requêtes séparées,
/// combinées ici.
class AbonnementServiceSupabase implements AbonnementService {
  AbonnementServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  /// La miniature de la photo d'une ligne de `profils` (colonne
  /// `photo_url`), pour les listes de personnes.
  String? _miniature(Map<String, dynamic> profil) => urlPhotoProfil(
    _client,
    profil['photo_url'] as String?,
    miniature: true,
  );

  @override
  Future<List<ProfilPublic>> rechercher(String requete) async {
    final v = requete.trim();
    if (v.isEmpty) return [];

    // Les deux requêtes sont indépendantes (la seconde ne filtre que sur
    // _monId, connu avant même que la première ne parte) : les lancer en
    // parallèle plutôt que d'attendre l'une puis l'autre.
    final resultats = await Future.wait([
      _client
          .from('profils')
          .select('id, pseudo, photo_url')
          .ilike('pseudo', '%$v%')
          .neq('id', _monId)
          .limit(20),
      _client
          .from('abonnements')
          .select('suiveur_id, suivi_id, statut')
          .or('suiveur_id.eq.$_monId,suivi_id.eq.$_monId'),
    ]);
    final profils = resultats[0];
    final relations = resultats[1];

    final ids = profils.map((p) => p['id'] as String).toList();
    if (ids.isEmpty) return [];

    // Les deux sens séparément : le bouton dit où j'en suis avec elle
    // (quelqu'un qui me suit n'est pas pour autant quelqu'un que je
    // suis), « Suivre en retour » dit qu'elle me suit déjà.
    final monStatutVers = <String, StatutAbonnement>{};
    final meSuivent = <String>{};
    final meDemandent = <String>{};
    for (final r in relations) {
      final suiveurId = r['suiveur_id'] as String;
      final suiviId = r['suivi_id'] as String;
      final accepte = r['statut'] == 'accepte';
      if (suiveurId == _monId) {
        monStatutVers[suiviId] = accepte
            ? StatutAbonnement.abonne
            : StatutAbonnement.demandeEnvoyee;
      } else if (accepte) {
        meSuivent.add(suiveurId);
      } else {
        meDemandent.add(suiveurId);
      }
    }

    return profils.map((p) {
      final id = p['id'] as String;
      return ProfilPublic(
        id: id,
        pseudo: p['pseudo'] as String,
        statut:
            monStatutVers[id] ??
            (meDemandent.contains(id)
                ? StatutAbonnement.demandeRecue
                : StatutAbonnement.aucun),
        meSuit: meSuivent.contains(id),
        photoUrl: _miniature(p),
      );
    }).toList();
  }

  @override
  Future<ProfilVisite> profil(String id) async {
    final (profil, relation, inverse) = await (
      _client
          .from('profils')
          .select('pseudo, photo_url, est_prive')
          .eq('id', id)
          .single(),
      _client
          .from('abonnements')
          .select('statut')
          .eq('suiveur_id', _monId)
          .eq('suivi_id', id)
          .maybeSingle(),
      // Dans l'autre sens : me suit-elle déjà ?
      _client
          .from('abonnements')
          .select('statut')
          .eq('suiveur_id', id)
          .eq('suivi_id', _monId)
          .eq('statut', 'accepte')
          .maybeSingle(),
    ).wait;
    return ProfilVisite(
      id: id,
      pseudo: profil['pseudo'] as String,
      photoUrl: urlPhotoProfil(_client, profil['photo_url'] as String?),
      estPrive: profil['est_prive'] as bool? ?? true,
      statut: switch (relation?['statut']) {
        null => StatutAbonnement.aucun,
        'accepte' => StatutAbonnement.abonne,
        _ => StatutAbonnement.demandeEnvoyee,
      },
      meSuit: inverse != null,
    );
  }

  @override
  Future<CompteursProfil> compteurs(String profilId) async {
    // Fonction de la base : les tables elles-mêmes ne laissent pas
    // compter ce qu'on ne peut pas voir (migration 20261020000000).
    final lignes = await _client.rpc(
      'compteurs_profil',
      params: {'p_profil': profilId},
    );
    final ligne = (lignes as List).first as Map<String, dynamic>;
    return (
      moments: ligne['moments'] as int,
      abonnes: ligne['abonnes'] as int,
      abonnements: ligne['abonnements'] as int,
    );
  }

  @override
  Future<StatutAbonnement> suivre(String suiviId) async {
    final profil = await _client
        .from('profils')
        .select('est_prive')
        .eq('id', suiviId)
        .single();
    final immediat = profil['est_prive'] == false;
    // La policy d'insertion n'accepte 'accepte' que vers un profil
    // public : si le profil vient de repasser en privé entre-temps,
    // l'insertion échoue plutôt que de contourner son accord.
    await _client.from('abonnements').insert({
      'suiveur_id': _monId,
      'suivi_id': suiviId,
      'statut': immediat ? 'accepte' : 'en_attente',
      // Quand le suivi a commencé : la notification « vous suit ».
      if (immediat) 'accepte_le': DateTime.now().toUtc().toIso8601String(),
    });
    return immediat
        ? StatutAbonnement.abonne
        : StatutAbonnement.demandeEnvoyee;
  }

  @override
  Future<void> arreterDeSuivre(String suiviId) async {
    await _client
        .from('abonnements')
        .delete()
        .eq('suiveur_id', _monId)
        .eq('suivi_id', suiviId);
  }

  @override
  Future<List<DemandeAbonnement>> demandesRecues() async {
    final lignes = await _client
        .from('abonnements')
        .select('suiveur_id')
        .eq('suivi_id', _monId)
        .eq('statut', 'en_attente');

    final ids = lignes.map((l) => l['suiveur_id'] as String).toList();
    if (ids.isEmpty) return [];

    final profils = await _client
        .from('profils')
        .select('id, pseudo, photo_url')
        .inFilter('id', ids);

    return profils
        .map(
          (p) => DemandeAbonnement(
            suiveurId: p['id'] as String,
            pseudo: p['pseudo'] as String,
            photoUrl: _miniature(p),
          ),
        )
        .toList();
  }

  @override
  Future<void> accepterDemande(String suiveurId) async {
    await _client
        .from('abonnements')
        .update({
          'statut': 'accepte',
          // « Clara a accepté votre demande », chez celui qui l'a faite.
          'accepte_le': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('suiveur_id', suiveurId)
        .eq('suivi_id', _monId);
  }

  @override
  Future<void> refuserDemande(String suiveurId) async {
    await _client
        .from('abonnements')
        .delete()
        .eq('suiveur_id', suiveurId)
        .eq('suivi_id', _monId);
  }

  @override
  Future<int> nombreDemandesEnAttente() async {
    final lignes = await _client
        .from('abonnements')
        .select('suiveur_id')
        .eq('suivi_id', _monId)
        .eq('statut', 'en_attente');
    return lignes.length;
  }

  @override
  Future<List<ProfilPublic>> mesRelations() async {
    final lignes = await _client
        .from('abonnements')
        .select('suiveur_id, suivi_id, profils_suiveur:profils!suiveur_id(pseudo, photo_url), '
            'profils_suivi:profils!suivi_id(pseudo, photo_url)')
        .eq('statut', 'accepte')
        .or('suiveur_id.eq.$_monId,suivi_id.eq.$_monId');

    final amis = <String, ProfilPublic>{};
    for (final l in lignes) {
      final suiveurId = l['suiveur_id'] as String;
      final suiviId = l['suivi_id'] as String;
      final (id, profil) = suiveurId == _monId
          ? (suiviId, l['profils_suivi'] as Map<String, dynamic>?)
          : (suiveurId, l['profils_suiveur'] as Map<String, dynamic>?);
      final pseudo = profil?['pseudo'] as String?;
      if (pseudo == null) continue;
      amis[id] = ProfilPublic(
        id: id,
        pseudo: pseudo,
        statut: StatutAbonnement.abonne,
        photoUrl: _miniature(profil!),
      );
    }

    return amis.values.toList();
  }

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async {
    final lignes = await _client
        .from('abonnements')
        .select('suiveur_id, suivi_id, statut')
        .or('suiveur_id.eq.$_monId,suivi_id.eq.$_monId');

    final abonnesIds = <String>[];
    final abonnementsIds = <String>[];
    final monStatutVers = <String, StatutAbonnement>{};
    for (final l in lignes) {
      final suiveurId = l['suiveur_id'] as String;
      final suiviId = l['suivi_id'] as String;
      final accepte = l['statut'] == 'accepte';
      if (suiveurId == _monId) {
        monStatutVers[suiviId] = accepte
            ? StatutAbonnement.abonne
            : StatutAbonnement.demandeEnvoyee;
        if (accepte) abonnementsIds.add(suiviId);
      } else if (accepte) {
        abonnesIds.add(suiveurId);
      }
    }

    final meSuivent = abonnesIds.toSet();
    final ids = {...abonnesIds, ...abonnementsIds}.toList();
    if (ids.isEmpty) return (abonnes: <ProfilPublic>[], abonnements: <ProfilPublic>[]);
    final profils = await _client
        .from('profils')
        .select('id, pseudo, photo_url')
        .inFilter('id', ids);
    final parId = {for (final p in profils) p['id'] as String: p};

    List<ProfilPublic> liste(List<String> ids) {
      final resultat = [
        for (final id in ids)
          if (parId[id] case final p?)
            ProfilPublic(
              id: id,
              pseudo: p['pseudo'] as String,
              statut: monStatutVers[id] ?? StatutAbonnement.aucun,
              meSuit: meSuivent.contains(id),
              photoUrl: _miniature(p),
            ),
      ];
      resultat.sort(
        (a, b) => a.pseudo.toLowerCase().compareTo(b.pseudo.toLowerCase()),
      );
      return resultat;
    }

    return (abonnes: liste(abonnesIds), abonnements: liste(abonnementsIds));
  }

  @override
  Future<Set<String>> mesAbonnesIds() async {
    final lignes = await _client
        .from('abonnements')
        .select('suiveur_id')
        .eq('suivi_id', _monId)
        .eq('statut', 'accepte');
    return lignes.map((l) => l['suiveur_id'] as String).toSet();
  }

  @override
  Future<bool> monProfilEstPrive() async {
    final profil = await _client
        .from('profils')
        .select('est_prive')
        .eq('id', _monId)
        .single();
    return profil['est_prive'] as bool? ?? true;
  }

  @override
  Future<String> definirPhotoProfil(Uint8List photo) async {
    // Un nom nouveau à chaque fois : l'ancienne adresse, encore en cache
    // dans les images déjà affichées, ne montre jamais la nouvelle photo
    // par erreur. La miniature (voir `cheminMiniature`) reçoit la même
    // image, déjà petite (l'app la réduit avant l'envoi).
    final chemin = '$_monId/photo-${DateTime.now().millisecondsSinceEpoch}.jpg';
    const options = FileOptions(contentType: 'image/jpeg');
    await Future.wait([
      _client.storage
          .from('avatars')
          .uploadBinary(chemin, photo, fileOptions: options),
      _client.storage
          .from('avatars')
          .uploadBinary(cheminMiniature(chemin), photo, fileOptions: options),
    ]);
    await _client
        .from('profils')
        .update({'photo_url': chemin})
        .eq('id', _monId);
    return urlPhotoProfil(_client, chemin)!;
  }

  @override
  Future<void> definirProfilPrive(bool prive) async {
    await _client.from('profils').update({'est_prive': prive}).eq('id', _monId);
    if (prive) return;
    await _client
        .from('abonnements')
        .update({
          'statut': 'accepte',
          'accepte_le': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('suivi_id', _monId)
        .eq('statut', 'en_attente');
  }
}
