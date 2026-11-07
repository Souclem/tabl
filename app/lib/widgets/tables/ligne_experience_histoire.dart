import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une expérience dans "Notre histoire" (megaprompt Bloc 3, règle 22) :
/// photo, restaurant, date, auteur, émotion si utile — rien de plus.
class TablLigneExperienceHistoire extends StatelessWidget {
  const TablLigneExperienceHistoire({
    super.key,
    required this.restaurantNom,
    required this.ville,
    required this.dateLisible,
    required this.auteurPseudo,
    this.photoUrl,
    this.emoji,
  });

  final String? photoUrl;
  final String restaurantNom;
  final String ville;
  final String dateLisible;
  final String auteurPseudo;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(TablTokens.espaceS),
            child: SizedBox(
              width: 56,
              height: 56,
              child: photoUrl == null
                  ? Container(color: c.surface)
                  : Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          Container(color: c.surface),
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
                    Expanded(
                      child: Text(
                        restaurantNom,
                        style: c.corps,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (emoji != null) Text(emoji!, style: c.corps),
                  ],
                ),
                Text(
                  '$ville · $dateLisible · $auteurPseudo',
                  style: c.legende.copyWith(color: c.texteDoux),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
