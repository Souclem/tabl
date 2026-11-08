import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Fond décoratif plein écran pour un écran d'accueil : un dégradé chaud
/// statique, en attendant l'illustration finale (voir les maquettes dans
/// `instruction/`). Remplacer par une vraie image ne touchera que ce
/// fichier.
///
/// Volontairement statique et en dégradé linéaire uniquement : un dégradé
/// animé et/ou radial s'est révélé instable sur certains appareils
/// physiques avec le moteur de rendu Impeller (écran qui reste noir,
/// en particulier après une transition de page).
class TablFondHeros extends StatelessWidget {
  const TablFondHeros({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            TablTokens.primaireFoncee.withValues(alpha: 0.35),
            TablTokens.fond,
            TablTokens.fond,
          ],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: child,
    );
  }
}
