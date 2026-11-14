import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Un bouton sous la cloche.
class ActionCloche {
  const ActionCloche({
    required this.libelle,
    required this.onPresse,
    this.principale = false,
  });

  final String libelle;

  /// `null` : le bouton est grisé (un geste est déjà en cours).
  final VoidCallback? onPresse;

  /// Plein et doré ; sinon, un simple contour.
  final bool principale;
}

/// La cloche de publication : le mot « À table », un trait doré qui se
/// remplit avec l'envoi, le pourcentage, une phrase d'état et deux boutons
/// au plus. Toujours sombre, quel que soit le réglage Apparence.
///
/// Composant pur : tout arrive prêt à l'affichage, les gestes repartent
/// par [ActionCloche.onPresse].
class TablClochePublication extends StatelessWidget {
  const TablClochePublication({
    super.key,
    required this.progression,
    required this.pourcentage,
    required this.mot,
    this.estompe = false,
    this.note,
    this.actions = const [],
  });

  /// La longueur du trait, de 0 à 1.
  final double progression;

  /// « 42 », sans le signe %.
  final String pourcentage;
  final String mot;

  /// Le pourcentage pâlit quand l'envoi est arrêté.
  final bool estompe;

  /// L'état en une phrase (« Le réseau est lent… »), ou rien.
  final String? note;
  final List<ActionCloche> actions;

  static const _tailleCloche = 200.0;

  @override
  Widget build(BuildContext context) {
    final or = TablTokens.primaire;
    return ColoredBox(
      color: TablTokens.fond,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 38),
            Semantics(
              label: 'Publication en cours',
              value: '$pourcentage %',
              excludeSemantics: true,
              child: Column(
                children: [
                  SizedBox(
                    width: _tailleCloche,
                    height: _tailleCloche,
                    child: CustomPaint(
                      painter: _PeintreCloche(
                        progression: progression.clamp(0.0, 1.0),
                        or: or,
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      text: pourcentage,
                      children: [
                        TextSpan(
                          text: ' %',
                          style: TablTokens.legende.copyWith(
                            color: or.withValues(alpha: estompe ? 0.35 : 0.75),
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    style: TablTokens.titreAffichage.copyWith(
                      fontSize: 20,
                      height: 1,
                      color: or.withValues(alpha: estompe ? 0.45 : 1),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                  Text(
                    mot,
                    style: TablTokens.titreAffichage.copyWith(fontSize: 34),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 62),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TablTokens.espaceXl,
              ),
              child: SizedBox(
                height: 44,
                child: Center(
                  child: note == null
                      ? null
                      : Semantics(
                          liveRegion: true,
                          child: Text(
                            note!,
                            textAlign: TextAlign.center,
                            style: TablTokens.legende.copyWith(
                              fontSize: 13,
                              height: 1.45,
                              color: TablTokens.texte.withValues(alpha: 0.66),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: TablTokens.espaceM),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                0,
                TablTokens.espaceM,
                TablTokens.espaceL,
              ),
              child: SizedBox(
                height: TablTokens.hauteurControle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: _BoutonCloche(action: actions[i]),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonCloche extends StatelessWidget {
  const _BoutonCloche({required this.action});

  final ActionCloche action;

  @override
  Widget build(BuildContext context) {
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
    );
    final bouton = action.principale
        ? FilledButton(
            onPressed: action.onPresse,
            style: FilledButton.styleFrom(
              backgroundColor: TablTokens.primaire,
              foregroundColor: TablTokens.texteSurPrimaire,
              disabledBackgroundColor: TablTokens.primaire.withValues(
                alpha: 0.4,
              ),
              disabledForegroundColor: TablTokens.texteSurPrimaire,
              shape: forme,
              textStyle: TablTokens.libelleBouton,
            ),
            child: Text(action.libelle, textAlign: TextAlign.center),
          )
        : OutlinedButton(
            onPressed: action.onPresse,
            style: OutlinedButton.styleFrom(
              foregroundColor: TablTokens.texte,
              disabledForegroundColor: TablTokens.texte.withValues(alpha: 0.4),
              backgroundColor: TablTokens.texte.withValues(alpha: 0.07),
              side: BorderSide(color: TablTokens.texte.withValues(alpha: 0.22)),
              shape: forme,
              textStyle: TablTokens.libelleBouton,
            ),
            child: Text(action.libelle, textAlign: TextAlign.center),
          );
    return SizedBox.expand(child: bouton);
  }
}

/// Le dôme de la cloche posé sur son plateau : le trait doré du plateau
/// se remplit de gauche à droite. Dessiné dans un carré de 200, comme la
/// maquette.
class _PeintreCloche extends CustomPainter {
  const _PeintreCloche({required this.progression, required this.or});

  final double progression;
  final Color or;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 200);

    final clair = Color.lerp(or, TablTokens.texte, 0.5)!;
    final degrade = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [clair, or, TablTokens.primaireFoncee],
    );
    final doree = Paint()
      ..shader = degrade.createShader(const Rect.fromLTWH(44, 67, 112, 66))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dome = Path()
      ..moveTo(58, 118)
      ..cubicTo(58, 92, 77, 74, 100, 74)
      ..cubicTo(123, 74, 142, 92, 142, 118)
      ..close();
    canvas.drawPath(dome, Paint()..color = or.withValues(alpha: 0.07));
    canvas.drawPath(dome, doree);

    final poignee = Path()
      ..moveTo(94, 74)
      ..cubicTo(94, 69, 97, 67, 100, 67)
      ..cubicTo(103, 67, 106, 69, 106, 74);
    canvas.drawPath(poignee, doree);

    const plateau = Rect.fromLTWH(44, 128, 112, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(plateau, const Radius.circular(2.5)),
      Paint()..color = TablTokens.texte.withValues(alpha: 0.13),
    );
    final largeur = plateau.width * progression;
    if (largeur > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(plateau.left, plateau.top, largeur, plateau.height),
          const Radius.circular(2.5),
        ),
        Paint()..shader = degrade.createShader(plateau),
      );
    }
    final tete = Offset(plateau.left + largeur, 130.5);
    canvas.drawCircle(
      tete,
      7,
      Paint()
        ..color = or.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(tete, 3, Paint()..color = clair);
  }

  @override
  bool shouldRepaint(_PeintreCloche ancien) =>
      ancien.progression != progression || ancien.or != or;
}
