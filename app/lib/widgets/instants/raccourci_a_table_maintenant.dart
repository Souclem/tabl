import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// "À table maintenant · 4" — CTA compact, jamais une row de Stories
/// (megaprompt Bloc 2, règle 12). N'apparaît que lorsqu'il apporte une
/// vraie valeur (2+ expériences actives) : c'est à l'écran appelant de
/// décider de l'afficher ou non.
class TablRaccourciATableMaintenant extends StatelessWidget {
  const TablRaccourciATableMaintenant({
    super.key,
    required this.nombre,
    required this.onPresse,
  });

  final int nombre;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        0,
        TablTokens.espaceL,
        TablTokens.espaceS,
      ),
      child: Material(
        color: TablTokens.texte.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
        child: InkWell(
          onTap: onPresse,
          borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceM,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
              border: Border.all(
                color: TablTokens.texte.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.restaurant_rounded,
                  size: 15,
                  color: TablTokens.primaire,
                ),
                const SizedBox(width: 7),
                Text(
                  'À table maintenant · $nombre',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: TablTokens.texte,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
