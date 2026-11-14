import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// « Aa » : écrire un mot (rail de la finalisation).
class IconeMot extends StatelessWidget {
  const IconeMot({super.key, this.couleur});

  final Color? couleur;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Aa',
      style: TablTokens.titreAffichage.copyWith(
        fontSize: 19,
        height: 1,
        fontWeight: FontWeight.w400,
        color: couleur ?? TablTokens.texte,
      ),
    );
  }
}

/// Deux étincelles : « Ce qui ressort ».
class IconeEtincelle extends StatelessWidget {
  const IconeEtincelle({super.key, this.taille = 18, this.couleur});

  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(taille),
    painter: _PeintreEtincelle(couleur ?? TablTokens.texte),
  );
}

/// Deux silhouettes : « Avec qui ».
class IconeAvecQui extends StatelessWidget {
  const IconeAvecQui({super.key, this.taille = 19, this.couleur});

  final double taille;
  final Color? couleur;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(taille),
    painter: _PeintreAvecQui(couleur ?? TablTokens.texte),
  );
}

// Les deux dessins suivent ceux du prototype, sur une grille de 24.

Path _etoile(double x, double haut, double bas, double gauche, double droite) {
  final milieu = (haut + bas) / 2;
  final ry = (bas - haut) / 2;
  final rx = (droite - gauche) / 2;
  // Les points de contrôle tirent chaque branche vers le centre.
  return Path()
    ..moveTo(x, haut)
    ..cubicTo(
      x + rx * .08,
      milieu - ry * .34,
      x + rx * .35,
      milieu - ry * .08,
      droite,
      milieu,
    )
    ..cubicTo(
      x + rx * .35,
      milieu + ry * .08,
      x + rx * .08,
      milieu + ry * .34,
      x,
      bas,
    )
    ..cubicTo(
      x - rx * .08,
      milieu + ry * .34,
      x - rx * .35,
      milieu + ry * .08,
      gauche,
      milieu,
    )
    ..cubicTo(
      x - rx * .35,
      milieu - ry * .08,
      x - rx * .08,
      milieu - ry * .34,
      x,
      haut,
    )
    ..close();
}

class _PeintreEtincelle extends CustomPainter {
  const _PeintreEtincelle(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    canvas.drawPath(
      _etoile(12, 2.5, 17.5, 4.5, 19.5),
      Paint()..color = couleur,
    );
    canvas.drawPath(
      _etoile(19, 15.5, 21.5, 16, 22),
      Paint()..color = couleur.withValues(alpha: couleur.a * .7),
    );
  }

  @override
  bool shouldRepaint(_PeintreEtincelle ancien) => ancien.couleur != couleur;
}

class _PeintreAvecQui extends CustomPainter {
  const _PeintreAvecQui(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final trait = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawCircle(const Offset(9, 8), 3.2, trait)
      ..drawCircle(const Offset(16.5, 9), 2.6, trait)
      ..drawPath(
        Path()
          ..moveTo(3, 19)
          ..cubicTo(3.7, 15.8, 6, 14, 9, 14)
          ..cubicTo(12, 14, 14.3, 15.8, 15, 19)
          ..moveTo(15.5, 13.6)
          ..cubicTo(17.9, 13.6, 19.8, 15, 20.4, 17.6),
        trait,
      );
  }

  @override
  bool shouldRepaint(_PeintreAvecQui ancien) => ancien.couleur != couleur;
}
