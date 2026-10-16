import 'package:supabase_flutter/supabase_flutter.dart';

import 'abonnement_service.dart';
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
          .select('id, pseudo')
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

    final statutParId = <String, StatutAbonnement>{};
    for (final r in relations) {
      final suiveurId = r['suiveur_id'] as String;
      final suiviId = r['suivi_id'] as String;
      final accepte = r['statut'] == 'accepte';
      if (suiveurId == _monId && ids.contains(suiviId)) {
        statutParId[suiviId] = accepte
            ? StatutAbonnement.abonne
            : StatutAbonnement.demandeEnvoyee;
      } else if (suiviId == _monId && ids.contains(suiveurId)) {
        statutParId[suiveurId] = accepte
            ? StatutAbonnement.abonne
            : StatutAbonnement.demandeRecue;
      }
    }

    return profils
        .map(
          (p) => ProfilPublic(
            id: p['id'] as String,
            pseudo: p['pseudo'] as String,
            statut: statutParId[p['id']] ?? StatutAbonnement.aucun,
          ),
        )
        .toList();
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
        .select('id, pseudo')
        .inFilter('id', ids);

    return profils
        .map(
          (p) => DemandeAbonnement(
            suiveurId: p['id'] as String,
            pseudo: p['pseudo'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> accepterDemande(String suiveurId) async {
    await _client
        .from('abonnements')
        .update({'statut': 'accepte'})
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
        .select('suiveur_id, suivi_id, profils_suiveur:profils!suiveur_id(pseudo), '
            'profils_suivi:profils!suivi_id(pseudo)')
        .eq('statut', 'accepte')
        .or('suiveur_id.eq.$_monId,suivi_id.eq.$_monId');

    final amis = <String, String>{};
    for (final l in lignes) {
      final suiveurId = l['suiveur_id'] as String;
      final suiviId = l['suivi_id'] as String;
      if (suiveurId == _monId) {
        final profil = l['profils_suivi'] as Map<String, dynamic>?;
        final pseudo = profil?['pseudo'] as String?;
        if (pseudo != null) amis[suiviId] = pseudo;
      } else {
        final profil = l['profils_suiveur'] as Map<String, dynamic>?;
        final pseudo = profil?['pseudo'] as String?;
        if (pseudo != null) amis[suiveurId] = pseudo;
      }
    }

    return amis.entries
        .map(
          (e) => ProfilPublic(
            id: e.key,
            pseudo: e.value,
            statut: StatutAbonnement.abonne,
          ),
        )
        .toList();
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

    final ids = {...abonnesIds, ...abonnementsIds}.toList();
    if (ids.isEmpty) return (abonnes: <ProfilPublic>[], abonnements: <ProfilPublic>[]);
    final profils = await _client
        .from('profils')
        .select('id, pseudo')
        .inFilter('id', ids);
    final pseudos = {
      for (final p in profils) p['id'] as String: p['pseudo'] as String,
    };

    List<ProfilPublic> liste(List<String> ids) {
      final resultat = [
        for (final id in ids)
          if (pseudos[id] != null)
            ProfilPublic(
              id: id,
              pseudo: pseudos[id]!,
              statut: monStatutVers[id] ?? StatutAbonnement.aucun,
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
  Future<void> definirProfilPrive(bool prive) async {
    await _client
        .from('profils')
        .update({'est_prive': prive})
        .eq('id', _monId);
    if (prive) return;
    await _client
        .from('abonnements')
        .update({'statut': 'accepte'})
        .eq('suivi_id', _monId)
        .eq('statut', 'en_attente');
  }
}
