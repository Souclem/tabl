import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'boutons.dart';

/// La paire de boutons Apple + Google, dans l'ordre attendu partout dans
/// l'app (accueil, connexion, inscription). Deux callbacks distincts : les
/// deux fournisseurs déclenchent des flux de connexion différents.
class TablBoutonsAuthTierce extends StatelessWidget {
  const TablBoutonsAuthTierce({
    super.key,
    this.onPresseApple,
    this.onPresseGoogle,
    this.pilule = false,
    this.styleApple = TablBoutonSocialStyle.contour,
    this.styleGoogle = TablBoutonSocialStyle.contour,
  });

  final VoidCallback? onPresseApple;
  final VoidCallback? onPresseGoogle;
  final bool pilule;
  final TablBoutonSocialStyle styleApple;
  final TablBoutonSocialStyle styleGoogle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TablBoutonSocial(
          libelle: 'Continuer avec Apple',
          icone: Icons.apple,
          style: styleApple,
          pilule: pilule,
          onPresse: onPresseApple,
        ),
        const SizedBox(height: TablTokens.espaceM),
        TablBoutonSocial(
          libelle: 'Continuer avec Google',
          icone: Icons.g_mobiledata_rounded,
          style: styleGoogle,
          pilule: pilule,
          onPresse: onPresseGoogle,
        ),
      ],
    );
  }
}
