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
  Future<void> suivre(String suiviId) async {
    await _client.from('abonnements').insert({
      'suiveur_id': _monId,
      'suivi_id': suiviId,
    });
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
}
