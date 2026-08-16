import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Mise en page commune aux écrans de connexion et d'inscription.
///
/// Centre le contenu, le limite en largeur pour qu'il ne s'étire pas sur
/// grand écran, et le rend défilable — sinon le clavier qui s'ouvre écrase
/// le formulaire et Flutter affiche une bande jaune et noire.
class EnveloppeFormulaire extends StatelessWidget {
  const EnveloppeFormulaire({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.children,
  });

  final String titre;
  final String sousTitre;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceL,
              vertical: TablTokens.espaceXl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: TablTokens.largeurMaxFormulaire,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(titre, style: TablTokens.grandTitre),
                  const SizedBox(height: TablTokens.espaceS),
                  Text(sousTitre, style: TablTokens.corps.copyWith(
                    color: TablTokens.texteDoux,
                  )),
                  const SizedBox(height: TablTokens.espaceXl),
                  ...children,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
