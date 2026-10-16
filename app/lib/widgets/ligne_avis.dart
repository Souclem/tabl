import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Un avis en version compacte, sur la page d'un restaurant : la photo du
/// plat en petit à gauche, et à droite qui, quand, l'émotion et le début
/// de la légende. Un tap ouvre la publication en entier.
class TablLigneAvis extends StatelessWidget {
  const TablLigneAvis({
    super.key,
    required this.auteurPseudo,
    required this.dateLisible,
    required this.onPresse,
    this.auteurPhotoUrl,
    this.photoUrl,
    this.emoji,
    this.legende,
    this.resumeReactions,
  });

  final String auteurPseudo;
  final String? auteurPhotoUrl;

  /// "12 mars".
  final String dateLisible;
  final String? photoUrl;
  final String? emoji;
  final String? legende;

  /// "Emma et 3 autres ont aimé" — déjà composé.
  final String? resumeReactions;
  final VoidCallback onPresse;

  static const _cote = 84.0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TablTokens.espaceL,
          vertical: TablTokens.espaceS + 2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              child: SizedBox(
                width: _cote,
                height: _cote,
                child: photoUrl == null
                    ? const ColoredBox(color: TablTokens.surface)
                    : Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        // Petite vignette : inutile de décoder la photo en
                        // pleine résolution.
                        cacheWidth: (_cote * 3).round(),
                        errorBuilder: (_, _, _) =>
                            const ColoredBox(color: TablTokens.surface),
                      ),
              ),
            ),
            const SizedBox(width: TablTokens.espaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TablAvatar(
                        pseudo: auteurPseudo,
                        photoUrl: auteurPhotoUrl,
                        rayon: 10,
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                      Expanded(
                        child: Text(
                          auteurPseudo,
                          overflow: TextOverflow.ellipsis,
                          style: TablTokens.corps.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (emoji != null) ...[
                        Text(emoji!, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: TablTokens.espaceS),
                      ],
                      Text(
                        dateLisible,
                        style: TablTokens.legende.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  if (legende != null) ...[
                    const SizedBox(height: TablTokens.espaceXs),
                    Text(
                      legende!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.corps.copyWith(fontSize: 14),
                    ),
                  ],
                  if (resumeReactions != null) ...[
                    const SizedBox(height: TablTokens.espaceXs),
                    Text(
                      resumeReactions!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.legende.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
