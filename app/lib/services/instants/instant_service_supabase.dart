import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'instant_affichable.dart';
import 'instant_service.dart';
import 'instants_config.dart';
import 'signal_instants.dart';
import 'type_media_instant.dart';

/// Instants adossés à Supabase (bucket Storage `instants`, tables
/// `instants` et `instant_vues` — voir la migration
/// `20260917040000_instants.sql`).
class InstantServiceSupabase implements InstantService {
  InstantServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<void> creer({
    required String experienceId,
    required TypeMediaInstant type,
    required Uint8List media,
  }) async {
    final parent = await _client
        .from('souvenirs')
        .select('cree_le')
        .eq('id', experienceId)
        .single();
    final creeLeParent = DateTime.parse(parent['cree_le'] as String);
    if (DateTime.now().isAfter(
      creeLeParent.add(InstantsConfig.fenetreCreation),
    )) {
      throw const FenetreInstantFermeeException();
    }

    final actifs = await _client
        .from('instants')
        .select('id')
        .eq('parent_experience_id', experienceId)
        .gt('expire_socialement_le', DateTime.now().toIso8601String());
    if ((actifs as List).length >= InstantsConfig.maxParExperience) {
      throw const LimiteInstantsAtteinteException();
    }

    final chemin = await _deposerMedia(media, type);
    final maintenant = DateTime.now();

    await _client.from('instants').insert({
      'parent_experience_id': experienceId,
      'owner_user_id': _monId,
      'media_type': type.valeur,
      'media_url': chemin,
      'expire_socialement_le': maintenant
          .add(InstantsConfig.dureeVisibiliteSociale)
          .toIso8601String(),
    });
  }

  @override
  Future<List<InstantAffichable>> instantsDe(String experienceId) async {
    final lignes = await _client
        .from('instants')
        .select('id, owner_user_id, media_type, media_url, cree_le')
        .eq('parent_experience_id', experienceId)
        .gt('expire_socialement_le', DateTime.now().toIso8601String())
        .order('cree_le');

    final chemins = lignes.map((l) => l['media_url'] as String).toList();
    final urlParChemin = await _resoudreUrls(chemins);

    return lignes.map((l) {
      final chemin = l['media_url'] as String;
      return InstantAffichable(
        id: l['id'] as String,
        mediaUrl: urlParChemin[chemin] ?? '',
        type: TypeMediaInstant.depuisValeur(l['media_type'] as String),
        creeLe: DateTime.parse(l['cree_le'] as String),
        estMoi: l['owner_user_id'] == _monId,
      );
    }).toList();
  }

  @override
  Future<void> marquerVu(String instantId) async {
    try {
      await _client.from('instant_vues').insert({
        'instant_id': instantId,
        'profil_id': _monId,
      });
    } on PostgrestException catch (e) {
      // Déjà marqué vu : l'état voulu est déjà atteint.
      if (e.code != '23505') rethrow;
    }
  }

  @override
  Future<void> supprimer(String instantId) async {
    await _client.from('instants').delete().eq('id', instantId);
  }

  @override
  Future<Map<String, SignalInstants>> signaux(
    List<String> experienceIds,
  ) async {
    if (experienceIds.isEmpty) return {};

    final instants = await _client
        .from('instants')
        .select('id, parent_experience_id, cree_le')
        .inFilter('parent_experience_id', experienceIds)
        .gt('expire_socialement_le', DateTime.now().toIso8601String());

    final idsInstants = (instants as List)
        .map((l) => l['id'] as String)
        .toList();
    final vues = idsInstants.isEmpty
        ? <String>{}
        : {
            for (final l in await _client
                .from('instant_vues')
                .select('instant_id')
                .inFilter('instant_id', idsInstants)
                .eq('profil_id', _monId))
              l['instant_id'] as String,
          };

    final parents = await _client
        .from('souvenirs')
        .select('id, cree_le, auteur_id')
        .inFilter('id', experienceIds)
        .eq('auteur_id', _monId);
    final creeLeParExperienceAMoi = {
      for (final l in parents)
        l['id'] as String: DateTime.parse(l['cree_le'] as String),
    };

    final parExperience = <String, List<Map<String, dynamic>>>{};
    for (final l in instants) {
      final experienceId = l['parent_experience_id'] as String;
      parExperience.putIfAbsent(experienceId, () => []).add(l);
    }

    return {
      for (final experienceId in experienceIds)
        experienceId: _construireSignal(
          parExperience[experienceId] ?? const [],
          vues,
          creeLeParExperienceAMoi[experienceId],
        ),
    };
  }

  SignalInstants _construireSignal(
    List<Map<String, dynamic>> lignes,
    Set<String> vues,
    DateTime? creeLeSiAMoi,
  ) {
    if (lignes.isEmpty) {
      return SignalInstants(
        total: 0,
        nonVus: 0,
        fenetreCreationOuverte:
            creeLeSiAMoi != null &&
            DateTime.now().isBefore(
              creeLeSiAMoi.add(InstantsConfig.fenetreCreation),
            ),
      );
    }

    var nonVus = 0;
    DateTime? plusRecent;
    for (final l in lignes) {
      if (!vues.contains(l['id'] as String)) nonVus++;
      final creeLe = DateTime.parse(l['cree_le'] as String);
      if (plusRecent == null || creeLe.isAfter(plusRecent)) plusRecent = creeLe;
    }

    return SignalInstants(
      total: lignes.length,
      nonVus: nonVus,
      fenetreCreationOuverte:
          creeLeSiAMoi != null &&
          DateTime.now().isBefore(
            creeLeSiAMoi.add(InstantsConfig.fenetreCreation),
          ),
      plusRecentActifLe: plusRecent,
    );
  }

  Future<Map<String, String>> _resoudreUrls(List<String> chemins) async {
    if (chemins.isEmpty) return {};

    final resultats = await _client.storage
        .from('instants')
        .createSignedUrlsResult(chemins, 3600);

    final urlParChemin = <String, String>{};
    for (final resultat in resultats) {
      if (resultat is SignedUrlSuccess) {
        urlParChemin[resultat.path] = resultat.signedUrl;
      }
    }
    return urlParChemin;
  }

  Future<String> _deposerMedia(Uint8List media, TypeMediaInstant type) async {
    final extension = type == TypeMediaInstant.photo ? 'jpg' : 'mp4';
    final contentType = type == TypeMediaInstant.photo
        ? 'image/jpeg'
        : 'video/mp4';
    final chemin = '$_monId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage
        .from('instants')
        .uploadBinary(
          chemin,
          media,
          fileOptions: FileOptions(contentType: contentType),
        );
    return chemin;
  }
}
