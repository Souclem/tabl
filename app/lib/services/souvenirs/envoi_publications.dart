import 'dart:async';

import 'package:flutter/foundation.dart';

import 'brouillon_local.dart';
import 'brouillons_a_reprendre.dart';
import 'file_envoi.dart';
import 'metadonnees_photo.dart';
import 'publication_en_deux_temps.dart';
import 'publication_service.dart';
import 'rappels_brouillons.dart';

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

/// Où en est réellement une publication, relue au retour de l'app au premier
/// plan (voir [EnvoiPublications.etatReel]).
enum EtatReel {
  /// Le moment est publié sur le serveur.
  publie,

  /// Un envoi tourne encore dans l'app.
  enCours,

  /// L'envoi a échoué ; la file attend le choix de l'auteur.
  echec,

  /// Plus aucun envoi ne tourne alors que rien n'est publié : l'envoi a été
  /// coupé (l'OS a suspendu l'app). Le brouillon est intact.
  coupe,

  /// Le brouillon n'existe plus et le serveur n'a rien publié.
  introuvable,
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
    this._rappels,
  }) : _service = service ?? PublicationEnDeuxTemps(_depot),
       _maintenant = maintenant ?? DateTime.now;

  /// Ouvre les brouillons du téléphone et leur file d'envoi.
  static Future<EnvoiPublications> ouvrir(
    DepotPublication depot, {
    RappelsSysteme? rappels,
  }) async {
    final brouillons = await BrouillonsLocaux.ouvrir();
    return EnvoiPublications(
      depot,
      brouillons,
      FileEnvoi(brouillons.racine),
      rappels: rappels,
    );
  }

  final DepotPublication _depot;
  final BrouillonsLocaux _brouillons;
  final FileEnvoi _file;
  final PublicationService _service;
  final DateTime Function() _maintenant;
  final RappelsSysteme? _rappels;

  /// Les ordres de rappels partent dans l'ordre où ils sont donnés : un
  /// retour au premier plan qui suit de près un départ les retire bien.
  Future<void> _ordresRappels = Future.value();

  Future<void> _rappeler(Future<void> Function(RappelsSysteme r) ordre) {
    final rappels = _rappels;
    if (rappels == null) return Future.value();
    return _ordresRappels = _ordresRappels.then((_) async {
      try {
        await ordre(rappels);
      } catch (e) {
        debugPrint('EnvoiPublications: rappels : $e');
      }
    });
  }

  /// L'app passe en arrière-plan : chaque brouillon à reprendre (pas ceux
  /// que la file envoie ou va envoyer) programme ses rappels encore à
  /// venir, 2 h et 5 h après sa dernière modification.
  Future<void> programmerRappels() => _rappeler((rappels) async {
    final confies = {
      for (final e in await _file.lister())
        if (e.etat != EtatEnvoi.aAbandonner) e.brouillonId,
      ..._actifs.keys,
    };
    final aReprendre = brouillonsAReprendre(
      await _brouillons.lister(),
      enAttente: confies,
    );
    await rappels.remplacer(
      rappelsBrouillons(aReprendre, maintenant: _maintenant()),
    );
  });

  /// L'app est au premier plan : aucun rappel ne sonne pendant qu'on s'en
  /// sert.
  Future<void> retirerRappels() =>
      _rappeler((rappels) => rappels.remplacer(const []));

  /// Les brouillons du téléphone, ceux que cette file publie : l'écran qui
  /// les modifie doit partager cette instance, pour que leurs écritures
  /// passent dans le même ordre.
  BrouillonsLocaux get brouillons => _brouillons;

  /// Les publications en cours de traitement dans cette session de l'app.
  final _actifs = <String, Future<Object?>>{};
  final _annulations = <String>{};

  /// L'essai de la cloche qui a la main sur chaque publication : un essai
  /// détaché ([detacher]) perd son jeton et s'arrête avant son commit.
  final _jetons = <String, Completer<void>>{};
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
    unawaited(_rappeler((rappels) => rappels.annuler(brouillonId)));
    final resultat = await _verrouiller(brouillonId, () {
      final jeton = _jetons[brouillonId] = Completer<void>();
      return _tenter(
        brouillonId,
        auPremierPlan: true,
        surProgression: surProgression,
        abandonne: () => !identical(_jetons[brouillonId], jeton),
      );
    });
    return resultat ?? const ResultatEnvoi(StatutEnvoi.dejaEnCours);
  }

  /// L'envoi de la cloche est suspendu sans erreur (voir `SuiviPublication`) :
  /// on le lâche, pour que « Garder en brouillon » et « Réessayer » ne
  /// l'attendent pas. Il s'arrête avant son commit s'il n'y est pas encore ;
  /// la file passe en échec, le brouillon est intact.
  Future<void> detacher(String brouillonId) async {
    final etait = _actifs.remove(brouillonId);
    _jetons.remove(brouillonId)?.complete();
    _annulations.remove(brouillonId);
    if (etait == null) return;
    await _file.modifier(
      brouillonId,
      (e) => e.copieAvec(
        etat: EtatEnvoi.echec,
        derniereErreur: () => 'envoi suspendu',
      ),
    );
  }

  /// Relit l'état réel de la publication, au retour de l'app au premier
  /// plan : l'OS a pu suspendre l'envoi pendant l'absence. Lève si le serveur
  /// est injoignable (l'état n'est alors pas connu).
  Future<EtatReel> etatReel(String brouillonId) async {
    if (_actifs.containsKey(brouillonId)) return EtatReel.enCours;
    final statut = await _depot.statutDe(brouillonId);
    if (statut == statutPublie) {
      try {
        await _terminer(brouillonId);
      } catch (_) {
        // La prochaine reprise le constate.
      }
      return EtatReel.publie;
    }
    if (await _brouillons.charger(brouillonId) == null) {
      return EtatReel.introuvable;
    }
    final envoi = await _file.lire(brouillonId);
    return envoi?.etat == EtatEnvoi.echec ? EtatReel.echec : EtatReel.coupe;
  }

  /// « Envoyer dès que possible » : la publication est gardée dans la file
  /// et repart à la prochaine ouverture ou reprise de l'app. Faux si le
  /// brouillon n'existe plus.
  Future<bool> mettreEnAttente(String brouillonId) async {
    if (await _brouillons.charger(brouillonId) == null) return false;
    unawaited(_rappeler((rappels) => rappels.annuler(brouillonId)));
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
        await Future.any([enCours, ?_jetons[brouillonId]?.future]);
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
      // Ambigu : orpheline nettoyée par un autre téléphone, ou moment publié
      // puis supprimé ailleurs. Dans les deux cas on garde le brouillon local
      // (mieux vaut un brouillon de trop qu'un souvenir perdu) et on retire
      // seulement la ligne de la file.
      await _file.retirer(id);
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
        // Ambigu : orpheline nettoyée par un autre téléphone, ou moment publié
        // puis supprimé ailleurs. Dans les deux cas on garde le brouillon local
        // (mieux vaut un brouillon de trop qu'un souvenir perdu) et on retire
        // seulement la ligne de la file.
        await _file.retirer(id);
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
    bool Function()? abandonne,
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
      final octets = [
        for (final p in brouillon.photos)
          await _brouillons.fichierPhoto(id, p.id).readAsBytes(),
      ];
      final demande = DemandePublication(
        id: id,
        lieu: lieu,
        photos: octets,
        empreintes: [
          for (final p in await lirePhotos(octets)) ?p.metadonnees.empreinte,
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
        if (_annulations.contains(id) || (abandonne?.call() ?? false)) {
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
    unawaited(_rappeler((rappels) => rappels.annuler(id)));
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
      // Un essai détaché qui se termine tard ne doit pas défaire le suivant.
      if (identical(_actifs[id], execution)) {
        _actifs.remove(id);
        _annulations.remove(id);
        _jetons.remove(id);
      }
    }
  }
}
