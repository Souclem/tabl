import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brouillon_local.dart';
import 'file_envoi.dart';
import 'publication_en_deux_temps.dart';
import 'publication_service.dart';

/// Une ligne `brouillon` du serveur que rien ne réclame (ni file d'envoi ni
/// envoi en cours) n'est supprimée qu'après ce délai : un autre téléphone du
/// même compte peut être en train de publier.
const delaiOrphelineServeur = Duration(hours: 24);

enum StatutEnvoi {
  /// Le moment est publié : le brouillon local et la file l'ont oublié.
  publie,

  /// L'envoi a échoué ; l'état de la file dit ce qui se passe ensuite (la
  /// cloche attend le choix de l'auteur).
  echec,

  /// Cette publication est déjà en cours de traitement (cloche, reprise).
  dejaEnCours,

  /// Le brouillon local n'existe plus.
  introuvable,

  /// Il manque le lieu ou l'émotion : rien ne part.
  incomplet,

  /// L'auteur a annulé avant le commit : rien n'a été publié.
  annule,
}

class ResultatEnvoi {
  const ResultatEnvoi(
    this.statut, {
    this.erreur,
    this.tablesEnEchec = const [],
    this.dejaPublie = false,
  });

  final StatutEnvoi statut;
  final Object? erreur;

  /// Vrai avec [StatutEnvoi.publie] quand le serveur avait déjà publié ce
  /// moment (le commit d'un essai précédent avait abouti) : les
  /// modifications du brouillon n'ont pas été appliquées.
  final bool dejaPublie;

  /// Les Tables dont l'association a échoué (voir [MomentPrepare]).
  final List<String> tablesEnEchec;

  bool get estPublie => statut == StatutEnvoi.publie;
}

enum IssueReprise {
  /// Le moment a été publié pendant l'absence de l'auteur (« Publié pendant
  /// votre absence »).
  publiee,

  /// L'envoi a été interrompu quand l'auteur a quitté l'app avant le
  /// commit : rien n'a été envoyé, le brouillon est gardé (« Publication
  /// interrompue quand vous avez quitté Tabl. · rien n'a été envoyé »).
  interrompue,
}

/// Ce que la reprise a constaté, à montrer à l'auteur une fois.
class ResultatReprise {
  const ResultatReprise(this.brouillonId, this.issue);

  final String brouillonId;
  final IssueReprise issue;
}

/// Publie les brouillons et rattrape ce que l'app a laissé en route.
///
/// Le brouillon local reste sur le téléphone jusqu'à la confirmation du
/// serveur ; chaque publication passe par la [FileEnvoi], écrite avant le
/// premier envoi. Après une fermeture de l'app, [reprendre] relit la file et
/// la compare au serveur (jamais de commit en double : l'id du brouillon est
/// la clé d'idempotence) :
///
/// - **en attente** (l'auteur a choisi « Envoyer dès que possible ») : relancée
///   jusqu'à ce qu'elle aboutisse ;
/// - **interrompue avant le commit** : le brouillon serveur est supprimé, le
///   brouillon local est gardé ;
/// - **interrompue après le commit** : le commit est mené à terme, ou
///   constaté — le brouillon local est alors effacé, publié ou supprimé
///   depuis ;
/// - une ligne `brouillon` du serveur qu'aucune file ne réclame est supprimée
///   après [delaiOrphelineServeur].
///
/// Pas de `connectivity_plus` ni de tâche d'arrière-plan : la file repart à
/// l'ouverture de l'app, à sa reprise ([ReprisePublications]) et sur
/// « Réessayer » ([envoyer]).
class EnvoiPublications {
  EnvoiPublications(
    this._depot,
    this._brouillons,
    this._file, {
    PublicationService? service,
    DateTime Function()? maintenant,
  }) : _service = service ?? PublicationEnDeuxTemps(_depot),
       _maintenant = maintenant ?? DateTime.now;

  /// Ouvre les brouillons du téléphone et leur file d'envoi.
  static Future<EnvoiPublications> ouvrir(DepotPublication depot) async {
    final brouillons = await BrouillonsLocaux.ouvrir();
    return EnvoiPublications(depot, brouillons, FileEnvoi(brouillons.racine));
  }

  final DepotPublication _depot;
  final BrouillonsLocaux _brouillons;
  final FileEnvoi _file;
  final PublicationService _service;
  final DateTime Function() _maintenant;

