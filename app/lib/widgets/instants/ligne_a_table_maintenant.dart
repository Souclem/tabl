import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une ligne de la sheet "À table maintenant" (megaprompt Bloc 2,
/// règle 13-14) : le restaurant reste aussi important que la personne,
/// jamais "Thomas a posté." — toujours "Thomas · Septime · 3 nouveaux
/// Instants".
class TablLigneATableMaintenant extends StatelessWidget {
  const TablLigneATableMaintenant({
    super.key,
    required this.auteurPseudo,
    required this.restaurantNom,
    required this.libelleInstants,
    required this.nonVu,
    required this.onTap,
  });

  final String auteurPseudo;
  final String restaurantNom;

  /// "3 nouveaux Instants", "1 Instant", "vu"...
  final String libelleInstants;
  final bool nonVu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initiale = auteurPseudo.isEmpty ? '?' : auteurPseudo[0].toUpperCase();
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: TablTokens.primaire.withValues(
          alpha: nonVu ? 0.85 : 0.4,
        ),
        child: Text(
          initiale,
          style: TablTokens.legende.copyWith(
            color: TablTokens.texteSurPrimaire,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        auteurPseudo,
        style: TablTokens.corps.copyWith(
          fontWeight: nonVu ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        '$restaurantNom · $libelleInstants',
        style: TablTokens.legende.copyWith(
          color: nonVu ? TablTokens.primaire : TablTokens.texteDoux,
        ),
      ),
    );
  }
}
