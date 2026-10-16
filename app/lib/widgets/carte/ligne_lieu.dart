import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Un lieu dans la vue liste de la carte.
class TablLigneLieu extends StatelessWidget {
  const TablLigneLieu({
    super.key,
    required this.nom,
    required this.description,
    required this.resume,
    required this.duReseau,
    required this.onPresse,
    this.estEnvie = false,
    this.distance,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String description;

  /// "Emma et Thomas y sont allés".
  final String resume;

  /// Visité par mon réseau : pastille pleine, résumé en doré.
  final bool duReseau;
  final bool estEnvie;

  /// "1,6 km", si la position est connue.
  final String? distance;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TablTokens.espaceL,
          vertical: TablTokens.espaceM,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: duReseau ? TablTokens.primaire : Colors.transparent,
                  border: Border.all(color: TablTokens.primaire, width: 2),
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
                          nom,
                          style: TablTokens.corps.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (distance != null)
                        Text(distance!, style: TablTokens.legende),
                    ],
                  ),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.legende,
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          resume,
                          style: TablTokens.legende.copyWith(
                            color: duReseau
                                ? TablTokens.primaire
                                : TablTokens.texteDoux,
                          ),
                        ),
                      ),
                      if (estEnvie)
                        const Icon(
                          Icons.bookmark_rounded,
                          size: 16,
                          color: TablTokens.primaire,
                        ),
                    ],
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
