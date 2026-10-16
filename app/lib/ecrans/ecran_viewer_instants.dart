import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Une expérience à afficher dans le viewer — métadonnées déjà connues
/// (issues du Feed ou de la sheet "À table maintenant"), les Instants
/// eux-mêmes sont chargés à la demande (règle 40 : pas tout précharger
/// d'un coup).
class ContexteInstant {
  const ContexteInstant({
    required this.experienceId,
    required this.auteurPseudo,
    required this.restaurantNom,
    required this.ville,
  });

  final String experienceId;
  final String auteurPseudo;
  final String restaurantNom;
  final String ville;
}

/// Viewer plein écran des Instants (megaprompt Bloc 2, règle 15-19,
/// 61-64) : propriétaire Tabl., une seule instance active, jamais de
/// chaîne infinie automatique — après la dernière expérience de
/// [contextes], on ferme ou on propose "Ensuite" volontairement.
class EcranViewerInstants extends StatefulWidget {
  const EcranViewerInstants({
    super.key,
    required this.instantService,
    required this.contextes,
    required this.indexInitial,
    required this.onVoirExperience,
  });

  final InstantService instantService;
  final List<ContexteInstant> contextes;
  final int indexInitial;
  final ValueChanged<String> onVoirExperience;

  @override
  State<EcranViewerInstants> createState() => _EcranViewerInstantsState();
}

enum _Mode { chargement, media, ensuite, indisponible }

class _EcranViewerInstantsState extends State<EcranViewerInstants> {
  late int _indexContexte = widget.indexInitial;
  int _indexMedia = 0;
  _Mode _mode = _Mode.chargement;

  final Map<int, List<InstantAffichable>> _cache = {};
  VideoPlayerController? _controleurVideo;
  Timer? _minuteurVu;

  ContexteInstant get _contexte => widget.contextes[_indexContexte];
  List<InstantAffichable>? get _instants => _cache[_indexContexte];

  @override
  void initState() {
    super.initState();
    _chargerContexte();
  }

  @override
  void dispose() {
    _minuteurVu?.cancel();
    _controleurVideo?.dispose();
    super.dispose();
  }

  Future<void> _chargerContexte() async {
    setState(() => _mode = _Mode.chargement);
    try {
      final instants = await widget.instantService.instantsDe(
        _contexte.experienceId,
      );
      if (!mounted) return;
      if (instants.isEmpty) {
        setState(() => _mode = _Mode.indisponible);
        return;
      }
      setState(() {
        _cache[_indexContexte] = instants;
        _indexMedia = 0;
        _mode = _Mode.media;
      });
      _apresChangementMedia();
    } catch (_) {
      if (!mounted) return;
      setState(() => _mode = _Mode.indisponible);
    }
  }

