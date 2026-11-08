import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Ma carte / Envies / Le cercle — ce sont des MODES de carte, pas des
/// filtres : une vraie hiérarchie de navigation principale, un
/// segmented control premium et sobre, jamais le même composant pill
/// que la portée sociale, les villes ou la période (megaprompt Bloc 1,
/// règles 12-13, 32).
///
/// Composant pur et générique : ne connaît aucune notion de "mode
/// carte" — juste des libellés et un index sélectionné, comme
/// `TablSelecteurEmotion` pour les émotions. C'est l'écran appelant qui
/// fait le lien avec `ModeCarte`.
class TablSegmentModeCarte extends StatelessWidget {
  const TablSegmentModeCarte({
    super.key,
    required this.options,
    required this.selectionne,
    required this.onSelection,
  });

  final List<String> options;
  final int selectionne;
  final ValueChanged<int> onSelection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TablTokens.surface,
        borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
        border: Border.all(color: TablTokens.bordure),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++) _segment(options[i], i),
        ],
      ),
    );
  }

  Widget _segment(String libelle, int index) {
    final actif = index == selectionne;
    return Semantics(
      label: libelle,
      button: true,
      selected: actif,
      child: GestureDetector(
        onTap: () => onSelection(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceM,
            vertical: TablTokens.espaceS,
          ),
          decoration: BoxDecoration(
            color: actif ? TablTokens.primaire : Colors.transparent,
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
          ),
          child: Text(
            libelle,
            style: TablTokens.legende.copyWith(
              fontWeight: FontWeight.w600,
              color: actif ? TablTokens.texteSurPrimaire : TablTokens.texteDoux,
            ),
          ),
        ),
      ),
    );
  }
}
