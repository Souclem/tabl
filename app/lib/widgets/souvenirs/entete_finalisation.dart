import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le haut de ce qu'on dit d'un moment à la finalisation, posé sur la
/// photo : le lieu (touchez pour le confirmer ou le changer), la date et
/// la légende. Le texte arrive déjà prêt à l'affichage.
class TablEnteteFinalisation extends StatelessWidget {
  const TablEnteteFinalisation({
    super.key,
    required this.lieu,
    required this.indicationLieu,
    required this.aConfirmer,
    required this.dateLisible,
    required this.legende,
    required this.indicationLegende,
    required this.onPresseLieu,
    required this.onPresseLegende,
  });

  /// `null` : pas de lieu, l'[indicationLieu] prend sa place.
  final String? lieu;
  final String indicationLieu;

  /// Le lieu est une proposition, pas encore un choix.
  final bool aConfirmer;
  final String dateLisible;

  /// Entre « », `null` : rien n'est encore écrit.
  final String? legende;
  final String indicationLegende;
  final VoidCallback onPresseLieu;
  final VoidCallback onPresseLegende;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    const ombre = [Shadow(blurRadius: 12, color: Color(0x99000000))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPresseLieu,
          behavior: HitTestBehavior.opaque,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: TablTokens.espaceS,
            children: [
              Text(
                lieu ?? indicationLieu,
                style: c.titreAffichage.copyWith(
                  fontSize: 30,
                  height: 1.1,
                  shadows: ombre,
                  color: lieu == null ? c.primaire : c.texte,
                ),
              ),
              if (aConfirmer)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TablTokens.espaceS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      TablTokens.arrondiBouton,
                    ),
                    border: Border.all(color: c.primaire),
                  ),
                  child: Text(
                    'à confirmer',
                    style: c.legende.copyWith(fontSize: 12, color: c.primaire),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: TablTokens.espaceXs),
        Text(
          dateLisible,
          style: c.legende.copyWith(
            color: c.texte.withValues(alpha: 0.85),
            shadows: ombre,
          ),
        ),
        const SizedBox(height: TablTokens.espaceS),
        GestureDetector(
          onTap: onPresseLegende,
          behavior: HitTestBehavior.opaque,
          child: Text(
            legende ?? indicationLegende,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: c.corps.copyWith(
              fontStyle: FontStyle.italic,
              shadows: ombre,
              color: legende == null ? c.texte.withValues(alpha: 0.6) : c.texte,
            ),
          ),
        ),
      ],
    );
  }
}
