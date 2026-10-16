import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// La sheet Période — un titre, un handle, pas de bouton "Valider" : le
/// choix ferme immédiatement (megaprompt Bloc 1, règles 33, 54).
///
/// Composant pur et générique : ne connaît pas `PeriodeCarte`, juste des
/// libellés et un index — c'est l'écran qui fait le lien.
class TablSheetPeriode extends StatelessWidget {
  const TablSheetPeriode({
    super.key,
    required this.options,
    required this.selectionneIndex,
    required this.onSelection,
  });

  final List<String> options;
  final int selectionneIndex;
  final ValueChanged<int> onSelection;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Handle(),
        const Padding(
          padding: EdgeInsets.fromLTRB(
            TablTokens.espaceM,
            TablTokens.espaceS,
            TablTokens.espaceM,
            TablTokens.espaceS,
          ),
          child: Text('Période', style: TablTokens.sousTitre),
        ),
        for (var i = 0; i < options.length; i++)
          ListTile(
            onTap: () => onSelection(i),
            title: Text(options[i], style: TablTokens.corps),
            trailing: i == selectionneIndex
                ? const Icon(Icons.check, color: TablTokens.primaire)
                : null,
          ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: TablTokens.espaceS),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: TablTokens.bordure,
          borderRadius: BorderRadius.circular(TablTokens.arrondiS),
        ),
      ),
    );
  }
}
