import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/tokens.dart';
import 'pile_photos_camera.dart';
import 'verre_camera.dart';

/// Combien de photos l'éventail déploie au plus (les plus récentes).
const nombreMaxEventail = 6;

/// Appui long avant qu'une photo ne se soulève pour être glissée.
const delaiSaisieEventail = Duration(milliseconds: 280);

/// Une photo de l'éventail ou de la visionneuse : son identifiant (rendu aux
/// callbacks), son image, et ce que lisent les lecteurs d'écran.
class VignetteEventail {
  const VignetteEventail({
    required this.id,
    required this.image,
    required this.libelle,
  });

  final String id;
  final ImageProvider image;
  final String libelle;
}

const _largeurPhoto = 64.0;
const _hauteurPhoto = 84.0;
const _marge = 7.0;
const _rayon = 190.0;
const _rayonCorbeille = 34.0;

/// L'éventail de la pile : les photos du moment se déploient en arc au-dessus
/// de la pile, suivies de « Importer ». Toucher une photo l'agrandit, le ×
/// la supprime, et un appui long (280 ms) la soulève : on la glisse alors
/// vers la corbeille qui apparaît en bas à droite.
///
/// À poser sur tout l'écran (`Positioned.fill`) : [ancre] est le centre de la
/// pile dans ce repère. Les photos sont rendues déjà choisies et ordonnées
/// (la plus récente d'abord) ; une suppression part en callback, c'est à
/// l'écran de retirer la photo de [vignettes].
class EventailPhotosCamera extends StatefulWidget {
  const EventailPhotosCamera({
    super.key,
    required this.vignettes,
    required this.ancre,
    required this.bas,
    required this.libelleImporter,
    required this.libelleSupprimer,
    required this.libelleCorbeille,
    required this.onOuvrir,
    required this.onSupprimer,
    required this.onImporter,
    required this.onFermer,
    this.indice,
  });

  final List<VignetteEventail> vignettes;

  /// Le centre de la pile, d'où l'éventail se déploie.
  final Offset ancre;

  /// La distance entre le bas de l'écran et le centre de la rangée du
  /// déclencheur : la corbeille et l'indice se posent au-dessus.
  final double bas;

  /// « Importer ».
  final String libelleImporter;

  /// Lu par les lecteurs d'écran sur le ×.
  final String libelleSupprimer;

  /// « Supprimer », sous l'icône de la corbeille.
  final String libelleCorbeille;

  /// « Touchez × ou glissez une photo vers la corbeille » : affiché un
  /// instant à l'ouverture ; `null` pour ne rien dire.
  final String? indice;

  final ValueChanged<String> onOuvrir;

  /// Rendue quand la suppression est faite : la photo reste cachée jusque-là.
  final Future<void> Function(String id) onSupprimer;
  final VoidCallback onImporter;

  /// Toucher à côté des photos.
  final VoidCallback onFermer;

  @override
  State<EventailPhotosCamera> createState() => _EventailPhotosCameraState();
}

