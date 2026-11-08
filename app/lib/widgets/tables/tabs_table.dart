import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les 3 onglets d'une Table (megaprompt Bloc 3, règle 2, 76) : "Notre
/// histoire", "On y va ?", "À découvrir", toujours dans cet ordre.
///
/// Visuellement distinct du segmented control de la carte (règle 76 :
/// "pas même design que GO / Garder / Voir sur la carte") — un
/// soulignement champagne très subtil plutôt qu'un fond plein, pour
/// rester clairement des tabs de navigation, pas des boutons d'action.
/// Composant pur et générique, comme `TablSegmentModeCarte`.
class TablTabsTable extends StatelessWidget {
  const TablTabsTable({
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
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) Expanded(child: _tab(options[i], i)),
      ],
    );
  }

  Widget _tab(String libelle, int index) {
    final actif = index == selectionne;
    return Semantics(
      label: actif ? '$libelle, sélectionné' : libelle,
      button: true,
      selected: actif,
      child: InkWell(
        onTap: () => onSelection(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: actif ? TablTokens.primaire : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            libelle,
            textAlign: TextAlign.center,
            style: TablTokens.legende.copyWith(
              fontWeight: actif ? FontWeight.w700 : FontWeight.w500,
              color: actif ? TablTokens.texte : TablTokens.texteDoux,
            ),
          ),
        ),
      ),
    );
  }
}
