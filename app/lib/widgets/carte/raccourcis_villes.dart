import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les raccourcis villes — des favoris personnels ("Paris  Liège
/// Marbella  +"), une seule ligne, jamais des pills, jamais deux lignes
/// (megaprompt Bloc 1, règles 15-16). Doivent être présents : une
/// passe précédente du prototype les avait supprimés par erreur.
class TablRaccourcisVilles extends StatelessWidget {
  const TablRaccourcisVilles({
    super.key,
    required this.villes,
    required this.villeActive,
    required this.onSelection,
    required this.onAjouter,
  });

  final List<String> villes;
  final String? villeActive;
  final ValueChanged<String> onSelection;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          for (final ville in villes) _item(ville),
          Semantics(
            label: 'Ajouter une ville',
            button: true,
            child: GestureDetector(
              onTap: onAjouter,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: TablTokens.espaceS),
                child: Icon(Icons.add, size: 18, color: TablTokens.texteDoux),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(String ville) {
    final actif = ville == villeActive;
    return Semantics(
      label: ville,
      button: true,
      selected: actif,
      child: GestureDetector(
        onTap: () => onSelection(ville),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(right: TablTokens.espaceL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ville,
                style: TablTokens.corps.copyWith(
                  fontSize: 14,
                  color: actif ? TablTokens.texte : TablTokens.texteDoux,
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                height: 2,
                width: actif ? 16 : 0,
                color: TablTokens.primaire,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
