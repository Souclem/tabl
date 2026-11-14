import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_camera.dart';
import 'ecran_finalisation.dart';
import 'feuille_brouillons.dart';

/// Le parcours de création d'un moment : la caméra, la finalisation, puis la
/// cloche (ouverte par la finalisation). Chaque étape remplace la précédente
/// dans la pile : la caméra ne reste pas ouverte sous la finalisation, et
/// « Reprendre des photos » ramène à la caméra, sur le même brouillon.
///
/// Sans brouillon en cours, « + » ouvre directement la caméra. Sinon, il
/// propose d'abord « Brouillons » : en reprendre un (la caméra s'ouvre
/// avec ses photos) ou, en dernier, « Nouveau moment » — au plus
/// [nombreMaxBrouillons] brouillons.
///
/// [ouvrir] rend le [ResultatCloche] quand la cloche s'est refermée, ou
/// `null` si l'on est sorti avant (liste fermée, caméra fermée, « Plus
/// tard ») : le moment est alors gardé sur le téléphone.
class ParcoursCreation {
  ParcoursCreation._({
    required this.navigateur,
    required this.souvenirService,
    required this.abonnementService,
    required this.camera,
    required this.envois,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.maintenant,
  });

  final NavigatorState navigateur;
  final SouvenirService souvenirService;
  final AbonnementService abonnementService;
  final CameraService camera;
  final EnvoiPublications envois;
  final TableService? tableService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;
  final DateTime Function()? maintenant;

  BrouillonsLocaux get _brouillons => envois.brouillons;

  final _fin = Completer<ResultatCloche?>();

  /// L'écran du parcours actuellement en haut de la pile : quand un écran
  /// en remplace un autre, la fermeture de l'ancien ne termine pas le
  /// parcours.
  Route<Object?>? _courante;

  static Future<ResultatCloche?> ouvrir(
    BuildContext context, {
    required SouvenirService souvenirService,
    required AbonnementService abonnementService,
    required CameraService camera,
    required EnvoiPublications envois,
    TableService? tableService,
    RechercheLieuService? rechercheLieuService,
    PositionService? positionService,
    DateTime Function()? maintenant,
  }) {
    final parcours = ParcoursCreation._(
      navigateur: Navigator.of(context),
      souvenirService: souvenirService,
      abonnementService: abonnementService,
      camera: camera,
      envois: envois,
      tableService: tableService,
      rechercheLieuService: rechercheLieuService,
      positionService: positionService,
      maintenant: maintenant,
    );
    unawaited(parcours._commencer(context));
    return parcours._fin.future;
  }

  /// La liste des brouillons s'il y en a, puis la caméra.
  Future<void> _commencer(BuildContext context) async {
    // La file d'envoi illisible : aucun brouillon n'est tenu pour « en
    // attente », ils comptent tous dans la limite.
    var enAttente = <String>{};
    try {
      enAttente = {
        for (final e in await envois.enAttenteDEnvoi()) e.brouillonId,
      };
    } catch (e) {
      debugPrint('ParcoursCreation: file d\'envoi : $e');
    }
    List<Brouillon> aReprendre;
    try {
      aReprendre = brouillonsAReprendre(
        await _brouillons.lister(),
        enAttente: enAttente,
      );
      final enTrop = brouillonsEnTrop(aReprendre);
      for (final b in enTrop) {
        await _brouillons.supprimerBrouillon(b.id);
      }
      if (enTrop.isNotEmpty) {
        aReprendre = aReprendre.sublist(0, nombreMaxBrouillons);
      }
    } catch (e) {
      // Sans savoir combien il y a de brouillons, pas de nouveau moment :
      // ce serait peut-être le quatrième.
      debugPrint('ParcoursCreation: brouillons : $e');
      if (context.mounted) afficherMessage(context, messageErreurGenerique);
      _terminer(null);
      return;
    }
    if (!context.mounted) {
      _terminer(null);
      return;
    }
    if (aReprendre.isEmpty) {
      _ouvrirCamera(remplace: false);
      return;
    }
    final choix = await ouvrirFeuilleBrouillons(
      context,
      brouillons: _brouillons,
      aReprendre: aReprendre,
      maintenant: maintenant,
    );
    if (choix == null || !context.mounted) {
      _terminer(null);
      return;
    }
    _ouvrirCamera(remplace: false, brouillon: choix.brouillon);
  }

  void _aller<T extends Object?>(
    Route<T> route, {
    required bool remplace,
    required void Function(T? valeur) apres,
  }) {
    _courante = route;
    final futur = remplace
        ? navigateur.pushReplacement<T, Object?>(route)
        : navigateur.push<T>(route);
    futur.then((valeur) {
      if (identical(_courante, route)) apres(valeur);
    });
  }

  void _terminer(ResultatCloche? resultat) {
    if (!_fin.isCompleted) _fin.complete(resultat);
  }

  /// [brouillon] : celui que les photos rejoignent ; `null`, un nouveau
  /// moment.
  void _ouvrirCamera({required bool remplace, Brouillon? brouillon}) {
    _aller<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EcranCamera(
          camera: camera,
          brouillons: _brouillons,
          brouillon: brouillon,
          positionService: positionService,
          maintenant: maintenant,
          surContinuer: _ouvrirFinalisation,
        ),
      ),
      remplace: remplace,
      apres: (_) => _terminer(null),
    );
  }

  void _ouvrirFinalisation(Brouillon brouillon) {
    _aller<ResultatCloche>(
      MaterialPageRoute<ResultatCloche>(
        builder: (_) => EcranFinalisation(
          souvenirService: souvenirService,
          abonnementService: abonnementService,
          brouillons: _brouillons,
          brouillon: brouillon,
          envois: envois,
          tableService: tableService,
          rechercheLieuService: rechercheLieuService,
          positionService: positionService,
          maintenant: maintenant ?? DateTime.now,
          reprendrePhotos: () => _reprendrePhotos(brouillon),
        ),
      ),
      remplace: true,
      apres: _terminer,
    );
  }

  /// Le bouton appareil photo de la finalisation : la caméra revient à sa
  /// place, sur le brouillon tel que la finalisation l'a laissé.
  Future<void> _reprendrePhotos(Brouillon brouillon) async {
    final aJour = await _brouillons.charger(brouillon.id) ?? brouillon;
    _ouvrirCamera(remplace: true, brouillon: aJour);
  }
}
