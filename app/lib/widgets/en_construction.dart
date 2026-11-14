import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Une page pas encore prête : son titre et un mot d'explication, au
/// centre de l'écran.
///
/// Composant pur : les textes arrivent prêts à l'affichage.
class TablEnConstruction extends StatelessWidget {
  const TablEnConstruction({
    super.key,
    required this.titre,
    required this.message,
  });

  /// « Vos Tables ».
  final String titre;

  /// « Cette page est en construction… ».
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Center(
          child: Padding(
            // Un peu plus haut que le centre : la barre de navigation
            // flotte en bas.
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceXl,
              0,
              TablTokens.espaceXl,
              TablTokens.espaceXxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.primaire.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.construction_rounded,
                    color: c.primaire,
                    size: 34,
                  ),
                ),
                const SizedBox(height: TablTokens.espaceL),
                Text(titre, style: c.titre, textAlign: TextAlign.center),
                const SizedBox(height: TablTokens.espaceS),
                Text(
                  message,
                  style: c.corps.copyWith(color: c.texteDoux),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
