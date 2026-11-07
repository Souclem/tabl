import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'ligne_avis.dart';
import 'publication.dart';

/// Une publication qui passe de sa version compacte ([TablLigneAvis]) à
/// la version complète ([TablPublication]), sur place : la vignette grandit et glisse jusqu'à la place de la
/// grande photo, le texte compact s'efface en glissant pendant que la
/// hauteur s'ouvre, puis le reste de la publication apparaît. À la
/// fermeture, l'animation inverse. La ligne "Réduire" au-dessus de la
/// version complète fait partie du composant.
class TablPublicationDepliable extends StatefulWidget {
  const TablPublicationDepliable({
    super.key,
    required this.ouvert,
    required this.photoUrl,
    required this.compact,
    required this.complet,
    required this.onReduire,
  });

  /// Hauteur de la ligne "Réduire" au-dessus de la publication complète.
  static const hauteurReduire = 44.0;

  final bool ouvert;

  /// La photo de la publication, celle qui grandit pendant l'animation.
  final String? photoUrl;

  /// La version compacte, normalement un [TablLigneAvis].
  final Widget compact;

  /// La version complète, normalement un [TablPublication].
  final Widget complet;
  final VoidCallback onReduire;

  @override
  State<TablPublicationDepliable> createState() => _EtatPublicationDepliable();
}

class _EtatPublicationDepliable extends State<TablPublicationDepliable>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.ouvert ? 1 : 0,
  );
  final _cleCompact = GlobalKey();
  final _cleComplet = GlobalKey();

  /// Hauteurs mesurées des deux versions (la complète n'est connue
  /// qu'une fois construite).
  double? _hauteurCompacte;
  double? _hauteurComplete;

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((_) => setState(() {}));
  }

  @override
  void didUpdateWidget(TablPublicationDepliable ancien) {
    super.didUpdateWidget(ancien);
    if (widget.ouvert == ancien.ouvert) return;
    if (widget.ouvert) {
      // On construit d'abord la version complète (invisible) pour la
      // mesurer, puis on anime.
      _hauteurComplete = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hauteurCompacte = _cleCompact.currentContext?.size?.height;
          _hauteurComplete = _cleComplet.currentContext?.size?.height;
        });
        _animation.forward();
      });
    } else {
      _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  bool get _auRepos =>
      _animation.status == AnimationStatus.completed ||
      _animation.status == AnimationStatus.dismissed;

  Widget _complet(TablCouleurs c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: TablPublicationDepliable.hauteurReduire,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onReduire,
            icon: const Icon(Icons.expand_less_rounded, size: 18),
            label: const Text('Réduire'),
            style: TextButton.styleFrom(foregroundColor: c.texteDoux),
          ),
        ),
      ),
      widget.complet,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    // Au repos : la version affichée, telle quelle.
    if (_auRepos && !(widget.ouvert && _hauteurComplete == null)) {
      return widget.ouvert ? _complet(c) : widget.compact;
    }
    return LayoutBuilder(
      builder: (context, contraintes) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => _enMouvement(contraintes.maxWidth, c),
      ),
    );
  }

  Widget _enMouvement(double largeur, TablCouleurs c) {
    final t = Curves.easeInOutCubic.transform(_animation.value);
    final hauteurCompacte =
        _hauteurCompacte ??
        TablLigneAvis.cotePhoto + 2 * TablLigneAvis.margeHaut;
    final hauteurComplete = _hauteurComplete ?? hauteurCompacte;

    // La vignette, de sa place compacte à celle de la grande photo.
    const depart = Rect.fromLTWH(
      TablLigneAvis.margeGauche,
      TablLigneAvis.margeHaut,
      TablLigneAvis.cotePhoto,
      TablLigneAvis.cotePhoto,
    );
    final largeurPhoto = largeur - 2 * TablPublication.margePhoto;
    final arrivee = Rect.fromLTWH(
      TablPublication.margePhoto,
      TablPublicationDepliable.hauteurReduire + TablPublication.hauteurEnTete,
      largeurPhoto,
      largeurPhoto * TablPublication.proportionPhoto,
    );
    final photo = Rect.lerp(depart, arrivee, t)!;
    final arrondi = lerpDouble(
      TablLigneAvis.arrondiPhoto,
      TablPublication.arrondiPhoto,
      t,
    )!;

    // Le texte compact s'efface en glissant vers le bas pendant le début,
    // le reste de la publication apparaît à la fin.
    final effacement = const Interval(0, 0.4).transform(t);
    final apparition = const Interval(0.7, 1).transform(t);

    return ClipRect(
      child: SizedBox(
        height: lerpDouble(hauteurCompacte, hauteurComplete, t),
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Stack(
            children: [
              Opacity(
                opacity: apparition,
                child: KeyedSubtree(key: _cleComplet, child: _complet(c)),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - effacement,
                    child: Transform.translate(
                      offset: Offset(0, 24 * t),
                      child: KeyedSubtree(
                        key: _cleCompact,
                        child: widget.compact,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: photo,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(arrondi),
                  child: widget.photoUrl == null
                      ? ColoredBox(color: c.surface)
                      : Image.network(
                          widget.photoUrl!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              ColoredBox(color: c.surface),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
