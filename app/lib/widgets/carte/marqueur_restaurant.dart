import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Un restaurant individuel sur la carte — jamais un pin type Google
/// Maps, un petit bijou circulaire ivoire/champagne (megaprompt Bloc 1,
/// règle 3). [connuUniquementReseauEtendu] utilise un style secondaire
/// creux plutôt qu'une simple différence de couleur (règle 9).
/// [aDeLaRecurrence] ajoute un petit éclat, jamais une animation
/// permanente (règle 6).
///
/// Composant pur : [diametre] arrive déjà résolu (le calcul "1 proche →
/// petit, 4+ → grand" vit dans `services/carte/objet_cartographique.dart`,
/// pas ici — voir la règle d'organisation de CLAUDE.md).
class TablMarqueurRestaurant extends StatelessWidget {
  const TablMarqueurRestaurant({
    super.key,
    required this.diametre,
    required this.selectionne,
    required this.connuUniquementReseauEtendu,
    required this.aDeLaRecurrence,
    required this.libelleAccessibilite,
    required this.onTap,
  });

  final double diametre;
  final bool selectionne;
  final bool connuUniquementReseauEtendu;
  final bool aDeLaRecurrence;
  final String libelleAccessibilite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduireMouvement = MediaQuery.of(context).disableAnimations;
    final duree = reduireMouvement
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Semantics(
      label: libelleAccessibilite,
      button: true,
      // Zone tactile 44x44 même si le point visible est plus petit
      // (règle 63).
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: duree,
                  width: selectionne ? diametre + 6 : diametre,
                  height: selectionne ? diametre + 6 : diametre,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connuUniquementReseauEtendu
                        ? TablTokens.fond.withValues(alpha: 0.6)
                        : TablTokens.primaire,
                    border: Border.all(
                      color: TablTokens.primaire,
                      width: connuUniquementReseauEtendu
                          ? 1.5
                          : (selectionne ? 1.5 : 0),
                    ),
                  ),
                ),
                if (aDeLaRecurrence)
                  const Positioned(
                    top: -1,
                    right: -1,
                    child: Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: TablTokens.primaire,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
