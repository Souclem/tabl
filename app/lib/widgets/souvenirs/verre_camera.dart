import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

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
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.fond.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(arrondi),
            border: Border.all(color: c.texte.withValues(alpha: 0.12)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
