import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Un message du mini-chat "Organisation" (megaprompt Bloc 4, règle 43,
/// "bulles minimales, pas d'interface Messenger, pas de grosses photos
/// de profil"). Jamais de coche "vu" (règle 46) — ce widget n'a même pas
/// de paramètre pour ça.
class TablBulleMessageOrganisation extends StatelessWidget {
  const TablBulleMessageOrganisation({
    super.key,
    required this.auteurPseudo,
    required this.contenu,
    required this.parMoi,
    this.onSupprimer,
  });

  final String auteurPseudo;
  final String contenu;
  final bool parMoi;

  /// `null` = pas de suppression possible (règle 48 : uniquement son
  /// propre message).
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Align(
      alignment: parMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onSupprimer,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceS,
            vertical: TablTokens.espaceXs,
          ),
          constraints: const BoxConstraints(maxWidth: 260),
          decoration: BoxDecoration(
            color: parMoi ? c.primaire.withValues(alpha: 0.16) : c.surface,
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!parMoi)
                Text(
                  auteurPseudo,
                  style: c.legende.copyWith(color: c.texteDoux),
                ),
              Text(contenu, style: c.corps),
            ],
          ),
        ),
      ),
    );
  }
}
