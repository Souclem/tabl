import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bouton rond en verre dépoli, posé sur une photo (haut d'un profil,
/// moment agrandi) : il reste lisible quelle que soit l'image dessous.
class TablBoutonVerre extends StatelessWidget {
  const TablBoutonVerre({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onPresse,
    this.pastille = false,
    this.doree = false,
  });

  final IconData icone;

  /// Lu par les lecteurs d'écran et affiché en info-bulle.
  final String libelle;
  final VoidCallback onPresse;

  /// Petit point doré : quelque chose attend derrière ce bouton.
  final bool pastille;

  /// Icône dorée : le geste est déjà fait (marque-page gardé).
  final bool doree;

  @override
  Widget build(BuildContext context) {
    // Posé sur une photo : le verre reste sombre (icône claire) dans les
    // deux apparences, seul l'accent de la pastille suit le thème.
    const verre = TablCouleurs.sombre;
    final c = TablCouleurs.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: verre.fond.withValues(alpha: 0.45),
                shape: CircleBorder(
                  side: BorderSide(color: verre.texte.withValues(alpha: 0.14)),
                ),
                child: IconButton(
                  onPressed: onPresse,
                  tooltip: libelle,
                  icon: Icon(
                    icone,
                    size: 20,
                    color: doree ? c.primaire : verre.texte,
                  ),
                ),
              ),
            ),
          ),
          if (pastille)
            Positioned(
              top: 1,
              right: 1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: c.primaire,
                  shape: BoxShape.circle,
                  border: Border.all(color: verre.fond, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
