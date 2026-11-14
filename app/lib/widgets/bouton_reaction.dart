import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Le « J'aime » de Tabl : la cloche de service, la signature de l'app.
/// Au tap, elle se tasse, son dôme se soulève et laisse jaillir un cœur
/// doré dans quelques éclats, puis retombe et se remplit d'or, le cœur
/// gravé dedans ; retaper la vide. Rien que de l'image : pas de libellé,
/// le geste se comprend tout seul.
///
/// Composant pur : ne décide jamais lui-même s'il faut réagir ou pas,
/// joue l'animation et prévient via [onPresse] ; [actif] (remplie ou
/// non) vient de l'écran.
class TablBoutonReaction extends StatefulWidget {
  const TablBoutonReaction({
    super.key,
    required this.actif,
    required this.onPresse,
    this.taille = 30,
  });

  final bool actif;
  final VoidCallback onPresse;

  /// Côté du dessin ; la zone touchable fait toujours au moins 44 px.
  final double taille;

  @override
  State<TablBoutonReaction> createState() => _TablBoutonReactionState();
}

class _TablBoutonReactionState extends State<TablBoutonReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ouverture = AnimationController(
    vsync: this,
    duration: _duree,
  );

  static const _duree = Duration(milliseconds: 900);

  // La chorégraphie, en fractions de la durée.
  static const _appui = Interval(0, 0.12, curve: Curves.easeOut);
  static const _relache = Interval(0.12, 0.26, curve: Curves.easeOut);
  static const _levee = Interval(0.1, 0.38, curve: Curves.easeOutBack);
  static const _retombee = Interval(0.66, 0.88, curve: Curves.easeInCubic);
  static const _jaillit = Interval(0.2, 0.55, curve: ElasticOutCurve(0.55));
  static const _monte = Interval(0.2, 0.5, curve: Curves.easeOutCubic);
  static const _eclats = Interval(0.3, 0.7, curve: Curves.easeOut);
  static const _efface = Interval(0.68, 0.84, curve: Curves.easeIn);

  /// Où est le cœur : sous le dôme, au-dessus du plateau quand il a
  /// jailli, puis vers sa place gravée quand le dôme retombe (il s'efface
  /// alors, l'or prend le relais).
  static const _coeurDepart = Offset(15, 22);
  static const _coeurHaut = _PeintreCloche.coeurHaut;

  @override
  void dispose() {
    _ouverture.dispose();
    super.dispose();
  }

  void _declencher() {
    // La cloche ne s'ouvre qu'en aimant ; ne plus aimer la vide
    // simplement (voir le remplissage, qui suit [actif]).
    if (!widget.actif) _ouverture.forward(from: 0);
    widget.onPresse();
  }

  @override
  Widget build(BuildContext context) {
    final libelle = widget.actif ? 'Aimé' : "J'aime";
    final couleurs = TablCouleurs.of(context);
    return Tooltip(
      message: libelle,
      child: Semantics(
        button: true,
        toggled: widget.actif,
        label: "J'aime",
        excludeSemantics: true,
        child: GestureDetector(
          onTap: _declencher,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: math.max(44, widget.taille + 8),
            height: 44,
            child: Center(
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: widget.actif ? 1 : 0),
                // L'or arrive quand le dôme est retombé.
                duration: widget.actif
                    ? _duree
                    : const Duration(milliseconds: 300),
                curve: widget.actif
                    ? const Interval(0.86, 1, curve: Curves.easeOutCubic)
                    : Curves.easeIn,
                builder: (context, remplissage, _) => AnimatedBuilder(
                  animation: _ouverture,
                  builder: (context, _) {
                    final t = _ouverture.value;
                    final anime = _ouverture.isAnimating;
                    final retombee = anime ? _retombee.transform(t) : 0.0;
                    final jaillit = anime ? _jaillit.transform(t) : 0.0;
                    final coeur = anime && jaillit > 0
                        ? (
                            centre: Offset.lerp(
                              Offset.lerp(
                                _coeurDepart,
                                _coeurHaut,
                                _monte.transform(t),
                              ),
                              _PeintreCloche.coeurGrave,
                              retombee,
                            )!,
                            largeur: lerpDouble(
                              9 * jaillit,
                              _PeintreCloche.largeurGrave,
                              retombee,
                            )!,
                            opacite: 1 - _efface.transform(t),
                          )
                        : null;
                    return CustomPaint(
                      size: Size.square(widget.taille),
                      painter: _PeintreCloche(
                        appui: anime
                            ? _appui.transform(t) - _relache.transform(t)
                            : 0,
                        ouverture: anime ? _levee.transform(t) - retombee : 0,
                        coeur: coeur,
                        eclats: anime && t >= _eclats.begin
                            ? _eclats.transform(t)
                            : 0,
                        remplissage: remplissage,
                        anime: anime,
                        actif: widget.actif,
                        couleurActive: couleurs.primaire,
                        couleurRepos: couleurs.texteDoux,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le cœur en vol : son centre et sa largeur (dans le carré de 30 du
/// dessin), et son opacité.
typedef _Coeur = ({Offset centre, double largeur, double opacite});

/// La cloche dessinée dans un carré de 30 : le plateau, le dôme et sa
/// poignée, le cœur.
class _PeintreCloche extends CustomPainter {
  _PeintreCloche({
    required this.appui,
    required this.ouverture,
    required this.coeur,
    required this.eclats,
    required this.remplissage,
    required this.anime,
    required this.actif,
    required this.couleurActive,
    required this.couleurRepos,
  });

  /// 0 → 1 → 0 : la cloche se tasse sous le doigt, puis se relève.
  final double appui;

  /// 0 → 1 → 0 : le dôme se soulève en pivotant sur son bord droit, puis
  /// retombe.
  final double ouverture;

  /// Le cœur qui jaillit, ou rien.
  final _Coeur? coeur;

  /// 0 → 1 : les éclats jaillissent puis s'effacent.
  final double eclats;

  /// 0 → 1 : le dôme se remplit d'or, le cœur gravé dedans.
  final double remplissage;

  /// L'animation joue (la cloche est alors dorée même avant d'être
  /// aimée).
  final bool anime;
  final bool actif;

  /// La cloche aimée, le cœur, les éclats.
  final Color couleurActive;

  /// La cloche au repos.
  final Color couleurRepos;

  /// Le cœur jailli, sous le dôme ouvert.
  static const coeurHaut = Offset(13.5, 17);

  /// Le cœur gravé dans le dôme rempli : son centre et sa largeur.
  static const coeurGrave = Offset(15, 17.6);
  static const largeurGrave = 6.6;

  /// Le dôme, posé sur la ligne y = 23.
  static final _dome = Path()
    ..moveTo(5, 23)
    ..cubicTo(5, 15.5, 9.5, 10, 15, 10)
    ..cubicTo(20.5, 10, 25, 15.5, 25, 23)
    ..close();

  static final _poignee = Path()
    ..moveTo(13.2, 10)
    ..cubicTo(13.2, 8.2, 14.1, 7.4, 15, 7.4)
    ..cubicTo(15.9, 7.4, 16.8, 8.2, 16.8, 10);

  /// Le dôme rempli, le cœur découpé dedans (le fond se voit au travers).
  static final _domeGrave = Path.combine(
    PathOperation.difference,
    _dome,
    _cheminCoeur(coeurGrave, largeurGrave),
  );

  /// Pivot du dôme quand il se soulève : son bord droit.
  static const _charniere = Offset(25, 23);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 30);

    // L'appui tasse toute la cloche contre la table.
    if (appui > 0) {
      canvas.translate(15, 25);
      canvas.scale(1 + 0.08 * appui, 1 - 0.12 * appui);
      canvas.translate(-15, -25);
    }

    final couleur = actif || anime ? couleurActive : couleurRepos;
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Le plateau.
    canvas.drawLine(const Offset(3.5, 25.5), const Offset(26.5, 25.5), trait);

    // Le cœur, sous le dôme : il n'apparaît que quand celui-ci se lève.
    final c = coeur;
    if (c != null && c.largeur > 0.1 && c.opacite > 0) {
      canvas.drawPath(
        _cheminCoeur(c.centre, c.largeur),
        Paint()..color = couleurActive.withValues(alpha: c.opacite),
      );
    }

    // Le dôme et sa poignée, soulevés autour de la charnière.
    canvas.save();
    if (ouverture != 0) {
      canvas.translate(_charniere.dx, _charniere.dy - 6 * ouverture);
      canvas.rotate(34 * math.pi / 180 * ouverture);
      canvas.translate(-_charniere.dx, -_charniere.dy);
    }
    if (remplissage > 0) {
      canvas.drawPath(
        _domeGrave,
        Paint()..color = couleurActive.withValues(alpha: 0.9 * remplissage),
      );
    }
    canvas.drawPath(_dome, trait);
    canvas.drawPath(_poignee, trait);
    canvas.restore();

    // Les éclats, autour du cœur, du côté où le dôme s'est ouvert.
    if (eclats > 0 && eclats < 1) {
      final pinceau = Paint()
        ..color = couleurActive.withValues(alpha: 1 - eclats)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      const centre = coeurHaut;
      for (final degres in const [-175, -140, -105]) {
        final a = degres * math.pi / 180;
        final direction = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          centre + direction * (6 + 3 * eclats),
          centre + direction * (8 + 5 * eclats),
          pinceau,
        );
      }
    }
    canvas.restore();
  }

  /// Un cœur de [largeur] centré sur [centre] (un peu moins haut que
  /// large).
  static Path _cheminCoeur(Offset centre, double largeur) {
    final l = largeur;
    Offset p(double x, double y) => centre + Offset(x * l, y * l);
    final haut = p(0, -0.32);
    final bas = p(0, 0.4);
    final g1 = p(-0.1, 0.3), g2 = p(-0.5, 0.05), g3 = p(-0.5, -0.17);
    final g4 = p(-0.5, -0.36), g5 = p(-0.36, -0.47), g6 = p(-0.22, -0.47);
    final g7 = p(-0.11, -0.47), g8 = p(-0.03, -0.41);
    final d7 = p(0.03, -0.41), d8 = p(0.11, -0.47), d6 = p(0.22, -0.47);
    final d5 = p(0.36, -0.47), d4 = p(0.5, -0.36), d3 = p(0.5, -0.17);
    final d2 = p(0.5, 0.05), d1 = p(0.1, 0.3);
    return Path()
      ..moveTo(bas.dx, bas.dy)
      ..cubicTo(g1.dx, g1.dy, g2.dx, g2.dy, g3.dx, g3.dy)
      ..cubicTo(g4.dx, g4.dy, g5.dx, g5.dy, g6.dx, g6.dy)
      ..cubicTo(g7.dx, g7.dy, g8.dx, g8.dy, haut.dx, haut.dy)
      ..cubicTo(d7.dx, d7.dy, d8.dx, d8.dy, d6.dx, d6.dy)
      ..cubicTo(d5.dx, d5.dy, d4.dx, d4.dy, d3.dx, d3.dy)
      ..cubicTo(d2.dx, d2.dy, d1.dx, d1.dy, bas.dx, bas.dy)
      ..close();
  }

  @override
  bool shouldRepaint(_PeintreCloche ancien) =>
      ancien.appui != appui ||
      ancien.ouverture != ouverture ||
      ancien.coeur != coeur ||
      ancien.eclats != eclats ||
      ancien.remplissage != remplissage ||
      ancien.anime != anime ||
      ancien.actif != actif ||
      ancien.couleurActive != couleurActive ||
      ancien.couleurRepos != couleurRepos;
}
