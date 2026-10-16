import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// La position de l'utilisateur — impossible à confondre avec un
/// restaurant ou une sélection : centre clair + anneau de précision +
/// halo si la précision GPS est faible (megaprompt Bloc 1, règle 29).
/// [capDegres] `null` signifie qu'aucune direction n'est affichée,
/// jamais inventée (règle 30).
class TablMarqueurPositionUtilisateur extends StatelessWidget {
  const TablMarqueurPositionUtilisateur({
    super.key,
    required this.precisionFaible,
    this.capDegres,
  });

  final bool precisionFaible;
  final double? capDegres;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Votre position.',
      child: SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (precisionFaible)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blueAccent.withValues(alpha: 0.12),
                ),
              ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: TablTokens.fond, width: 2),
                color: Colors.blueAccent,
              ),
            ),
            if (capDegres != null)
              Transform.rotate(
                angle: capDegres! * math.pi / 180,
                child: const Icon(
                  Icons.navigation,
                  size: 14,
                  color: Colors.blueAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
