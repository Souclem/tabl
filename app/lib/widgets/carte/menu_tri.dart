import 'package:flutter/material.dart';

import '../../theme/apparence.dart';
import '../../theme/tokens.dart';

/// « Trié par Récents ⌄ » : un toucher ouvre un petit menu sur papier
/// clair, chaque tri avec ce qu'il fait ; le choisi porte une coche.
///
/// Composant pur : les tris arrivent prêts à afficher, le choix repart
/// par [onChoisir].
class TablMenuTri extends StatelessWidget {
  const TablMenuTri({
    super.key,
    required this.options,
    required this.choisi,
    required this.onChoisir,
  });

  final List<({String libelle, String description})> options;
  final int choisi;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    final c = TablCouleurs.of(context);
    return PopupMenuButton<int>(
      tooltip: 'Changer le tri',
      onSelected: onChoisir,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: c.surface,
      elevation: 12,
      shadowColor: c.texte.withValues(alpha: 0.4),
      constraints: const BoxConstraints(minWidth: 272, maxWidth: 272),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      menuPadding: const EdgeInsets.all(6),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          PopupMenuItem<int>(
            value: i,
            padding: EdgeInsets.zero,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: i == choisi ? c.fond : null,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          options[i].libelle,
                          style: TablTokens.corps.copyWith(
                            fontSize: 15.5,
                            fontWeight: i == choisi
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: c.texte,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          options[i].description,
                          style: TablTokens.legende.copyWith(
                            fontSize: 12.5,
                            color: c.texteDoux,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i == choisi)
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: c.primaireFoncee,
                    ),
                ],
              ),
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Trié par ',
              style: TablTokens.legende.copyWith(
                fontSize: 14,
                color: palette.texteDoux,
              ),
            ),
            Text(
              options[choisi].libelle,
              style: TablTokens.corps.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: palette.texte,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: palette.texteDoux,
            ),
          ],
        ),
      ),
    );
  }
}
