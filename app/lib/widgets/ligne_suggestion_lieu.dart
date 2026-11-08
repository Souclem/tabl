import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Une suggestion de restaurant pendant la recherche : le nom, et en
/// dessous ce qui aide à reconnaître le bon (type, adresse, distance),
/// déjà composé par l'appelant.
class TablLigneSuggestionLieu extends StatelessWidget {
  const TablLigneSuggestionLieu({
    super.key,
    required this.nom,
    required this.description,
    required this.onSelection,
  });

  final String nom;
  final String description;
  final VoidCallback onSelection;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return InkWell(
      onTap: onSelection,
      borderRadius: BorderRadius.circular(TablTokens.arrondiM),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: TablTokens.espaceS + 2,
          horizontal: TablTokens.espaceXs,
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined, size: 20, color: c.primaire),
            const SizedBox(width: TablTokens.espaceM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    style: c.corps.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.legende,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
