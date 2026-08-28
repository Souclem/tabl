import 'package:flutter/material.dart';

/// Fondu + léger glissement sur un sous-intervalle d'un [AnimationController]
/// partagé, pour faire arriver plusieurs sections d'un écran en cascade
/// plutôt que d'un bloc (ex. logo, texte puis boutons de l'accueil).
///
/// `depart: Offset.zero` donne un simple fondu, sans glissement.
class TablEntreeEchelonnee extends StatelessWidget {
  const TablEntreeEchelonnee({
    super.key,
    required this.controleur,
    required this.debut,
    required this.fin,
    required this.child,
    this.depart = Offset.zero,
    this.courbe = Curves.easeOutCubic,
  });

  /// Le contrôleur d'animation partagé par toutes les sections de l'écran.
  final AnimationController controleur;

  /// Bornes (0 à 1) de l'intervalle de [controleur] sur lequel cette
  /// section anime — permet le décalage entre sections.
  final double debut;
  final double fin;

  final Offset depart;
  final Curve courbe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = CurvedAnimation(
      parent: controleur,
      curve: Interval(debut, fin, curve: courbe),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: depart,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
