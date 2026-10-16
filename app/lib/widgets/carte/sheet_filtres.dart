import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// La sheet Filtres — réseau, personnes, et rien de plus : ne pas
/// ajouter de filtres pour le plaisir (megaprompt Bloc 1, règle 34).
/// Le réseau étendu reste réservé au Premium (règle 8, 14) : une option
/// [verrouille] ouvre l'explication Premium plutôt que de changer la
/// portée.
///
/// Composant pur et générique : ne connaît pas `PorteeSociale`, juste
/// des libellés et un index — c'est l'écran qui fait le lien.
class TablSheetFiltres extends StatelessWidget {
  const TablSheetFiltres({
    super.key,
    required this.optionsReseau,
    required this.reseauSelectionneIndex,
    required this.amis,
    required this.amiSelectionneId,
    required this.onReseauSelection,
    required this.onAmiChange,
    required this.onOuvrirPremium,
  });

  final List<({String libelle, bool verrouille})> optionsReseau;
  final int? reseauSelectionneIndex;
  final List<({String id, String pseudo})> amis;
  final String? amiSelectionneId;
  final ValueChanged<int> onReseauSelection;
  final ValueChanged<String?> onAmiChange;
  final VoidCallback onOuvrirPremium;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              TablTokens.espaceM,
              TablTokens.espaceM,
              TablTokens.espaceM,
              TablTokens.espaceS,
            ),
            child: Text('Réseau', style: TablTokens.sousTitre),
          ),
          for (var i = 0; i < optionsReseau.length; i++) _ligneReseau(i),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              TablTokens.espaceM,
              TablTokens.espaceM,
              TablTokens.espaceM,
              TablTokens.espaceS,
            ),
            child: Text('Personnes', style: TablTokens.sousTitre),
          ),
          RadioGroup<String?>(
            groupValue: amiSelectionneId,
            onChanged: onAmiChange,
            child: Column(
              children: [
                const RadioListTile<String?>(
                  value: null,
                  title: Text('Tous', style: TablTokens.corps),
                ),
                for (final ami in amis)
                  RadioListTile<String?>(
                    value: ami.id,
                    title: Text(ami.pseudo, style: TablTokens.corps),
                  ),
              ],
            ),
          ),
          const SizedBox(height: TablTokens.espaceM),
        ],
      ),
    );
  }

  Widget _ligneReseau(int index) {
    final option = optionsReseau[index];
    return ListTile(
      onTap: option.verrouille ? onOuvrirPremium : () => onReseauSelection(index),
      title: Text(
        option.verrouille ? '${option.libelle} 🔒' : option.libelle,
        style: TablTokens.corps,
      ),
      trailing: !option.verrouille && index == reseauSelectionneIndex
          ? const Icon(Icons.check, color: TablTokens.primaire)
          : null,
    );
  }
}
