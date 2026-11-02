import 'package:flutter/material.dart';

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
    return PopupMenuButton<int>(
      tooltip: 'Changer le tri',
      onSelected: onChoisir,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      color: TablTokens.papier,
      elevation: 12,
      shadowColor: TablTokens.encre.withValues(alpha: 0.4),
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
                color: i == choisi ? TablTokens.lin : null,
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
                            color: TablTokens.encre,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          options[i].description,
                          style: TablTokens.legende.copyWith(
                            fontSize: 12.5,
                            color: TablTokens.encrePale,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i == choisi)
                    const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: TablTokens.primaireFoncee,
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
            Text('Trié par ', style: TablTokens.legende.copyWith(fontSize: 14)),
            Text(
              options[choisi].libelle,
              style: TablTokens.corps.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: TablTokens.texteDoux,
            ),
          ],
        ),
      ),
    );
  }
}
