import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Le « J'aime » de Tabl : deux verres qui trinquent. Au tap, ils se
/// penchent l'un vers l'autre, s'entrechoquent dans quelques éclats
/// dorés, puis se remplissent d'or ; retaper les vide. Rien que de
/// l'image : pas de libellé, le geste se comprend tout seul.
///
/// Composant pur : ne décide jamais lui-même s'il faut réagir ou pas,
/// joue l'animation et prévient via [onPresse] ; [actif] (rempli ou
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
  late final AnimationController _tchin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  );

  // La chorégraphie, en fractions de la durée.
  static const _approche = Interval(0, 0.32, curve: Curves.easeInCubic);
  static const _rebond = Interval(0.32, 0.75, curve: Curves.elasticOut);
  static const _eclats = Interval(0.3, 0.72, curve: Curves.easeOut);

  @override
  void dispose() {
    _tchin.dispose();
    super.dispose();
  }

  void _declencher() {
    // On ne trinque qu'en aimant ; ne plus aimer vide simplement les
    // verres (voir le remplissage, qui suit [actif]).
    if (!widget.actif) _tchin.forward(from: 0);
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
                duration: Duration(milliseconds: widget.actif ? 520 : 300),
                curve: widget.actif
                    ? const Interval(0.3, 1, curve: Curves.easeOutCubic)
                    : Curves.easeIn,
                builder: (context, remplissage, _) => AnimatedBuilder(
                  animation: _tchin,
                  builder: (context, _) {
                    final t = _tchin.value;
                    final enMouvement = _tchin.isAnimating;
                    return CustomPaint(
                      size: Size.square(widget.taille),
                      painter: _PeintreVerres(
                        approche: enMouvement ? _approche.transform(t) : 0,
                        rebond: enMouvement ? _rebond.transform(t) : 1,
                        eclats: enMouvement && t >= _eclats.begin
                            ? _eclats.transform(t)
                            : 0,
                        remplissage: remplissage,
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

class _PeintreVerres extends CustomPainter {
  _PeintreVerres({
    required this.approche,
    required this.rebond,
    required this.eclats,
    required this.remplissage,
    required this.actif,
    required this.couleurActive,
    required this.couleurRepos,
  });

  /// 0 → 1 : les verres se penchent jusqu'au choc.
  final double approche;

  /// 0 → 1 après le choc : ils reviennent en place en rebondissant.
  final double rebond;

  /// 0 → 1 : les éclats jaillissent puis s'effacent.
  final double eclats;

  /// 0 → 1 : le vin doré monte dans les verres.
  final double remplissage;
  final bool actif;

  /// Les verres qui trinquent, le vin, les éclats.
  final Color couleurActive;

  /// Les verres au repos.
  final Color couleurRepos;

  // Inclinaison (radians) : au repos, en pleine trinque.
  static const _repos = 10 * math.pi / 180;
  static const _reposAime = 5 * math.pi / 180;
  static const _choc = -20 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final echelle = size.width / 30;
    canvas.save();
    canvas.scale(echelle);

    final repos = actif ? _reposAime : _repos;
    // Avant le choc on s'approche ; après, on revient vers le repos.
    final angle = approche < 1
        ? repos + (_choc - repos) * approche
        : _choc + (repos - _choc) * rebond;

    final couleur = actif || approche > 0 ? couleurActive : couleurRepos;
    _verre(canvas, const Offset(8, 28), -angle, couleur);
    _verre(canvas, const Offset(22, 28), angle, couleur);

    if (eclats > 0) {
      final pinceau = Paint()
        ..color = couleurActive.withValues(alpha: 1 - eclats)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      const centre = Offset(15, 6);
      for (final degres in const [-150, -110, -70, -30]) {
        final a = degres * math.pi / 180;
        final direction = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          centre + direction * (2 + 5 * eclats),
          centre + direction * (4 + 8 * eclats),
          pinceau,
        );
      }
    }
    canvas.restore();
  }

  /// Un verre à pied, dessiné depuis son pied ([pied]) et penché de
  /// [inclinaison] (positif : le haut part vers la droite).
  void _verre(Canvas canvas, Offset pied, double inclinaison, Color couleur) {
    canvas.save();
    canvas.translate(pied.dx, pied.dy);
    canvas.rotate(inclinaison);

    final coupe = Path()
      ..moveTo(-5, -24)
      ..cubicTo(-5, -16, -3, -12.5, 0, -12.5)
      ..cubicTo(3, -12.5, 5, -16, 5, -24)
      ..close();

    if (remplissage > 0) {
      canvas.save();
      canvas.clipPath(coupe);
      final niveau = -12.5 - 9.5 * remplissage;
      canvas.drawRect(
        Rect.fromLTRB(-6, niveau, 6, -12),
        Paint()..color = couleurActive.withValues(alpha: 0.85),
      );
      canvas.restore();
    }

    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(coupe, trait);
    canvas.drawLine(const Offset(0, -12.5), const Offset(0, -1.5), trait);
    canvas.drawLine(const Offset(-3.8, -1.2), const Offset(3.8, -1.2), trait);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PeintreVerres ancien) =>
      ancien.approche != approche ||
      ancien.rebond != rebond ||
      ancien.eclats != eclats ||
      ancien.remplissage != remplissage ||
      ancien.actif != actif ||
      ancien.couleurActive != couleurActive ||
      ancien.couleurRepos != couleurRepos;
}
