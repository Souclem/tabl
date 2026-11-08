import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Une publication en version compacte : la photo du plat en petit à
/// gauche, et à droite un titre, la date, l'émotion et le début de la
/// légende. Le titre dépend de la page : l'auteur (avec son avatar) sur
/// celle d'un restaurant, le restaurant sur un profil. Un tap ouvre la
/// publication en entier.
class TablLigneAvis extends StatelessWidget {
  const TablLigneAvis({
    super.key,
    required this.titre,
    required this.dateLisible,
    required this.onPresse,
    this.avatarPseudo,
    this.avatarPhotoUrl,
    this.photoUrl,
    this.emoji,
    this.legende,
    this.resumeReactions,
  });

  final String titre;

  /// Avatar devant le titre (l'auteur) ; aucun si `null`.
  final String? avatarPseudo;
  final String? avatarPhotoUrl;

  /// "12 mars".
  final String dateLisible;
  final String? photoUrl;
  final String? emoji;
  final String? legende;

  /// "Emma et 3 autres ont aimé" — déjà composé.
  final String? resumeReactions;
  final VoidCallback onPresse;

  // Géométrie de la vignette, publique pour qu'elle puisse s'animer
  // jusqu'à la photo de la publication complète.
  static const cotePhoto = 84.0;
  static const margeGauche = TablTokens.espaceL;
  static const margeHaut = TablTokens.espaceS + 2;
  static const arrondiPhoto = TablTokens.arrondiM;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: margeGauche,
          vertical: margeHaut,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(arrondiPhoto),
              child: SizedBox(
                width: cotePhoto,
                height: cotePhoto,
                child: photoUrl == null
                    ? ColoredBox(color: c.surface)
                    : Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        // Petite vignette : inutile de décoder la photo en
                        // pleine résolution.
                        cacheWidth: (cotePhoto * 3).round(),
                        errorBuilder: (_, _, _) => ColoredBox(color: c.surface),
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
                      if (avatarPseudo != null) ...[
                        TablAvatar(
                          pseudo: avatarPseudo!,
                          photoUrl: avatarPhotoUrl,
                          rayon: 10,
                        ),
                        const SizedBox(width: TablTokens.espaceS),
                      ],
                      Expanded(
                        child: Text(
                          titre,
                          overflow: TextOverflow.ellipsis,
                          style: c.corps.copyWith(
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
                        style: c.legende.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                  if (legende != null) ...[
                    const SizedBox(height: TablTokens.espaceXs),
                    Text(
                      legende!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: c.corps.copyWith(fontSize: 14),
                    ),
                  ],
                  if (resumeReactions != null) ...[
                    const SizedBox(height: TablTokens.espaceXs),
                    Text(
                      resumeReactions!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.legende.copyWith(fontSize: 11),
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
