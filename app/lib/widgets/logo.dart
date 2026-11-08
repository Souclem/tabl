import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Le wordmark "tabl.", affiché en haut des écrans d'authentification et
/// de présentation.
///
/// Reproduit le logo officiel tel quel (voir
/// `instruction/Clément (2)/scraps/image-1-1.png`) : "tabl" en ivoire,
/// seul le point final en champagne — jamais le mot entier en couleur
/// d'accent, jamais redessiné autrement.
///
/// `grand` l'agrandit pour un usage en pièce maîtresse (écran d'accueil),
/// au lieu du petit en-tête habituel des formulaires.
class TablLogo extends StatelessWidget {
  const TablLogo({super.key, this.grand = false});

  final bool grand;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final style = grand
        ? c.logo.copyWith(fontSize: 48, letterSpacing: 0.5, color: c.texte)
        : c.logo.copyWith(color: c.texte);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'tabl'),
          TextSpan(
            text: '.',
            style: TextStyle(color: c.primaire),
          ),
        ],
      ),
    );
  }
}
