import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une ville agrégée à très grand zoom ("Paris 47") — design distinct
/// d'un raccourci ville personnel : c'est un objet cartographique, pas
/// un bouton de navigation (megaprompt Bloc 1, règle 20-21).
class TablMarqueurAgregatVille extends StatelessWidget {
  const TablMarqueurAgregatVille({
    super.key,
    required this.ville,
    required this.nombreRestaurants,
    required this.onTap,
  });

  final String ville;
  final int nombreRestaurants;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$ville, $nombreRestaurants adresses. Appuyez pour zoomer.',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceM,
            vertical: TablTokens.espaceS,
          ),
          decoration: BoxDecoration(
            color: TablTokens.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
            border: Border.all(color: TablTokens.bordure),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ville, style: TablTokens.titreAffichage.copyWith(fontSize: 16)),
              Text(
                '$nombreRestaurants',
                style: TablTokens.legende.copyWith(color: TablTokens.primaire),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
