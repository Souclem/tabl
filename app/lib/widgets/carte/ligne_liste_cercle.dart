import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une ligne de la vue Liste — même information sociale que la carte,
/// jamais un classement : pas de numéro, pas de score (megaprompt Bloc
/// 1, règles 37-38).
class TablLigneListeCercle extends StatelessWidget {
  const TablLigneListeCercle({
    super.key,
    required this.nom,
    required this.sousTitreLieu,
    required this.procheDirectResume,
    required this.recurrenceResume,
    required this.onTap,
  });

  final String nom;
  final String sousTitreLieu;
  final String procheDirectResume;

  /// "★ Ils y retournent", ou vide.
  final String recurrenceResume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: TablTokens.surface,
                borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                border: Border.all(color: TablTokens.bordure),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.restaurant,
                size: 20,
                color: TablTokens.texteDoux,
              ),
            ),
            const SizedBox(width: TablTokens.espaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nom, style: TablTokens.sousTitre),
                  Text(sousTitreLieu, style: TablTokens.legende),
                  if (procheDirectResume.isNotEmpty)
                    Text(procheDirectResume, style: TablTokens.legende),
                  if (recurrenceResume.isNotEmpty)
                    Text(
                      recurrenceResume,
                      style: TablTokens.legende.copyWith(color: TablTokens.primaire),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: TablTokens.texteDoux),
          ],
        ),
      ),
    );
  }
}
