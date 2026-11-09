import 'dart:typed_data';

import 'package:app/services/services.dart';

/// Le serveur en mémoire : une ligne `souvenirs` par id, des fichiers, et
/// les pannes qu'un test peut déclencher.
class DepotPublicationSimule implements DepotPublication {
  @override
  final monId = 'auteur-1';

  @override
  bool connecte = true;

  final lignes = <String, Map<String, Object?>>{};
  final fichiers = <String, Uint8List>{};
  final liens = <String, Set<String>>{};
  final tables = <String, Set<String>>{};
  final appels = <String>[];

  /// Le dépôt du fichier de ce rang échoue (réseau coupé).
  int? echecAuRang;
  bool echecAuCommit = false;

  /// Le serveur reçoit l'ordre de publier, mais la réponse se perd.
  bool reponsePerdueAuCommit = false;

  /// Aucun échange avec le serveur n'aboutit.
  bool horsLigne = false;
  Set<String> tablesRefusees = {};

  void _reseau() {
    if (horsLigne) throw StateError('hors ligne');
  }

  @override
  Future<String?> statutDe(String momentId) async {
    _reseau();
    return lignes[momentId]?['statut'] as String?;
  }

  @override
  Future<String> idRestaurant(LieuRestaurant lieu) async => 'resto-1';

  @override
  Future<void> deposerPhoto(String chemin, Uint8List octets) async {
    _reseau();
    appels.add('depot $chemin');
    if (echecAuRang != null && chemin.endsWith('-$echecAuRang.jpg')) {
      throw StateError('réseau coupé');
    }
    // Comme le stockage : un fichier déjà là n'est pas remplacé (409).
    fichiers.putIfAbsent(chemin, () => octets);
  }

  @override
  Future<void> creerBrouillon(
    String momentId,
    Map<String, Object?> colonnes,
  ) async {
    appels.add('creer');
    if (lignes.containsKey(momentId)) throw StateError('23505');
    lignes[momentId] = {...colonnes};
  }

  @override
  Future<void> mettreAJourBrouillon(
    String momentId,
    Map<String, Object?> colonnes,
  ) async {
    appels.add('maj');
    lignes[momentId]!.addAll(colonnes);
  }

  @override
  Future<void> viderLiens(String momentId) async {
    appels.add('vider liens');
    liens.remove('photos');
    liens.remove('amis');
    tables.remove(momentId);
  }

  @override
  Future<void> ecrireLiens(
    String momentId, {
    required List<String> cheminsAutresPhotos,
    required Set<String> empreintes,
    required Set<String> amisTaguesIds,
    required Set<String> personnesAudienceIds,
  }) async {
    liens['photos'] = {...?liens['photos'], ...cheminsAutresPhotos};
    liens['empreintes'] = {...?liens['empreintes'], ...empreintes};
    liens['amis'] = {...?liens['amis'], ...amisTaguesIds};
    liens['audience'] = {...personnesAudienceIds};
  }

  @override
  Future<List<String>> associerTables(
    String momentId,
    Set<String> tableIds,
  ) async {
    final reussies = tableIds.difference(tablesRefusees);
    tables[momentId] = {...?tables[momentId], ...reussies};
    return tableIds.intersection(tablesRefusees).toList();
  }

  @override
  Future<bool> passerEnPublie(String momentId) async {
    _reseau();
    appels.add('commit');
    if (echecAuCommit) throw StateError('réseau coupé');
    final ligne = lignes[momentId];
    if (ligne == null || ligne['statut'] != statutBrouillon) return false;
    ligne['statut'] = statutPublie;
    if (reponsePerdueAuCommit) throw StateError('réponse perdue');
    return true;
  }

  @override
  Future<List<String>> fichiersDuMoment(String momentId) async {
    _reseau();
    return [
      for (final chemin in fichiers.keys)
        if (chemin.startsWith('$monId/$momentId-')) chemin,
    ];
  }

  @override
  Future<List<({String id, DateTime creeLe})>> brouillonsDuServeur() async {
    _reseau();
    return [
      for (final l in lignes.entries)
        if (l.value['statut'] == statutBrouillon)
          (
            id: l.key,
            creeLe: l.value['cree_le'] as DateTime? ?? DateTime(2026, 11, 8),
          ),
    ];
  }

  @override
  Future<void> supprimerLigne(String momentId) async {
    _reseau();
    appels.add('suppression ligne');
    lignes.remove(momentId);
    tables.remove(momentId);
  }

  @override
  Future<void> supprimerFichiers(List<String> chemins) async {
    _reseau();
    appels.add('suppression fichiers');
    chemins.forEach(fichiers.remove);
  }
}
