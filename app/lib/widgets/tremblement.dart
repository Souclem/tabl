import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Un geste refusé (« Nouveau moment » à trois brouillons, « Continuer »
/// avec trop de photos) : l'enfant grossit, tremble de gauche à droite, de
/// moins en moins, et le téléphone vibre deux fois. Chaque fois que
/// [refus] augmente, ça recommence.
class TablTremblement extends StatefulWidget {
  const TablTremblement({
    super.key,
    required this.refus,
    required this.child,
    this.alignement = Alignment.center,
  });

  /// Le nombre de refus : l'écran l'augmente à chaque geste refusé.
  final int refus;
  final Widget child;

  /// D'où l'enfant grossit.
  final Alignment alignement;

  @override
  State<TablTremblement> createState() => _TablTremblementState();
}

class _TablTremblementState extends State<TablTremblement>
    with SingleTickerProviderStateMixin {
  late final _refus = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void didUpdateWidget(TablTremblement ancien) {
    super.didUpdateWidget(ancien);
    if (widget.refus > ancien.refus) unawaited(_trembler());
  }

  @override
  void dispose() {
    _refus.dispose();
    super.dispose();
  }

  Future<void> _trembler() async {
    unawaited(_refus.forward(from: 0));
    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 110));
    await HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _refus,
      builder: (context, enfant) {
        final t = _refus.value;
        // Grossit puis revient ; tremble trois fois, de moins en moins.
        final echelle = 1 + 0.05 * math.sin(math.pi * t);
        final decalage = 9 * math.sin(t * 3 * 2 * math.pi) * (1 - t);
        return Transform.translate(
          offset: Offset(decalage, 0),
          child: Transform.scale(
            scale: echelle,
            alignment: widget.alignement,
            child: enfant,
          ),
        );
      },
      child: widget.child,
    );
  }
}
