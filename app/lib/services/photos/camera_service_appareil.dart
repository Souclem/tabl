import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'camera.dart';

/// La caméra arrière du téléphone, via le paquet `camera`. Sans micro
/// (`enableAudio: false`) : l'app ne filme pas et ne demande pas le micro.
class CameraServiceAppareil extends CameraDeBase {
  CameraController? _controleur;

  @override
  Future<EtatCamera> ouvrirMateriel(ModeFlash flash) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return EtatCamera.indisponible;
      final choisie = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controleur = CameraController(
        choisie,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      _controleur = controleur;
      await controleur.initialize();
      await _flashSansEchec(controleur, flash);
      return EtatCamera.prete;
    } on CameraException catch (e) {
      await fermerMateriel();
      return _refus.contains(e.code)
          ? EtatCamera.refusee
          : EtatCamera.indisponible;
    }
  }

  @override
  Future<void> fermerMateriel() async {
    final controleur = _controleur;
    _controleur = null;
    await controleur?.dispose();
  }

  @override
  Future<void> appliquerFlash(ModeFlash mode) async {
    final controleur = _controleur;
    if (controleur != null) await _flashSansEchec(controleur, mode);
  }

  @override
  Future<PhotoPrise?> declencherMateriel() async {
    final controleur = _controleur;
    if (controleur == null ||
        !controleur.value.isInitialized ||
        controleur.value.isTakingPicture) {
      return null;
    }
    final fichier = await controleur.takePicture();
    return (octets: await fichier.readAsBytes(), priseLe: DateTime.now());
  }

  @override
  Widget apercu() {
    final controleur = _controleur;
    if (etat.value != EtatCamera.prete ||
        controleur == null ||
        !controleur.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controleur);
  }

  // Une caméra sans flash (ou un flash indisponible) ne doit pas
  // empêcher de prendre la photo.
  Future<void> _flashSansEchec(CameraController c, ModeFlash mode) async {
    try {
      await c.setFlashMode(switch (mode) {
        ModeFlash.auto => FlashMode.auto,
        ModeFlash.active => FlashMode.always,
        ModeFlash.desactive => FlashMode.off,
      });
    } on CameraException {
      // Pas de flash sur cette caméra.
    }
  }

  static const _refus = {
    'CameraAccessDenied',
    'CameraAccessDeniedWithoutPrompt',
    'CameraAccessRestricted',
  };
}
