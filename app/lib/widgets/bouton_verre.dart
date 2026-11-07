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
                color: TablTokens.fond.withValues(alpha: 0.45),
                shape: CircleBorder(
                  side: BorderSide(
                    color: TablTokens.texte.withValues(alpha: 0.14),
                  ),
                ),
                child: IconButton(
                  onPressed: onPresse,
                  tooltip: libelle,
                  icon: Icon(
                    icone,
                    size: 20,
                    color: doree ? TablTokens.primaire : TablTokens.texte,
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
                  color: TablTokens.primaire,
                  shape: BoxShape.circle,
                  border: Border.all(color: TablTokens.fond, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
