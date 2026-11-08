import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Sélecteur d'émotion à la finalisation d'un moment : "Comment
/// c'était ?", de vrais emoji, celui choisi grossit légèrement pour se
/// détacher des autres (voir
/// `instruction/Clément (2)/scraps/clement.txt`, B9).
///
/// Composant pur : ne connaît aucune notion d'"émotion" métier, juste une
/// liste d'emoji parmi lesquels un seul peut être sélectionné — c'est
/// l'écran appelant qui fait le lien avec son propre modèle.
class TablSelecteurEmotion extends StatelessWidget {
  const TablSelecteurEmotion({
    super.key,
    required this.emojis,
    required this.selection,
    required this.onSelection,
  });

  final List<String> emojis;

  /// L'emoji actuellement sélectionné, ou `null`.
  final String? selection;

  final ValueChanged<String> onSelection;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (final emoji in emojis)
          _BoutonEmotion(
            emoji: emoji,
            actif: emoji == selection,
            onPresse: () => onSelection(emoji),
          ),
      ],
    );
  }
}

class _BoutonEmotion extends StatelessWidget {
  const _BoutonEmotion({
    required this.emoji,
    required this.actif,
    required this.onPresse,
  });

  final String emoji;
  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return GestureDetector(
      onTap: onPresse,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: actif ? 1.35 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(TablTokens.espaceS),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: actif
                ? c.primaire.withValues(alpha: 0.14)
                : Colors.transparent,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
