import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le flou du verre de création (prototype « Création V5 ») : flou de 20,
/// puis couleurs saturées à 1,5 pour que la photo dessous reste vivante.
final flouVerre = ImageFilter.compose(
  outer: const ColorFilter.matrix([
    1.3937, -0.3576, -0.0361, 0, 0, //
    -0.1063, 1.1424, -0.0361, 0, 0, //
    -0.1063, -0.3576, 1.4639, 0, 0, //
    0, 0, 0, 1, 0,
  ]),
  inner: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
);

/// La teinte nuit posée sur le flou : assez légère pour voir la photo.
const teinteVerre = 0.36;

/// Une surface de verre dépoli posée sur le viseur : lisible quelle que
/// soit l'image dessous. L'écran caméra est toujours sombre, dans les deux
/// apparences.
class VerreCamera extends StatelessWidget {
  const VerreCamera({
    super.key,
    required this.child,
    this.arrondi = 16,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double arrondi;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return ClipRRect(
      borderRadius: BorderRadius.circular(arrondi),
      child: BackdropFilter(
        filter: flouVerre,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.fond.withValues(alpha: teinteVerre),
            borderRadius: BorderRadius.circular(arrondi),
            border: Border.all(color: c.texte.withValues(alpha: 0.12)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
