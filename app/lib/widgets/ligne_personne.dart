import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Une personne dans une liste : sa tête, son pseudo, une précision
/// (« Vous suit »), et à droite ce qu'on peut faire avec elle. Toute la
/// ligne ouvre son profil, pas seulement le nom.
///
/// Composant pur : la précision arrive prête à afficher, les boutons sont
/// fournis par l'écran.
class TablLignePersonne extends StatelessWidget {
  const TablLignePersonne({
    super.key,
    required this.pseudo,
    required this.onPresse,
    this.photoUrl,
    this.precision,
    this.actions = const [],
  });

  final String pseudo;
  final String? photoUrl;

  /// Sous le pseudo, en plus discret ; `null` : rien.
  final String? precision;

  /// Ouvre son profil.
  final VoidCallback onPresse;

  /// Des [TablPetitBouton], de gauche à droite.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TablTokens.espaceL - 4,
          vertical: 10,
        ),
        child: Row(
          children: [
            TablAvatar(pseudo: pseudo, photoUrl: photoUrl, rayon: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pseudo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.corps.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (precision != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      precision!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.legende.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            for (final action in actions) ...[const SizedBox(width: 6), action],
          ],
        ),
      ),
    );
  }
}
