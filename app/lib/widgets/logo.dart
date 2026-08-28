import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Le wordmark "tabl.", affiché en haut des écrans d'authentification et
/// de présentation.
///
/// `grand` l'agrandit pour un usage en pièce maîtresse (écran d'accueil),
/// au lieu du petit en-tête habituel des formulaires.
class TablLogo extends StatelessWidget {
  const TablLogo({super.key, this.grand = false});

  final bool grand;

  @override
  Widget build(BuildContext context) {
    return Text(
      'tabl.',
      style: grand
          ? TablTokens.logo.copyWith(fontSize: 48, letterSpacing: 0.5)
          : TablTokens.logo,
    );
  }
}
