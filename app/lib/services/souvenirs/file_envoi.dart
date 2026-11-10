import 'dart:io';

import 'brouillon_local.dart';

/// Où en est la publication d'un brouillon.
enum EtatEnvoi {
  /// L'auteur veut qu'elle parte dès que possible (« Envoyer dès que
  /// possible ») : elle est relancée à l'ouverture de l'app, à sa reprise et
  /// sur « Réessayer », jusqu'à ce qu'elle aboutisse.
  enAttente,

  /// La cloche est à l'écran : l'envoi est en cours dans l'app ouverte. Si
  /// l'app est quittée à ce moment, l'envoi est interrompu.
  enCours,

  /// L'envoi a échoué et la cloche attend le choix de l'auteur (Garder /
  /// Réessayer / Envoyer dès que possible).
  echec,

  /// L'auteur a gardé son brouillon mais le serveur n'a pas pu être nettoyé
  /// (hors ligne) : la suppression du brouillon serveur reste à faire.
  aAbandonner,
}

/// Une publication dont le serveur peut garder une trace : une ligne dans la
/// file d'envoi, sur le téléphone, à côté du brouillon du même identifiant.
class EnvoiPublication {
  const EnvoiPublication({
    required this.brouillonId,
    required this.auteurId,
    required this.etat,
    required this.creeLe,
    this.commitLance = false,
    this.tentatives = 0,
    this.derniereErreur,
  });

  /// L'identifiant du brouillon local, qui est aussi celui du moment sur le
  /// serveur (la clé d'idempotence).
  final String brouillonId;

  /// Le compte qui publie : une file n'envoie jamais pour un autre compte.
  final String auteurId;
  final EtatEnvoi etat;
  final DateTime creeLe;

  /// Vrai dès que l'ordre de publier (le commit) est parti : ce que le
  /// serveur a fait ensuite, le téléphone peut l'ignorer.
  final bool commitLance;
  final int tentatives;
  final String? derniereErreur;

  EnvoiPublication copieAvec({
    EtatEnvoi? etat,
    bool? commitLance,
    int? tentatives,
    String? Function()? derniereErreur,
  }) => EnvoiPublication(
    brouillonId: brouillonId,
    auteurId: auteurId,
    etat: etat ?? this.etat,
    creeLe: creeLe,
    commitLance: commitLance ?? this.commitLance,
    tentatives: tentatives ?? this.tentatives,
    derniereErreur: derniereErreur != null
        ? derniereErreur()
        : this.derniereErreur,
  );

  Map<String, Object?> versJson() => {
    'version': 1,
    'brouillonId': brouillonId,
    'auteurId': auteurId,
    'etat': etat.name,
    'creeLe': creeLe.toIso8601String(),
    'commitLance': commitLance,
    'tentatives': tentatives,
    'derniereErreur': derniereErreur,
  };

  static EnvoiPublication depuisJson(Map<String, dynamic> json) =>
      EnvoiPublication(
        brouillonId: json['brouillonId'] as String,
        auteurId: json['auteurId'] as String,
        etat: EtatEnvoi.values.byName(json['etat'] as String),
        creeLe: DateTime.parse(json['creeLe'] as String),
        commitLance: json['commitLance'] as bool? ?? false,
        tentatives: json['tentatives'] as int? ?? 0,
        derniereErreur: json['derniereErreur'] as String?,
      );
}

/// La file d'envoi des publications, sur le téléphone : un fichier JSON par
/// publication, dans `envois/` à côté des brouillons. Chaque changement est
/// écrit aussitôt (et de façon atomique), pour qu'une fermeture de l'app à
/// n'importe quel moment laisse un état relisible.
class FileEnvoi {
  FileEnvoi(Directory racine) : _dossier = Directory('${racine.path}/envois');

  final Directory _dossier;

  Future<void> _file = Future.value();

  File _fichier(String brouillonId) =>
      File('${_dossier.path}/$brouillonId.json');

  Future<T> _enchainer<T>(Future<T> Function() action) {
    final resultat = _file.then((_) => action());
    _file = resultat.then((_) {}, onError: (_) {});
    return resultat;
  }

  Future<EnvoiPublication?> lire(String brouillonId) =>
      _enchainer(() => _lire(brouillonId));

  /// Toutes les publications de la file, la plus ancienne d'abord. Un
  /// fichier illisible est ignoré.
  Future<List<EnvoiPublication>> lister() => _enchainer(() async {
    if (!await _dossier.exists()) return const [];
    final envois = <EnvoiPublication>[];
    await for (final fichier in _dossier.list()) {
      if (fichier is! File || !fichier.path.endsWith('.json')) continue;
      final nom = fichier.uri.pathSegments.last;
      final envoi = await _lire(nom.substring(0, nom.length - '.json'.length));
      if (envoi != null) envois.add(envoi);
    }
    envois.sort((a, b) => a.creeLe.compareTo(b.creeLe));
    return envois;
  });

  Future<void> ecrire(EnvoiPublication envoi) => _enchainer(
    () => ecrireJsonAtomique(_fichier(envoi.brouillonId), envoi.versJson()),
  );

  /// Lit, transforme puis écrit d'un seul tenant : pas de changement perdu
  /// entre deux étapes concurrentes. Ne fait rien si la ligne n'existe plus.
  Future<EnvoiPublication?> modifier(
    String brouillonId,
    EnvoiPublication Function(EnvoiPublication actuel) transformation,
  ) => _enchainer(() async {
    final actuel = await _lire(brouillonId);
    if (actuel == null) return null;
    final modifie = transformation(actuel);
    await ecrireJsonAtomique(_fichier(brouillonId), modifie.versJson());
    return modifie;
  });

  Future<void> retirer(String brouillonId) => _enchainer(() async {
    final fichier = _fichier(brouillonId);
    if (await fichier.exists()) await fichier.delete();
  });

  Future<EnvoiPublication?> _lire(String brouillonId) async {
    final json = await lireJson(_fichier(brouillonId));
    if (json == null) return null;
    try {
      return EnvoiPublication.depuisJson(json);
    } catch (_) {
      return null;
    }
  }
}
