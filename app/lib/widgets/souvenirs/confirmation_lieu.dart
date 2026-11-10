import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';

/// « Étiez-vous chez Le Comptoir ? » : le lieu proposé d'après les photos,
/// à confirmer d'un « Oui » ou à changer. Le texte arrive prêt à
/// l'affichage.
class TablConfirmationLieu extends StatelessWidget {
  const TablConfirmationLieu({
    super.key,
    required this.question,
    required this.libelleOui,
    required this.libelleNon,
    required this.onOui,
    required this.onNon,
    this.detail,
  });

  final String question;

  /// Sous la question (« Végétarien · Liège · à 40 m de la photo »).
  final String? detail;
  final String libelleOui;
  final String libelleNon;
  final VoidCallback onOui;
  final VoidCallback onNon;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.all(TablTokens.espaceM),
      decoration: BoxDecoration(
        color: c.fond,
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        border: Border.all(color: c.primaire.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: c.titreAffichage.copyWith(fontSize: 22)),
          if (detail != null) ...[
            const SizedBox(height: TablTokens.espaceXs),
            Text(detail!, style: c.legende),
          ],
          const SizedBox(height: TablTokens.espaceM),
          Row(
            children: [
              Expanded(
                child: TablPetitBouton(
                  libelle: libelleOui,
                  plein: true,
                  onPresse: onOui,
                ),
              ),
              const SizedBox(width: TablTokens.espaceS),
              Expanded(
                child: TablPetitBouton(libelle: libelleNon, onPresse: onNon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
