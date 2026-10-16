import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Plusieurs restaurants regroupés — visuellement bien distinct d'un
/// restaurant individuel : cercle plus grand, fond plus sombre, contour
/// champagne, chiffre centré (megaprompt Bloc 1, règle 23). Le chiffre
/// est toujours un nombre d'adresses, jamais autre chose (règle 22).
class TablMarqueurCluster extends StatelessWidget {
  const TablMarqueurCluster({
    super.key,
    required this.nombreRestaurants,
    required this.onTap,
  });

  final int nombreRestaurants;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$nombreRestaurants adresses dans cette zone. Appuyez pour zoomer.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TablTokens.surface,
            border: Border.all(color: TablTokens.primaire, width: 1.5),
          ),
          child: Text(
            '$nombreRestaurants',
            style: TablTokens.sousTitre.copyWith(color: TablTokens.primaire),
          ),
        ),
      ),
    );
  }
}
