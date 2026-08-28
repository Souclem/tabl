import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bouton retour rond et discret : un contour, une flèche, rien de plus.
///
/// Prévu pour être posé en haut à gauche d'un écran (via `Positioned` ou
/// `Align`) ; ne se positionne pas lui-même.
class TablBoutonRetour extends StatelessWidget {
  const TablBoutonRetour({super.key, required this.onPresse});

  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Material(
      // Fond opaque, pas transparent : ce bouton flotte au-dessus d'un
      // contenu qui peut défiler dessous (formulaire) — un fond transparent
      // laisserait voir ce contenu à travers, façon collision visuelle.
      color: TablTokens.fond,
      shape: const CircleBorder(side: BorderSide(color: TablTokens.bordure)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPresse,
        icon: const Icon(Icons.arrow_back_rounded, size: 20),
        color: TablTokens.texte,
        splashRadius: 22,
      ),
    );
  }
}
