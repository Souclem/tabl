import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le signal Instants sur un post existant — "3 nouveaux Instants" ou
/// "3 Instants" si déjà vus (megaprompt Bloc 2, règle 7-8). Jamais un
/// nouveau post, jamais une carte séparée : une simple ligne cliquable
/// intégrée à la publication.
///
/// Composant pur : reçoit déjà les deux nombres, ne calcule rien.
class TablSignalInstants extends StatelessWidget {
  const TablSignalInstants({
    super.key,
    required this.total,
    required this.nonVus,
    required this.onPresse,
  });

  final int total;
  final int nonVus;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final libelle = nonVus > 0
        ? (nonVus > 1 ? '$nonVus nouveaux Instants' : '$nonVus nouvel Instant')
        : '$total Instant${total > 1 ? 's' : ''}';

    return GestureDetector(
      onTap: onPresse,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.play_circle_outline_rounded,
              size: 15,
              color: nonVus > 0
                  ? TablTokens.primaire
                  : TablTokens.texteDoux,
            ),
            const SizedBox(width: 6),
            Text(
              libelle,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: nonVus > 0 ? FontWeight.w600 : FontWeight.w500,
                color: nonVus > 0
                    ? TablTokens.primaire
                    : TablTokens.texteDoux,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
