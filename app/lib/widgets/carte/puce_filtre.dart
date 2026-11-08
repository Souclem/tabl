import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une pastille de la rangée de filtres de la carte. [avecChoix] ajoute
/// une petite flèche : la pastille ouvre un choix (une personne, une
/// Table...) au lieu de simplement s'activer.
class TablPuceFiltre extends StatelessWidget {
  const TablPuceFiltre({
    super.key,
    required this.libelle,
    required this.actif,
    required this.onPresse,
    this.avecChoix = false,
  });

  final String libelle;
  final bool actif;
  final bool avecChoix;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final couleur = actif ? c.texteSurPrimaire : c.texte;
    return Material(
      color: actif ? c.primaire : c.surface,
      shape: StadiumBorder(
        side: BorderSide(color: actif ? c.primaire : c.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPresse,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 7, avecChoix ? 8 : 14, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                libelle,
                style: c.legende.copyWith(
                  color: couleur,
                  fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (avecChoix)
                Icon(Icons.expand_more_rounded, size: 16, color: couleur),
            ],
          ),
        ),
      ),
    );
  }
}
