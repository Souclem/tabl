import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Barre de recherche en pilule, loupe à gauche ; une croix apparaît
/// dès qu'il y a du texte, pour tout effacer d'un geste.
class TablBarreRecherche extends StatelessWidget {
  const TablBarreRecherche({
    super.key,
    required this.controleur,
    required this.indication,
    required this.onChanged,
  });

  final TextEditingController controleur;
  final String indication;

  /// Aussi appelé avec `''` quand on efface par la croix.
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: c.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
        border: Border.all(color: c.texte.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(Icons.search_rounded, size: 20, color: c.texteDoux),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controleur,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              autocorrect: false,
              cursorColor: c.primaire,
              style: c.corps.copyWith(fontSize: 15),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: indication,
                hintStyle: c.corps.copyWith(fontSize: 15, color: c.texteDoux),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controleur,
            builder: (context, valeur, _) => valeur.text.isEmpty
                ? const SizedBox(width: 14)
                : IconButton(
                    tooltip: 'Effacer',
                    onPressed: () {
                      controleur.clear();
                      onChanged('');
                    },
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 18,
                      color: c.texteDoux,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
