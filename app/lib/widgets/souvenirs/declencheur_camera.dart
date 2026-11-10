import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le nombre de photos qu'un moment publie au plus : une graduation par
/// photo autour du déclencheur.
const _nombreGraduations = 10;

/// Le déclencheur de l'écran caméra : un anneau, un disque ivoire, et
/// dix graduations dorées qui s'allument une à une, une par photo. Le
/// geste part dès le toucher, pas au relâchement.
class DeclencheurCamera extends StatefulWidget {
  const DeclencheurCamera({
    super.key,
    required this.nombrePhotos,
    required this.onDeclencher,
    this.actif = true,
    this.libelle = 'Prendre une photo',
  });

  /// Les photos déjà gardées : autant de graduations allumées (dix au plus).
  final int nombrePhotos;
  final VoidCallback onDeclencher;

  /// `false` : la caméra n'est pas prête, le déclencheur est grisé.
  final bool actif;
  final String libelle;

  @override
  State<DeclencheurCamera> createState() => _DeclencheurCameraState();
}

class _DeclencheurCameraState extends State<DeclencheurCamera>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  var _enfonce = false;

  @override
  void didUpdateWidget(DeclencheurCamera ancien) {
    super.didUpdateWidget(ancien);
    if (widget.nombrePhotos > ancien.nombrePhotos &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _toucher() {
    if (!widget.actif) return;
    setState(() => _enfonce = true);
    widget.onDeclencher();
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final allumees = math.min(widget.nombrePhotos, _nombreGraduations);
    return Semantics(
      button: true,
      enabled: widget.actif,
      label: widget.libelle,
      onTap: widget.actif ? widget.onDeclencher : null,
      child: ExcludeSemantics(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _toucher(),
          onPointerUp: (_) => setState(() => _enfonce = false),
          onPointerCancel: (_) => setState(() => _enfonce = false),
          child: Opacity(
            opacity: widget.actif ? 1 : 0.4,
            child: SizedBox(
              width: 96,
              height: 96,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedOpacity(
                    opacity: allumees > 0 ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) => Transform.scale(
                        scale: allumees == _nombreGraduations
                            ? 1 + 0.03 * math.sin(_pulse.value * math.pi)
                            : 1,
                        child: CustomPaint(
                          size: const Size.square(96),
                          painter: _PeintreGraduations(
                            allumees: allumees,
                            pulse: _pulse.value,
                            dore: c.primaire,
                            eteint: c.texte.withValues(alpha: 0.24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: c.texte.withValues(alpha: 0.92),
                        width: 3.5,
                      ),
                    ),
                  ),
                  AnimatedScale(
                    scale: _enfonce ? 0.88 : 1,
                    duration: const Duration(milliseconds: 60),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: c.texte,
                        border: Border.all(
                          color: c.primaire.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dix arcs de 28° tous les 36°, le premier juste à droite du haut.
class _PeintreGraduations extends CustomPainter {
  _PeintreGraduations({
    required this.allumees,
    required this.pulse,
    required this.dore,
    required this.eteint,
  });

  final int allumees;
  final double pulse;
  final Color dore;
  final Color eteint;

  @override
  void paint(Canvas canvas, Size size) {
    final rayon = size.width * 45 / 96;
    final cadre = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: rayon,
    );
    for (var k = 0; k < _nombreGraduations; k++) {
      final allumee = k < allumees;
      // La graduation qui vient de s'allumer grossit un instant.
      final epaisseur = allumee && k == allumees - 1 && pulse > 0 && pulse < 1
          ? 1.75 + 1.25 * math.sin(pulse * math.pi)
          : 1.75;
      final trait = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = epaisseur
        ..color = allumee ? dore : eteint;
      final debut = (-86 + 36 * k) * math.pi / 180;
      canvas.drawArc(cadre, debut, 28 * math.pi / 180, false, trait);
    }
  }

  @override
  bool shouldRepaint(_PeintreGraduations ancien) =>
      ancien.allumees != allumees ||
      ancien.pulse != pulse ||
      ancien.dore != dore ||
      ancien.eteint != eteint;
}
