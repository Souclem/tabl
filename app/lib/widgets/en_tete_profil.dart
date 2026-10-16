import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Haut d'un profil, le sien comme celui d'un autre : avatar, pseudo, une
/// ligne secondaire facultative (l'e-mail sur le sien), le nombre de
/// moments, et une action facultative dessous ("Suivre"…).
class TablEnTeteProfil extends StatelessWidget {
  const TablEnTeteProfil({
    super.key,
    required this.pseudo,
    this.photoUrl,
    this.sousTitre,
    this.resumeMoments,
    this.action,
  });

  final String pseudo;
  final String? photoUrl;
  final String? sousTitre;

  /// "12 moments" — `null` tant que la liste n'est pas chargée, ou
  /// quand elle n'est pas visible.
  final String? resumeMoments;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        TablTokens.espaceXxl,
        TablTokens.espaceL,
        TablTokens.espaceXl,
      ),
      child: Column(
        children: [
          TablAvatar(pseudo: pseudo, photoUrl: photoUrl, rayon: 45),
          const SizedBox(height: TablTokens.espaceM),
          Text(pseudo, textAlign: TextAlign.center, style: TablTokens.titre),
          if (sousTitre != null) ...[
            const SizedBox(height: TablTokens.espaceXs),
            Text(
              sousTitre!,
              textAlign: TextAlign.center,
              style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
            ),
          ],
          if (resumeMoments != null) ...[
            const SizedBox(height: TablTokens.espaceM),
            Text(resumeMoments!, style: TablTokens.legende),
          ],
          if (action != null) ...[
            const SizedBox(height: TablTokens.espaceM),
            action!,
          ],
        ],
      ),
    );
  }
}
