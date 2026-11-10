import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../restaurants/lieu_restaurant.dart';
import '../restaurants/registre_restaurants.dart';
import 'publication_en_deux_temps.dart';

/// [DepotPublication] adossé à Supabase : bucket `souvenirs` et tables
/// `souvenirs`, `souvenirs_photos`, `souvenirs_empreintes`,
/// `souvenirs_amis_tagues`, `souvenirs_audience` et
/// `associations_experience_table`. Aucune policy nouvelle : celles de
/// l'auteur couvrent le brouillon comme le moment publié.
class DepotPublicationSupabase implements DepotPublication {
  DepotPublicationSupabase(this._client)
    : _restaurants = RegistreRestaurants(_client);

  final SupabaseClient _client;
  final RegistreRestaurants _restaurants;

  @override
  bool get connecte => _client.auth.currentSession != null;

  @override
  String get monId => _client.auth.currentSession!.user.id;

  @override
  Future<String?> statutDe(String momentId) async {
    final ligne = await _client
        .from('souvenirs')
        .select('statut')
        .eq('id', momentId)
        .maybeSingle();
    return ligne?['statut'] as String?;
  }

  @override
  Future<String> idRestaurant(LieuRestaurant lieu) => _restaurants.idPour(lieu);

  @override
  Future<void> deposerPhoto(String chemin, Uint8List octets) async {
    try {
      await _client.storage
          .from('souvenirs')
          .uploadBinary(
            chemin,
            octets,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } on StorageException catch (e) {
      // Déjà déposée par un essai précédent : l'état voulu est atteint.
      if (e.statusCode != '409') rethrow;
    }
  }

  @override
  Future<void> creerBrouillon(
    String momentId,
    Map<String, Object?> colonnes,
  ) async {
    try {
      await _client.from('souvenirs').insert({'id': momentId, ...colonnes});
    } on PostgrestException catch (e) {
      // Une relance a écrit la ligne entre-temps : on la met à jour.
      if (e.code != '23505') rethrow;
      await mettreAJourBrouillon(momentId, {
        for (final c in colonnes.entries)
          if (c.key != 'auteur_id' && c.key != 'statut') c.key: c.value,
      });
    }
  }

  @override
  Future<void> mettreAJourBrouillon(
    String momentId,
    Map<String, Object?> colonnes,
  ) async {
    await _client
        .from('souvenirs')
        .update(colonnes)
        .eq('id', momentId)
        .eq('statut', statutBrouillon);
  }

  @override
  Future<void> viderLiens(String momentId) async {
    // Les empreintes restent : l'app ne peut que les ajouter, et elles ne
    // donnent accès à rien.
    await (
      _client.from('souvenirs_photos').delete().eq('souvenir_id', momentId),
      _client
          .from('souvenirs_amis_tagues')
          .delete()
          .eq('souvenir_id', momentId),
      _client
          .from('associations_experience_table')
          .delete()
          .eq('souvenir_id', momentId),
    ).wait;
  }

  @override
  Future<void> ecrireLiens(
    String momentId, {
    required List<String> cheminsAutresPhotos,
    required Set<String> empreintes,
    required Set<String> amisTaguesIds,
    required Set<String> personnesAudienceIds,
  }) async {
    // Une ligne déjà écrite par un essai précédent est ignorée, pas
    // refusée.
    Future<void> inserer(
      String table,
      List<Map<String, Object?>> lignes,
      String cle,
    ) => lignes.isEmpty
        ? Future<void>.value()
        : _client
              .from(table)
              .upsert(lignes, onConflict: cle, ignoreDuplicates: true);

    await (
      inserer('souvenirs_photos', [
        for (var i = 0; i < cheminsAutresPhotos.length; i++)
          {
            'souvenir_id': momentId,
            'rang': i + 1,
            'chemin': cheminsAutresPhotos[i],
          },
      ], 'souvenir_id,rang'),
      inserer('souvenirs_empreintes', [
        for (final e in empreintes) {'souvenir_id': momentId, 'empreinte': e},
      ], 'souvenir_id,empreinte'),
      inserer('souvenirs_amis_tagues', [
        for (final p in amisTaguesIds)
          {'souvenir_id': momentId, 'profil_id': p},
      ], 'souvenir_id,profil_id'),
      ecrirePersonnesAudience(_client, momentId, personnesAudienceIds),
    ).wait;
  }

  @override
  Future<List<String>> associerTables(String momentId, Set<String> tableIds) =>
      associerTablesAuMoment(_client, momentId, tableIds.toList());

  @override
  Future<bool> passerEnPublie(String momentId) async {
    final lignes = await _client
        .from('souvenirs')
        .update({'statut': statutPublie})
        .eq('id', momentId)
        .eq('statut', statutBrouillon)
        .select('id');
    return lignes.isNotEmpty;
  }

  @override
  Future<List<String>> fichiersDuMoment(String momentId) async {
    final fichiers = await _client.storage
        .from('souvenirs')
        .list(
          path: monId,
          searchOptions: SearchOptions(search: '$momentId-'),
        );
    return [
      for (final f in fichiers)
        if (f.name.startsWith('$momentId-')) '$monId/${f.name}',
    ];
  }

  @override
  Future<List<({String id, DateTime creeLe})>> brouillonsDuServeur() async {
    final lignes = await _client
        .from('souvenirs')
        .select('id, cree_le')
        .eq('auteur_id', monId)
        .eq('statut', statutBrouillon);
    return [
      for (final l in lignes)
        (id: l['id'] as String, creeLe: DateTime.parse(l['cree_le'] as String)),
    ];
  }

  @override
  Future<bool> supprimerLigne(String momentId) async {
    // Les lignes liées (photos, empreintes, audience…) suivent.
    // On ne supprime que si le moment est encore en brouillon : si un autre
    // téléphone l'a publié entre-temps, la suppression ne fait rien
    // (0 ligne affectée) et le moment publié est préservé.
    final supprimees = await _client
        .from('souvenirs')
        .delete()
        .eq('id', momentId)
        .eq('statut', statutBrouillon)
        .select('id');
    return supprimees.isNotEmpty;
  }

  @override
  Future<void> supprimerFichiers(List<String> chemins) =>
      _client.storage.from('souvenirs').remove(chemins);
}

/// Remplace la liste des personnes choisies (autorisées ou exclues selon
/// le mode) par [personneIds].
Future<void> ecrirePersonnesAudience(
  SupabaseClient client,
  String souvenirId,
  Set<String> personneIds,
) async {
  await client
      .from('souvenirs_audience')
      .delete()
      .eq('souvenir_id', souvenirId);
  if (personneIds.isEmpty) return;
  await client.from('souvenirs_audience').insert([
    for (final profilId in personneIds)
      {'souvenir_id': souvenirId, 'profil_id': profilId},
  ]);
}

/// Associe [souvenirId] à chaque Table de [tableIds] (règle 26-28, 39) —
/// un insert par Table plutôt qu'une transaction unique (l'architecture
/// cliente Supabase ne permet pas de transaction multi-lignes explicite
/// ici, voir plan Bloc 5). Best-effort délibéré : le moment existe déjà à
/// ce stade, un échec partiel ne doit jamais faire disparaître les Tables
/// qui ont réussi (règle 51). Retourne les identifiants de Table qui ont
/// échoué — jamais d'exception silencieuse.
Future<List<String>> associerTablesAuMoment(
  SupabaseClient client,
  String souvenirId,
  List<String> tableIds,
) async {
  final monId = client.auth.currentSession!.user.id;
  final echecs = <String>[];
  for (final tableId in tableIds) {
    try {
      await client.from('associations_experience_table').insert({
        'souvenir_id': souvenirId,
        'table_id': tableId,
        'ajoute_par': monId,
      });
    } on PostgrestException catch (e) {
      // Déjà associée (double tap, relance, règle 55) : l'état voulu est
      // déjà atteint, pas une vraie erreur. Sinon (membership perdue entre
      // la sélection et l'envoi, Table supprimée...) : on continue les
      // autres Tables plutôt que de tout annuler (règle 51).
      if (e.code != '23505') echecs.add(tableId);
    }
  }
  return echecs;
}