  /// Règle 9 : marquer vu seulement quand le média a réellement été
  /// présenté un temps suffisant — jamais au simple affichage.
  void _apresChangementMedia() {
    _minuteurVu?.cancel();
    _controleurVideo?.dispose();
    _controleurVideo = null;

    final instant = _instants?[_indexMedia];
    if (instant == null) return;

    if (instant.type == TypeMediaInstant.video) {
      final controleur = VideoPlayerController.networkUrl(
        Uri.parse(instant.mediaUrl),
      )..initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controleurVideo?.setLooping(true);
        _controleurVideo?.play();
      });
      _controleurVideo = controleur;
    }

    _minuteurVu = Timer(const Duration(milliseconds: 1200), () {
      widget.instantService.marquerVu(instant.id);
    });
  }

  void _media(int delta) {
    final instants = _instants;
    if (instants == null) return;
    final nouvel = _indexMedia + delta;
    if (nouvel < 0) return;
    if (nouvel >= instants.length) {
      _passerAEnsuite();
      return;
    }
    setState(() => _indexMedia = nouvel);
    _apresChangementMedia();
  }

  void _passerAEnsuite() {
    _minuteurVu?.cancel();
    if (_indexContexte + 1 < widget.contextes.length) {
      setState(() => _mode = _Mode.ensuite);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _continuerEnsuite() {
    setState(() => _indexContexte += 1);
    _chargerContexte();
  }

  Future<void> _supprimer(String instantId) async {
    final confirme = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: TablTokens.erreur),
              title: const Text(
                'Supprimer cet Instant',
                style: TextStyle(color: TablTokens.erreur),
              ),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              title: const Text('Annuler', style: TablTokens.corps),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (confirme != true) return;

    await widget.instantService.supprimer(instantId);
    HapticFeedback.lightImpact();
    if (!mounted) return;

    final restants = [..._instants!]..removeWhere((i) => i.id == instantId);
    if (restants.isEmpty) {
      _passerAEnsuite();
      return;
    }
    setState(() {
      _cache[_indexContexte] = restants;
      if (_indexMedia >= restants.length) _indexMedia = restants.length - 1;
    });
    _apresChangementMedia();
  }

  void _onPanEnd(DragEndDetails details) {
    final v = details.velocity.pixelsPerSecond;
    if (v.dy.abs() > v.dx.abs() && v.dy > 300) {
      Navigator.of(context).pop();
      return;
    }
    if (v.dx < -300) _media(1);
    if (v.dx > 300) _media(-1);
  }

  void _onTapUp(TapUpDetails details, double largeur) {
    if (details.localPosition.dx < largeur / 2) {
      _media(-1);
    } else {
      _media(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: switch (_mode) {
        _Mode.chargement => const Center(
          child: CircularProgressIndicator(color: TablTokens.primaire),
        ),
        _Mode.indisponible => _Indisponible(
          onFermer: () => Navigator.of(context).pop(),
        ),
        _Mode.ensuite => TablTransitionEnsuite(
          auteurPseudo: widget.contextes[_indexContexte + 1].auteurPseudo,
          restaurantNom: widget.contextes[_indexContexte + 1].restaurantNom,
          nombreInstants: 1,
          onContinuer: _continuerEnsuite,
          onFermer: () => Navigator.of(context).pop(),
        ),
        _Mode.media => _vueMedia(),
      },
    );
  }

  Widget _vueMedia() {
    final instants = _instants!;
    final instant = instants[_indexMedia];
    return LayoutBuilder(
      builder: (context, contraintes) {
        return GestureDetector(
          onTapUp: (d) => _onTapUp(d, contraintes.maxWidth),
          onPanEnd: _onPanEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: TablTokens.surface),
              if (instant.type == TypeMediaInstant.photo)
                Image.network(instant.mediaUrl, fit: BoxFit.cover)
              else if (_controleurVideo?.value.isInitialized ?? false)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controleurVideo!.value.size.width,
                    height: _controleurVideo!.value.size.height,
                    child: VideoPlayer(_controleurVideo!),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: TablEnteteViewerInstant(
                  auteurPseudo: _contexte.auteurPseudo,
                  sousLigne: '${_contexte.restaurantNom} · maintenant',
                  position: _indexMedia + 1,
                  total: instants.length,
                  onFermer: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: TablPiedViewerInstant(
                  restaurantNom: _contexte.restaurantNom,
                  ville: _contexte.ville,
                  onVoirExperience: () =>
                      widget.onVoirExperience(_contexte.experienceId),
                ),
              ),
              if (instant.estMoi)
                Positioned(
                  top: TablTokens.espaceXl,
                  right: TablTokens.espaceS,
                  child: Semantics(
                    label: "Options de l'Instant",
                    child: IconButton(
                      onPressed: () => _supprimer(instant.id),
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Indisponible extends StatelessWidget {
  const _Indisponible({required this.onFermer});

  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Cette expérience n'est plus disponible.",
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: TablTokens.espaceM),
          TextButton(
            onPressed: onFermer,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
