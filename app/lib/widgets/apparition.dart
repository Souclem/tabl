import 'package:flutter/material.dart';

/// Fait arriver son contenu en fondu, en remontant un peu, après
/// [retard] — pour qu'une page se construise en cascade plutôt que d'un
/// bloc. Rejoue l'animation quand sa `key` change (une autre année…).
class TablApparition extends StatefulWidget {
  const TablApparition({
    super.key,
    required this.child,
    this.retard = Duration.zero,
  });

  final Widget child;
  final Duration retard;

  @override
  State<TablApparition> createState() => _TablApparitionState();
}

class _TablApparitionState extends State<TablApparition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  late final Animation<double> _courbe = CurvedAnimation(
    parent: _controleur,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.retard, () {
      if (mounted) _controleur.forward();
    });
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _courbe,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_courbe),
        child: widget.child,
      ),
    );
  }
}
