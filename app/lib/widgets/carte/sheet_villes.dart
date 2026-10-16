import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// La sheet d'ajout/gestion des raccourcis villes (megaprompt Bloc 1,
/// règle 18) : mes villes, puis un champ pour en ajouter une nouvelle.
/// Supprimer un raccourci ne supprime jamais l'historique associé
/// (règle 19) — ce widget ne fait qu'appeler [onRetirer], la garantie
/// vient du service.
class TablSheetVilles extends StatefulWidget {
  const TablSheetVilles({
    super.key,
    required this.mesVilles,
    required this.onAjouter,
    required this.onRetirer,
  });

  final List<String> mesVilles;
  final ValueChanged<String> onAjouter;
  final ValueChanged<String> onRetirer;

  @override
  State<TablSheetVilles> createState() => _TablSheetVillesState();
}

class _TablSheetVillesState extends State<TablSheetVilles> {
  final _controleur = TextEditingController();

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _ajouter() {
    final v = _controleur.text.trim();
    if (v.isEmpty) return;
    widget.onAjouter(v);
    _controleur.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceM),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes villes', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
          for (final ville in widget.mesVilles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ville, style: TablTokens.corps),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: TablTokens.texteDoux),
                onPressed: () => widget.onRetirer(ville),
              ),
            ),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controleur,
                  style: TablTokens.corps,
                  decoration: const InputDecoration(hintText: 'Ajouter une ville'),
                  onSubmitted: (_) => _ajouter(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add, color: TablTokens.primaire),
                onPressed: _ajouter,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
