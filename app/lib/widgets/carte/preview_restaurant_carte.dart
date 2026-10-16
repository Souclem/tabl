import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// La preview qui monte au tap sur un restaurant — jamais une carte
/// permanente, jamais de données techniques (megaprompt Bloc 1, règles
/// 40, 43, 66). Langage humain uniquement (règle 45) : tout ce qui est
/// affiché ici arrive déjà composé par `CarteService`, ce widget ne
/// calcule rien.
class TablPreviewRestaurantCarte extends StatelessWidget {
  const TablPreviewRestaurantCarte({
    super.key,
    required this.nom,
    required this.sousTitreLieu,
    required this.procheDirectResume,
    required this.recurrenceResume,
    required this.emotionsRepresentatives,
    required this.reseauEtenduResume,
    required this.dejaVisiteParMoi,
    required this.dejaGardeParMoi,
    required this.onBasculerGarder,
    required this.onVoir,
    required this.onFermer,
  });

  final String nom;
  final String sousTitreLieu;

  /// Vide si aucune donnée sociale pertinente.
  final String procheDirectResume;

  /// "★ 2 y sont retournés", ou vide.
  final String recurrenceResume;
  final List<String> emotionsRepresentatives;

  /// "+7 personnes dans votre réseau étendu", ou vide si non applicable.
  final String reseauEtenduResume;

  final bool dejaVisiteParMoi;
  final bool dejaGardeParMoi;
  final ValueChanged<bool> onBasculerGarder;
  final VoidCallback onVoir;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TablTokens.espaceM),
      decoration: BoxDecoration(
        color: TablTokens.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(TablTokens.arrondiL),
        ),
        border: Border.all(color: TablTokens.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Placeholder élégant Tabl. tant qu'aucune photo réelle
              // n'est disponible — jamais "Photo" ni "Upload" (règle 44).
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: TablTokens.fond,
                  borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                  border: Border.all(color: TablTokens.bordure),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.restaurant,
                  size: 22,
                  color: TablTokens.texteDoux,
                ),
              ),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: TablTokens.titreAffichage.copyWith(fontSize: 18)),
                    Text(sousTitreLieu, style: TablTokens.legende),
                  ],
                ),
              ),
              IconButton(
                onPressed: onFermer,
                icon: const Icon(Icons.close, color: TablTokens.texteDoux),
              ),
            ],
          ),
          if (procheDirectResume.isNotEmpty || dejaVisiteParMoi) ...[
            const SizedBox(height: TablTokens.espaceS),
            Text(
              dejaVisiteParMoi ? 'Vous y êtes déjà allé.' : procheDirectResume,
              style: TablTokens.corps,
            ),
          ],
          if (recurrenceResume.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TablTokens.espaceXs),
              child: Text(
                recurrenceResume,
                style: TablTokens.legende.copyWith(color: TablTokens.primaire),
              ),
            ),
          if (reseauEtenduResume.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TablTokens.espaceXs),
              child: Text(reseauEtenduResume, style: TablTokens.legende),
            ),
          if (emotionsRepresentatives.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: TablTokens.espaceS),
              child: Text(
                emotionsRepresentatives.join(' '),
                style: const TextStyle(fontSize: 20),
              ),
            ),
          const SizedBox(height: TablTokens.espaceM),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onBasculerGarder(!dejaGardeParMoi),
                  child: Text(dejaGardeParMoi ? 'Gardé ✓' : 'Garder'),
                ),
              ),
              const SizedBox(width: TablTokens.espaceS),
              Expanded(
                child: FilledButton(onPressed: onVoir, child: const Text('Voir')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
