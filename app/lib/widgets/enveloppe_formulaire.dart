import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'bouton_retour.dart';
import 'logo.dart';

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
    this.onRetour,
  });

  final String titre;
  final String sousTitre;
  final List<Widget> children;

  /// Si fourni, affiche un bouton retour circulaire en haut de l'écran —
  /// pour revenir à l'écran qui a ouvert ce formulaire, sans dépendre du
  /// bouton retour natif ni de la pile de navigation.
  final VoidCallback? onRetour;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
                      const Center(child: TablLogo()),
                      const SizedBox(height: TablTokens.espaceXl),
                      Text(titre, style: c.grandTitre),
                      const SizedBox(height: TablTokens.espaceS),
                      Text(
                        sousTitre,
                        style: c.corps.copyWith(color: c.texteDoux),
                      ),
                      const SizedBox(height: TablTokens.espaceXl),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
            if (onRetour != null)
              Positioned(
                top: TablTokens.espaceS,
                left: TablTokens.espaceM,
                child: TablBoutonRetour(onPresse: onRetour!),
              ),
          ],
        ),
      ),
    );
  }
}
