import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'logo.dart';

/// Une étape du parcours de présentation.
///
/// Composant pur : le titre, le texte et l'icône arrivent déjà prêts à
/// l'affichage par le constructeur, et `onPasser` est la seule action
/// exposée. Le composant ne sait pas ce que "passer" signifie ni quelle
/// est la prochaine étape — c'est à l'appelant (`app/`) de le décider.
///
/// `onPasser` est optionnel : sans lui, aucun bouton ne s'affiche en bas
/// de l'étape (utile pour les étapes intermédiaires, qui se traversent
/// uniquement par swipe).
class EtapeOnboarding extends StatelessWidget {
  const EtapeOnboarding({
    super.key,
    required this.titre,
    required this.texte,
    required this.icone,
    this.onPasser,
    this.libellePasser = 'Passer',
  });

  final String titre;
  final String texte;
  final IconData icone;
  final VoidCallback? onPasser;
  final String libellePasser;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TablTokens.espaceL,
        vertical: TablTokens.espaceXl,
      ),
      child: Column(
        children: [
          const Align(alignment: Alignment.centerLeft, child: TablLogo()),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 160,
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icone, size: 72, color: c.primaire),
                ),
                const SizedBox(height: TablTokens.espaceXl),
                Text(titre, textAlign: TextAlign.center, style: c.grandTitre),
                const SizedBox(height: TablTokens.espaceM),
                Text(
                  texte,
                  textAlign: TextAlign.center,
                  style: c.corps.copyWith(color: c.texteDoux),
                ),
              ],
            ),
          ),
          if (onPasser != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onPasser,
                style: TextButton.styleFrom(
                  foregroundColor: c.texteDoux,
                  textStyle: TablTokens.libelleBouton,
                ),
                child: Text(libellePasser),
              ),
            )
          else
            const SizedBox(height: TablTokens.hauteurControle),
        ],
      ),
    );
  }
}
