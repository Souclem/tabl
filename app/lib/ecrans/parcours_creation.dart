import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';

import 'ecran_camera.dart';
import 'ecran_finalisation.dart';
import 'feuille_photos_moment.dart';

/// Le parcours de création d'un moment : la caméra, la finalisation, puis la
/// cloche (ouverte par la finalisation). Chaque étape remplace la précédente
/// dans la pile : la caméra ne reste pas ouverte sous la finalisation, et
/// « Reprendre des photos » ramène à la caméra.
///
/// [ouvrir] rend le [ResultatCloche] quand la cloche s'est refermée, ou
/// `null` si l'on est sorti avant (caméra fermée, « Plus tard ») : le moment
/// est alors gardé sur le téléphone.
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
    parcours._ouvrirCamera(remplace: false);
    return parcours._fin.future;
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

  void _ouvrirCamera({required bool remplace}) {
    _aller<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => EcranCamera(
          camera: camera,
          brouillons: _brouillons,
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
          ouvrirPhotos: (contexte) => _choisirPhotos(contexte, brouillon),
        ),
      ),
      remplace: true,
      apres: _terminer,
    );
  }

  /// « Photos du moment » ; « Reprendre des photos » rouvre la caméra à la
  /// place de la finalisation.
  Future<void> _choisirPhotos(
    BuildContext contexte,
    Brouillon brouillon,
  ) async {
    final actuel = await _brouillons.charger(brouillon.id) ?? brouillon;
    if (!contexte.mounted) return;
    final reprendre = await ouvrirFeuillePhotos(
      contexte,
      brouillons: _brouillons,
      brouillon: actuel,
      peutReprendre: true,
    );
    if (reprendre && contexte.mounted) _ouvrirCamera(remplace: true);
  }
}
