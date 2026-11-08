import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// En-tête du viewer plein écran (megaprompt Bloc 2, règle 15, 92) :
/// auteur à gauche, position "1 / 3" et fermeture à droite. Un gradient
/// noir très discret en fond, jamais un bandeau opaque.
class TablEnteteViewerInstant extends StatelessWidget {
  const TablEnteteViewerInstant({
    super.key,
    required this.auteurPseudo,
    required this.sousLigne,
    required this.position,
    required this.total,
    required this.onFermer,
  });

  final String auteurPseudo;

  /// "Septime · maintenant".
  final String sousLigne;

  /// Index 1-based de l'Instant courant.
  final int position;
  final int total;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x99000000), Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceM,
            TablTokens.espaceS,
            TablTokens.espaceM,
            TablTokens.espaceM,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      auteurPseudo,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sousLigne,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (total > 1)
                Padding(
                  padding: const EdgeInsets.only(right: TablTokens.espaceS),
                  child: Text(
                    '$position / $total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Semantics(
                label: 'Fermer',
                child: GestureDetector(
                  onTap: onFermer,
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(TablTokens.espaceXs),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
