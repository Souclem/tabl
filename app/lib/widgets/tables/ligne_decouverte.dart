import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une adresse "À découvrir" (megaprompt Bloc 3, règles 38, 78). CTA
/// principal toujours "Garder" — jamais "On y va ?" ici (règle 37, 102).
class TablLigneDecouverte extends StatelessWidget {
  const TablLigneDecouverte({
    super.key,
    required this.restaurantNom,
    required this.sousTitreLieu,
    required this.connaisseursTexte,
    required this.dejaGarde,
    required this.onBasculerGarder,
    required this.onVoirSurLaCarte,
    this.emotions = const [],
  });

  final String restaurantNom;
  final String sousTitreLieu;
  final String connaisseursTexte;
  final List<String> emotions;
  final bool dejaGarde;
  final ValueChanged<bool> onBasculerGarder;
  final VoidCallback onVoirSurLaCarte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(restaurantNom, style: TablTokens.corps),
                    Text(
                      sousTitreLieu,
                      style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                    ),
                  ],
                ),
              ),
              if (emotions.isNotEmpty) Text(emotions.join(' ')),
            ],
          ),
          const SizedBox(height: 2),
          Text(connaisseursTexte, style: TablTokens.legende),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => onBasculerGarder(!dejaGarde),
                style: OutlinedButton.styleFrom(
                  backgroundColor: dejaGarde ? TablTokens.primaire : null,
                  foregroundColor:
                      dejaGarde ? TablTokens.texteSurPrimaire : TablTokens.texte,
                ),
                child: Text(dejaGarde ? 'Gardé ✓' : 'Garder'),
              ),
              const SizedBox(width: TablTokens.espaceS),
              TextButton(
                onPressed: onVoirSurLaCarte,
                child: const Text('Voir sur la carte'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
