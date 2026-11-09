import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le moment est gardé : une coche dorée qui apparaît, un instant, avant
/// de revenir au Feed.
class TablMomentGarde extends StatelessWidget {
  const TablMomentGarde({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, enfant) => Opacity(
        opacity: t,
        child: ColoredBox(
          color: c.fond.withValues(alpha: 0.86),
          child: Center(
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: enfant),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: c.primaire, size: 64),
          const SizedBox(height: TablTokens.espaceM),
          Text('Moment gardé.', style: c.titreAffichage.copyWith(fontSize: 26)),
        ],
      ),
    );
  }
}