class _EventailPhotosCameraState extends State<EventailPhotosCamera>
    with TickerProviderStateMixin {
  static const _decalage = 25; // ms entre deux photos qui s'ouvrent
  static const _dureePhoto = 320; // ms

  final _cle = GlobalKey();

  late final AnimationController _ouverture = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _dureePhoto + _decalage * 7),
  );
  late final AnimationController _sortie = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  );
  late final AnimationController _retour = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  late final AnimationController _gloutonne = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  Timer? _delaiIndice;
  var _indiceVisible = false;
  var _initialise = false;

  String? _enLevee;
  Offset _doigt = Offset.zero;
  var _survol = false;
  var _corbeilleVisible = false;

  String? _sortieId;
  var _sortieDe = Offset.zero;
  var _sortieVers = Offset.zero;
  var _sortieEchelle = 1.0;
  var _sortieAngle = 0.0;
  final _masquees = <String>{};

  String? _retourId;
  var _retourDe = Offset.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialise) return;
    _initialise = true;
    _jouerOuverture();
    if (widget.indice != null) {
      _indiceVisible = true;
      _delaiIndice = Timer(const Duration(milliseconds: 2800), () {
        if (mounted) setState(() => _indiceVisible = false);
      });
    }
  }

  @override
  void didUpdateWidget(EventailPhotosCamera ancienne) {
    super.didUpdateWidget(ancienne);
    final avant = [for (final v in ancienne.vignettes) v.id];
    final apres = [for (final v in widget.vignettes) v.id];
    if (avant.join(',') != apres.join(',')) _jouerOuverture();
  }

  @override
  void dispose() {
    _delaiIndice?.cancel();
    _ouverture.dispose();
    _sortie.dispose();
    _retour.dispose();
    _gloutonne.dispose();
    super.dispose();
  }

  void _jouerOuverture() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _ouverture.value = 1;
    } else {
      _ouverture.forward(from: 0);
    }
  }

  Offset _local(Offset global) {
    final boite = _cle.currentContext?.findRenderObject() as RenderBox?;
    return boite?.globalToLocal(global) ?? global;
  }

  Offset _centreCorbeille(Size taille) => Offset(
    taille.width - 22 - _rayonCorbeille,
    taille.height - (widget.bas + 150) - _rayonCorbeille,
  );

  Offset _centrePhoto(int rang, int total) {
    final angle =
        (-100 + (total > 1 ? rang * (60 / (total - 1)) : 0)) * math.pi / 180;
    return widget.ancre +
        Offset(math.cos(angle) * _rayon + 16, math.sin(angle) * _rayon);
  }

  bool get _occupe => _sortieId != null || _retourId != null;

  void _soulever(String id, Offset global) {
    if (_occupe) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enLevee = id;
      _doigt = _local(global);
      _corbeilleVisible = true;
      _indiceVisible = false;
      _survol = false;
    });
  }

  void _glisser(Offset global, Size taille) {
    if (_enLevee == null) return;
    final doigt = _local(global);
    final survol = (doigt - _centreCorbeille(taille)).distance < 64;
    if (survol && !_survol) HapticFeedback.selectionClick();
    setState(() {
      _doigt = doigt;
      _survol = survol;
    });
  }

  void _lacher(Size taille) {
    final id = _enLevee;
    if (id == null) return;
    if (_survol) {
      _lancerSortie(
        id,
        de: _doigt,
        vers: _centreCorbeille(taille),
        echelle: 0.12,
        angle: 18 * math.pi / 180,
        versCorbeille: true,
      );
      return;
    }
    setState(() {
      _enLevee = null;
      _survol = false;
      _corbeilleVisible = false;
      _retourId = id;
      _retourDe = _doigt;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _retourId = null);
      return;
    }
    _retour.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _retourId = null);
    });
  }

  void _supprimerAuX(String id, Offset centre) {
    if (_occupe || _enLevee != null) return;
    HapticFeedback.lightImpact();
    _lancerSortie(
      id,
      de: centre,
      vers: centre,
      echelle: 0.2,
      angle: 0,
      versCorbeille: false,
    );
  }

  void _lancerSortie(
    String id, {
    required Offset de,
    required Offset vers,
    required double echelle,
    required double angle,
    required bool versCorbeille,
  }) {
    setState(() {
      _sortieId = id;
      _sortieDe = de;
      _sortieVers = vers;
      _sortieEchelle = echelle;
      _sortieAngle = angle;
      _enLevee = null;
    });
    final fini = MediaQuery.disableAnimationsOf(context)
        ? Future<void>.value()
        : _sortie.forward(from: 0);
    fini.whenComplete(() async {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      _masquees.add(id);
      if (versCorbeille && !MediaQuery.disableAnimationsOf(context)) {
        unawaited(_gloutonne.forward(from: 0));
      }
      setState(() {
        _sortieId = null;
        _survol = false;
      });
      try {
        await widget.onSupprimer(id);
      } finally {
        if (mounted) {
          setState(() {
            _masquees.remove(id);
            _corbeilleVisible = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vignettes = [
      for (final v in widget.vignettes)
        if (!_masquees.contains(v.id)) v,
    ];
    final total = vignettes.length + 1;
    return LayoutBuilder(
      builder: (context, contrainte) {
        final taille = contrainte.biggest;
        return SizedBox.expand(
          key: _cle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onFermer,
                ),
              ),
              if (widget.indice != null)
                Positioned(
                  left: 16,
                  bottom: widget.bas + 262,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _indiceVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 300),
                      child: VerreCamera(
                        arrondi: 15,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          height: 30,
                          child: Center(
                            widthFactor: 1,
                            child: Text(
                              widget.indice!,
                              maxLines: 1,
                              style: TextStyle(
                                color: TablCouleurs.sombre.texte,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 22,
                bottom: widget.bas + 150,
                child: _Corbeille(
                  libelle: widget.libelleCorbeille,
                  visible: _corbeilleVisible,
                  survol: _survol,
                  gloutonne: _gloutonne,
                ),
              ),
              AnimatedBuilder(
                animation: Listenable.merge([_ouverture, _sortie, _retour]),
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // La plus récente (rang 0) est dessus : on peint à l'envers,
                    // la photo soulevée en dernier.
                    for (var rang = total - 1; rang >= 0; rang--)
                      if (rang < vignettes.length &&
                          vignettes[rang].id != _enLevee)
                        _photo(vignettes[rang], rang, total, taille),
                    if (_enLevee != null)
                      for (var rang = 0; rang < vignettes.length; rang++)
                        if (vignettes[rang].id == _enLevee)
                          _photo(vignettes[rang], rang, total, taille),
                    _importer(total),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Où en est l'ouverture de la photo de ce [rang], de 0 à 1.
  double _progres(int rang) {
    final ms = _ouverture.value * _ouverture.duration!.inMilliseconds;
    final t = ((ms - rang * _decalage) / _dureePhoto).clamp(0.0, 1.0);
    return const Cubic(0.2, 1.15, 0.3, 1).transform(t);
  }

  Widget _photo(VignetteEventail v, int rang, int total, Size taille) {
    final base = _centrePhoto(rang, total);
    final progres = _progres(rang);
    final angleBase = (rang - total / 2) * 3 * math.pi / 180;
    var centre = Offset.lerp(widget.ancre, base, progres)!;
    var echelle = 0.6 + 0.4 * progres;
    var angle = angleBase * progres;
    var opacite = math.min(1.0, progres * 3);
    final levee = v.id == _enLevee;
    if (levee) {
      centre = _doigt;
      echelle = 1.12;
      angle = angleBase;
      opacite = 1;
    } else if (v.id == _sortieId) {
      final t = const Cubic(0.5, 0, 0.75, 0).transform(_sortie.value);
      centre = Offset.lerp(_sortieDe, _sortieVers, t)!;
      echelle = 1.12 + (_sortieEchelle - 1.12) * t;
      angle = angleBase + (_sortieAngle - angleBase) * t;
      opacite = 1 - t;
    } else if (v.id == _retourId) {
      final t = const Cubic(0.2, 1.25, 0.3, 1).transform(_retour.value);
      centre = Offset.lerp(_retourDe, base, t)!;
      echelle = 1.12 + (1 - 1.12) * t;
      angle = angleBase;
      opacite = 1;
    } else if (_enLevee != null) {
      opacite *= 0.35;
    }
    return Positioned(
      key: ValueKey(v.id),
      left: centre.dx - (_largeurPhoto / 2 + _marge),
      top: centre.dy - (_hauteurPhoto / 2 + _marge),
      child: Opacity(
        opacity: opacite.clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(angle)
            ..scaleByDouble(echelle, echelle, 1, 1),
          child: _TuilePhoto(
            vignette: v,
            levee: levee,
            libelleSupprimer: widget.libelleSupprimer,
            onTap: () => widget.onOuvrir(v.id),
            onSupprimer: () => _supprimerAuX(v.id, centre),
            onSoulever: (global) => _soulever(v.id, global),
            onGlisser: (global) => _glisser(global, taille),
            onLacher: () => _lacher(taille),
          ),
        ),
      ),
    );
  }

  Widget _importer(int total) {
    final rang = total - 1;
    final progres = _progres(rang);
    final centre = Offset.lerp(
      widget.ancre,
      _centrePhoto(rang, total),
      progres,
    )!;
    final angle = (rang - total / 2) * 3 * math.pi / 180 * progres;
    final echelle = 0.6 + 0.4 * progres;
    return Positioned(
      left: centre.dx - (_largeurPhoto / 2 + _marge),
      top: centre.dy - (_hauteurPhoto / 2 + _marge),
      child: Opacity(
        opacity: (math.min(1.0, progres * 3) * (_enLevee != null ? 0.35 : 1))
            .clamp(0.0, 1.0),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..rotateZ(angle)
            ..scaleByDouble(echelle, echelle, 1, 1),
          child: _TuileImporter(
            libelle: widget.libelleImporter,
            onTap: _enLevee == null ? widget.onImporter : null,
          ),
        ),
      ),
    );
  }
}

/// Le cadre d'une tuile : la photo (64 × 84) au centre, et une marge de 7 px
/// pour que le × déborde du coin.
class _TuilePhoto extends StatelessWidget {
  const _TuilePhoto({
    required this.vignette,
    required this.levee,
    required this.libelleSupprimer,
    required this.onTap,
    required this.onSupprimer,
    required this.onSoulever,
    required this.onGlisser,
    required this.onLacher,
  });

  final VignetteEventail vignette;
  final bool levee;
  final String libelleSupprimer;
  final VoidCallback onTap;
  final VoidCallback onSupprimer;
  final ValueChanged<Offset> onSoulever;
  final ValueChanged<Offset> onGlisser;
  final VoidCallback onLacher;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (r) => r.onTap = onTap,
            ),
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: delaiSaisieEventail),
              (r) => r
                ..onLongPressStart = ((d) => onSoulever(d.globalPosition))
                ..onLongPressMoveUpdate = ((d) => onGlisser(d.globalPosition))
                ..onLongPressEnd = ((_) => onLacher())
                ..onLongPressCancel = onLacher,
            ),
      },
      child: Semantics(
        button: true,
        label: vignette.libelle,
        child: ExcludeSemantics(
          child: SizedBox(
            width: _largeurPhoto + 2 * _marge,
            height: _hauteurPhoto + 2 * _marge,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _marge,
                  top: _marge,
                  width: _largeurPhoto,
                  height: _hauteurPhoto,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: levee
                          ? [
                              BoxShadow(color: c.texte, spreadRadius: 1.5),
                              const BoxShadow(
                                color: Color(0x99000000),
                                blurRadius: 44,
                                offset: Offset(0, 20),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: c.texte.withValues(alpha: 0.9),
                                spreadRadius: 1,
                              ),
                              const BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                    ),
                    child: MiniaturePhotoCamera(
                      image: vignette.image,
                      arrondi: 9,
                    ),
                  ),
                ),
                if (!levee)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Semantics(
                      button: true,
                      label: libelleSupprimer,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onSupprimer,
                        child: const _CroixSupprimer(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le × d'une photo : un disque de 24 px, dans une zone tactile de 34 px.
class _CroixSupprimer extends StatelessWidget {
  const _CroixSupprimer();

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return SizedBox(
      width: 34,
      height: 34,
      child: Align(
        alignment: Alignment.topRight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.fond.withValues(alpha: 0.82),
            boxShadow: [
              BoxShadow(
                color: c.texte.withValues(alpha: 0.35),
                spreadRadius: 1,
              ),
            ],
          ),
          child: SizedBox(
            width: 24,
            height: 24,
            child: Icon(Icons.close_rounded, size: 11, color: c.texte),
          ),
        ),
      ),
    );
  }
}

class _TuileImporter extends StatelessWidget {
  const _TuileImporter({required this.libelle, required this.onTap});

  final String libelle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Semantics(
      button: true,
      label: libelle,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: _largeurPhoto + 2 * _marge,
            height: _hauteurPhoto + 2 * _marge,
            child: Padding(
              padding: const EdgeInsets.all(_marge),
              child: VerreCamera(
                arrondi: 9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.photo_library_outlined,
                      size: 18,
                      color: c.texte,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      libelle,
                      maxLines: 1,
                      style: TextStyle(
                        color: c.texte,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La corbeille qui apparaît pendant qu'on glisse une photo ; elle grossit
/// et rougit quand la photo est au-dessus.
class _Corbeille extends StatelessWidget {
  const _Corbeille({
    required this.libelle,
    required this.visible,
    required this.survol,
    required this.gloutonne,
  });

  final String libelle;
  final bool visible;
  final bool survol;
  final Animation<double> gloutonne;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: gloutonne,
          builder: (context, enfant) => Transform.scale(
            scale: 1 + 0.3 * math.sin(math.pi * gloutonne.value),
            child: enfant,
          ),
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: AnimatedScale(
              scale: !visible
                  ? 0.8
                  : survol
                  ? 1.2
                  : 1,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: ClipOval(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _rayonCorbeille * 2,
                  height: _rayonCorbeille * 2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: survol
                        ? const Color(0xE07B2F1D)
                        : c.fond.withValues(alpha: 0.6),
                    border: Border.all(color: c.texte.withValues(alpha: 0.14)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        survol
                            ? Icons.delete_rounded
                            : Icons.delete_outline_rounded,
                        size: 24,
                        color: c.texte,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        libelle,
                        maxLines: 1,
                        style: TextStyle(
                          color: c.texte,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
