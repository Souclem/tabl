import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Interstitiel "Ensuite" (megaprompt Bloc 2, règle 17, 19) : après le
/// dernier Instant d'une expérience, on propose la suivante mais on ne
/// bascule jamais automatiquement. L'utilisateur garde le contrôle.
class TablTransitionEnsuite extends StatelessWidget {
  const TablTransitionEnsuite({
    super.key,
    required this.auteurPseudo,
    required this.restaurantNom,
    required this.nombreInstants,
    required this.onContinuer,
    required this.onFermer,
  });

  final String auteurPseudo;
  final String restaurantNom;
  final int nombreInstants;
  final VoidCallback onContinuer;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onContinuer,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Ensuite',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: TablTokens.espaceS),
            Text(
              auteurPseudo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$restaurantNom · $nombreInstants Instant${nombreInstants > 1 ? 's' : ''}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
            ),
            const SizedBox(height: TablTokens.espaceL),
            TextButton(
              onPressed: onFermer,
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