  /// Les publications en cours de traitement dans cette session de l'app.
  final _actifs = <String, Future<Object?>>{};
  final _annulations = <String>{};
  Future<List<ResultatReprise>>? _reprise;

  /// Ce que la reprise a constaté et que l'écran n'a pas encore montré.
  /// L'écran qui l'affiche appelle [acquitter].
  final aMontrer = ValueNotifier<List<ResultatReprise>>(const []);

  void acquitter(ResultatReprise resultat) {
    aMontrer.value = [
      for (final r in aMontrer.value)
        if (r != resultat) r,
    ];
  }

  /// Vrai quand une session est ouverte : sans elle, rien ne peut partir.
  bool get connecte => _depot.connecte;

  /// Les publications que l'auteur a demandé d'envoyer dès que possible
  /// (« En attente d'envoi »), la plus ancienne d'abord ; vide sans session.
  Future<List<EnvoiPublication>> enAttenteDEnvoi() async {
    if (!_depot.connecte) return const [];
    final moi = _depot.monId;
    return [
      for (final e in await _file.lister())
        if (e.auteurId == moi && e.etat == EtatEnvoi.enAttente) e,
    ];
  }

  /// Publie le brouillon, au premier plan (la cloche) ou sur « Réessayer ».
  /// [surProgression] reçoit (photos envoyées, total). Une erreur ne lève
  /// rien : le résultat est [StatutEnvoi.echec] et la file passe en
  /// [EtatEnvoi.echec], dans l'attente du choix de l'auteur ([garderEnBrouillon],
  /// [mettreEnAttente] ou un nouvel essai).
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    final resultat = await _verrouiller(
      brouillonId,
      () => _tenter(
        brouillonId,
        auPremierPlan: true,
        surProgression: surProgression,
      ),
    );
    return resultat ?? const ResultatEnvoi(StatutEnvoi.dejaEnCours);
  }

  /// « Envoyer dès que possible » : la publication est gardée dans la file
  /// et repart à la prochaine ouverture ou reprise de l'app. Faux si le
  /// brouillon n'existe plus.
  Future<bool> mettreEnAttente(String brouillonId) async {
    if (await _brouillons.charger(brouillonId) == null) return false;
    final modifie = await _file.modifier(
      brouillonId,
      (e) => e.copieAvec(etat: EtatEnvoi.enAttente),
    );
    if (modifie == null) {
      await _file.ecrire(
        EnvoiPublication(
          brouillonId: brouillonId,
          auteurId: _depot.monId,
          etat: EtatEnvoi.enAttente,
          creeLe: _maintenant(),
        ),
      );
    }
    return true;
  }

  /// « Garder en brouillon » ou « Annuler » : ce qui a été envoyé est
  /// défait, le brouillon local reste. Si un envoi est en cours, il est
  /// arrêté avant son commit. Hors ligne, la suppression du brouillon serveur
  /// est gardée dans la file. Faux si le moment était déjà publié (il l'est
  /// alors pour de bon).
  Future<bool> garderEnBrouillon(String brouillonId) async {
    final enCours = _actifs[brouillonId];
    if (enCours != null) {
      _annulations.add(brouillonId);
      try {
        await enCours;
      } catch (_) {}
    }
    try {
      if (!await _defaire(brouillonId)) {
        await _terminer(brouillonId);
        return false;
      }
      await _file.retirer(brouillonId);
    } catch (_) {
      final marque = await _file.modifier(
        brouillonId,
        (e) => e.copieAvec(etat: EtatEnvoi.aAbandonner),
      );
      if (marque == null) {
        await _file.ecrire(
          EnvoiPublication(
            brouillonId: brouillonId,
            auteurId: _depot.monId,
            etat: EtatEnvoi.aAbandonner,
            creeLe: _maintenant(),
          ),
        );
      }
    }
    return true;
  }

  /// À l'ouverture de l'app ([auLancement]) et à sa reprise : rattrape les
  /// publications laissées en route (voir la description de la classe).
  /// Sans effet hors session ; deux appels simultanés ne font qu'un
  /// traitement. Une erreur réseau laisse la file intacte : on retentera.
  Future<List<ResultatReprise>> reprendre({bool auLancement = false}) async {
    final enCours = _reprise;
    if (enCours != null) {
      if (!auLancement) return enCours;
      // Au lancement, le traitement complet (y compris les envois
      // interrompus) passe après celui qui tourne.
      await enCours;
    }
    if (!_depot.connecte) return const [];
    final reprise = _reprendre(auLancement);
    _reprise = reprise;
    try {
      return await reprise;
    } finally {
      if (identical(_reprise, reprise)) _reprise = null;
    }
  }

  Future<List<ResultatReprise>> _reprendre(bool auLancement) async {
    final moi = _depot.monId;
    final tout = await _file.lister();
    final resultats = <ResultatReprise>[];
    for (final envoi in tout) {
      if (envoi.auteurId != moi) continue;
      try {
        final issue = await _verrouiller(
          envoi.brouillonId,
          () => _reconcilier(envoi, auLancement),
        );
        if (issue != null) {
          resultats.add(ResultatReprise(envoi.brouillonId, issue));
        }
      } catch (_) {
        // Réseau ou disque : la ligne reste, la prochaine reprise réessaie.
      }
    }
    try {
      await _nettoyerOrphelines({
        for (final e in tout) e.brouillonId,
        ..._actifs.keys,
      });
    } catch (_) {}
    if (resultats.isNotEmpty) {
      aMontrer.value = [...aMontrer.value, ...resultats];
    }
    return resultats;
  }

  Future<IssueReprise?> _reconcilier(
    EnvoiPublication envoi,
    bool auLancement,
  ) async {
    switch (envoi.etat) {
      case EtatEnvoi.aAbandonner:
        if (await _defaire(envoi.brouillonId)) {
          await _file.retirer(envoi.brouillonId);
          return null;
        }
        await _terminer(envoi.brouillonId);
        return IssueReprise.publiee;
      case EtatEnvoi.enAttente:
        return _relancer(envoi);
      case EtatEnvoi.enCours || EtatEnvoi.echec:
        // Dans l'app ouverte, c'est la cloche qui s'en occupe ; après une
        // fermeture, l'envoi est resté en plan.
        return auLancement ? _apresInterruption(envoi) : null;
    }
  }

  Future<IssueReprise?> _relancer(EnvoiPublication envoi) async {
    final id = envoi.brouillonId;
    final statut = await _depot.statutDe(id);
    if (statut == statutPublie) {
      await _terminer(id);
      return IssueReprise.publiee;
    }
    if (statut == null && envoi.commitLance) {
      // Publié, puis supprimé par son auteur : rien à renvoyer.
      await _terminer(id);
      return null;
    }
    final resultat = await _tenter(id, auPremierPlan: false);
    switch (resultat.statut) {
      case StatutEnvoi.publie:
        return IssueReprise.publiee;
      case StatutEnvoi.introuvable || StatutEnvoi.incomplet:
        // Rien à envoyer : on ne garde ni la ligne ni ce que le serveur a.
        if (await _defaire(id)) {
          await _file.retirer(id);
          return null;
        }
        await _terminer(id);
        return IssueReprise.publiee;
      case StatutEnvoi.echec || StatutEnvoi.dejaEnCours || StatutEnvoi.annule:
        return null;
    }
  }

  Future<IssueReprise?> _apresInterruption(EnvoiPublication envoi) async {
    final id = envoi.brouillonId;
    final statut = await _depot.statutDe(id);
    if (statut == statutPublie) {
      await _terminer(id);
      return IssueReprise.publiee;
    }
    if (envoi.etat == EtatEnvoi.enCours && envoi.commitLance) {
      // L'ordre de publier est parti : on le mène à terme, une seule fois.
      if (statut == null) {
        await _terminer(id);
        return null;
      }
      try {
        await _service.valider(id);
      } on MomentIntrouvable {
        await _terminer(id);
        return null;
      }
      await _terminer(id);
      return IssueReprise.publiee;
    }
    // Avant le commit, ou après un échec que l'auteur a déjà vu : rien ne
    // doit partir. Le brouillon local est gardé.
    if (!await _defaire(id)) {
      await _terminer(id);
      return IssueReprise.publiee;
    }
    await _file.retirer(id);
    return envoi.etat == EtatEnvoi.enCours ? IssueReprise.interrompue : null;
  }

  Future<void> _nettoyerOrphelines(Set<String> reclames) async {
    final maintenant = _maintenant();
    for (final ligne in await _depot.brouillonsDuServeur()) {
      if (reclames.contains(ligne.id)) continue;
      if (maintenant.difference(ligne.creeLe) < delaiOrphelineServeur) continue;
      try {
        await _service.abandonner(ligne.id);
      } on MomentDejaPublie {
        // Publié entre-temps : rien à nettoyer.
      } catch (_) {
        // La prochaine reprise réessaie.
      }
    }
  }

  /// Un essai de publication. [auPremierPlan] : la cloche l'attend, un échec
  /// laisse la main à l'auteur ; sinon la publication reste en attente.
  Future<ResultatEnvoi> _tenter(
    String id, {
    required bool auPremierPlan,
    void Function(int envoyees, int total)? surProgression,
  }) async {
    final brouillon = await _brouillons.charger(id);
    if (brouillon == null) return const ResultatEnvoi(StatutEnvoi.introuvable);
    final lieu = brouillon.lieu;
    final emotion = brouillon.emotion;
    if (lieu == null || emotion == null) {
      return const ResultatEnvoi(StatutEnvoi.incomplet);
    }

    final existant = await _file.lire(id);
    final commence =
        (existant ??
                EnvoiPublication(
                  brouillonId: id,
                  auteurId: _depot.monId,
                  etat: EtatEnvoi.enAttente,
                  creeLe: _maintenant(),
                ))
            .copieAvec(
              etat: auPremierPlan ? EtatEnvoi.enCours : EtatEnvoi.enAttente,
              // Un nouvel essai repart de zéro côté serveur : l'ancien commit
              // n'engage plus rien.
              commitLance: false,
              tentatives: (existant?.tentatives ?? 0) + 1,
              derniereErreur: () => null,
            );
    await _file.ecrire(commence);

    MomentPrepare prepare;
    try {
      final demande = DemandePublication(
        id: id,
        lieu: lieu,
        photos: [
          for (final p in brouillon.photos)
            await _brouillons.fichierPhoto(id, p.id).readAsBytes(),
        ],
        emotion: emotion,
        priseLe: brouillon.priseLe,
        legende: brouillon.legende,
        etoiles: brouillon.etoiles,
        amisTaguesIds: brouillon.avecQuiIds,
        audience: brouillon.audience,
      );
      prepare = await _service.preparer(
        demande,
        surProgression: surProgression,
      );
      if (!prepare.dejaPublie) {
        if (_annulations.contains(id)) {
          return const ResultatEnvoi(StatutEnvoi.annule);
        }
        await _file.modifier(id, (e) => e.copieAvec(commitLance: true));
        await _service.valider(id);
      }
    } catch (e) {
      await _file.modifier(
        id,
        (e0) => e0.copieAvec(
          etat: auPremierPlan ? EtatEnvoi.echec : EtatEnvoi.enAttente,
          derniereErreur: () => '$e',
        ),
      );
      return ResultatEnvoi(StatutEnvoi.echec, erreur: e);
    }

    try {
      await _terminer(id);
    } catch (_) {
      // Déjà publié : si le ménage local échoue, la ligne de la file reste et
      // la prochaine reprise le constate.
    }
    return ResultatEnvoi(
      StatutEnvoi.publie,
      tablesEnEchec: prepare.tablesEnEchec,
      dejaPublie: prepare.dejaPublie,
    );
  }

  /// Le moment est publié, ou n'a plus lieu d'être : le brouillon local et
  /// la file l'oublient.
  Future<void> _terminer(String id) async {
    await _brouillons.supprimerBrouillon(id);
    await _file.retirer(id);
  }

  /// Supprime du serveur ce qui a été envoyé. Faux si le moment est déjà
  /// publié.
  Future<bool> _defaire(String id) async {
    try {
      await _service.abandonner(id);
      return true;
    } on MomentDejaPublie {
      return false;
    }
  }

  /// Exécute [action] si rien d'autre ne traite déjà cette publication ;
  /// `null` sinon.
  Future<T?> _verrouiller<T>(String id, Future<T> Function() action) async {
    if (_actifs.containsKey(id)) return null;
    final execution = action();
    _actifs[id] = execution;
    try {
      return await execution;
    } finally {
      _actifs.remove(id);
      _annulations.remove(id);
    }
  }
}
