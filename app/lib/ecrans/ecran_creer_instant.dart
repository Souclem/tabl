import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Créer un Instant (megaprompt Bloc 2, règle 20-25) : caméra
/// immédiatement, pas de formulaire, pas de restaurant/émotion à
/// rechoisir — tout existe déjà sur l'expérience parente. Tap → photo,
/// appui long → courte vidéo. Pas de galerie en V1.
class EcranCreerInstant extends StatefulWidget {
  const EcranCreerInstant({
    super.key,
    required this.instantService,
    required this.experienceId,
  });

  final InstantService instantService;
  final String experienceId;

  @override
  State<EcranCreerInstant> createState() => _EcranCreerInstantState();
}

enum _Etape { camera, previsualisation }

class _EcranCreerInstantState extends State<EcranCreerInstant> {
  _Etape _etape = _Etape.camera;
  Uint8List? _media;
  TypeMediaInstant? _type;
  VideoPlayerController? _controleurVideo;
  bool _enCours = false;

  @override
  void dispose() {
    _controleurVideo?.dispose();
    super.dispose();
  }

  Future<void> _capturerPhoto() async {
    final fichier = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (fichier == null || !mounted) return;
    final octets = await fichier.readAsBytes();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() {
      _media = octets;
      _type = TypeMediaInstant.photo;
      _etape = _Etape.previsualisation;
    });
  }

  Future<void> _capturerVideo() async {
    final fichier = await ImagePicker().pickVideo(
      source: ImageSource.camera,
      maxDuration: InstantsConfig.dureeMaxVideo,
    );
    if (fichier == null || !mounted) return;
    final octets = await fichier.readAsBytes();
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final controleur = VideoPlayerController.file(File(fichier.path));
    controleur.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      controleur.setLooping(true);
      controleur.play();
    });
    setState(() {
      _media = octets;
      _type = TypeMediaInstant.video;
      _controleurVideo = controleur;
      _etape = _Etape.previsualisation;
    });
  }

  void _reprendre() {
    _controleurVideo?.dispose();
    setState(() {
      _controleurVideo = null;
      _media = null;
      _type = null;
      _etape = _Etape.camera;
    });
  }

  Future<void> _ajouter() async {
    final media = _media;
    final type = _type;
    if (media == null || type == null) return;

    setState(() => _enCours = true);
    try {
      await widget.instantService.creer(
        experienceId: widget.experienceId,
        type: type,
        media: media,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on LimiteInstantsAtteinteException {
      if (!mounted) return;
      afficherMessage(
        context,
        "Vous avez atteint le maximum d'Instants pour cette expérience.",
      );
      setState(() => _enCours = false);
    } on FenetreInstantFermeeException {
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _etape == _Etape.camera
            ? _VueCamera(
                onTapPhoto: _capturerPhoto,
                onLongPressVideo: _capturerVideo,
                onFermer: () => Navigator.of(context).pop(false),
              )
            : _VuePrevisualisation(
                media: _media!,
                type: _type!,
                controleurVideo: _controleurVideo,
                enCours: _enCours,
                onReprendre: _reprendre,
                onAjouter: _ajouter,
              ),
      ),
    );
  }
}

class _VueCamera extends StatelessWidget {
  const _VueCamera({
    required this.onTapPhoto,
    required this.onLongPressVideo,
    required this.onFermer,
  });

  final VoidCallback onTapPhoto;
  final VoidCallback onLongPressVideo;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Stack(
      children: [
        const Center(
          child: Padding(
            padding: EdgeInsets.all(TablTokens.espaceXl),
            child: Text(
              'Un instant de votre expérience — quelques secondes, puis '
              "c'est gardé.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ),
        ),
        Positioned(
          top: TablTokens.espaceS,
          left: TablTokens.espaceS,
          child: Semantics(
            label: 'Fermer',
            child: IconButton(
              onPressed: onFermer,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: TablTokens.espaceXxl,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Semantics(
                label: 'Prendre une photo',
                hint: 'Maintenir pour enregistrer une vidéo',
                child: GestureDetector(
                  key: const Key('tabl_declencheur_instant'),
                  onTap: onTapPhoto,
                  onLongPress: onLongPressVideo,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: c.primaire, width: 4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TablTokens.espaceS),
              const Text(
                'Maintenir pour une vidéo',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VuePrevisualisation extends StatelessWidget {
  const _VuePrevisualisation({
    required this.media,
    required this.type,
    required this.controleurVideo,
    required this.enCours,
    required this.onReprendre,
    required this.onAjouter,
  });

  final Uint8List media;
  final TypeMediaInstant type;
  final VideoPlayerController? controleurVideo;
  final bool enCours;
  final VoidCallback onReprendre;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    final controleur = controleurVideo;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (type == TypeMediaInstant.photo)
          Image.memory(media, fit: BoxFit.cover)
        else if (controleur != null && controleur.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: controleur.value.size.width,
              height: controleur.value.size.height,
              child: VideoPlayer(controleur),
            ),
          )
        else
          const ColoredBox(color: Colors.black),
        Positioned(
          bottom: TablTokens.espaceXl,
          left: TablTokens.espaceL,
          right: TablTokens.espaceL,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: enCours ? null : onReprendre,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Reprendre'),
                ),
              ),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: TablBouton(
                  libelle: 'Ajouter',
                  enCours: enCours,
                  onPresse: onAjouter,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
