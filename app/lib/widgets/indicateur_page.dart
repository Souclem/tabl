import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Rangée de points indiquant la position dans une série d'écrans
/// (ex. le parcours de présentation).
class TablIndicateurPage extends StatelessWidget {
  const TablIndicateurPage({
    super.key,
    required this.total,
    required this.index,
  });

  /// Nombre total de pages.
  final int total;

  /// Index de la page active (0-based).
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final actif = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceXs / 2,
          ),
          width: actif
              ? TablTokens.tailleIndicateurPageActif
              : TablTokens.tailleIndicateurPage,
          height: TablTokens.tailleIndicateurPage,
          decoration: BoxDecoration(
            color: actif ? c.primaire : c.bordure,
            borderRadius: BorderRadius.circular(
              TablTokens.tailleIndicateurPage,
            ),
          ),
        );
      }),
    );
  }
}
