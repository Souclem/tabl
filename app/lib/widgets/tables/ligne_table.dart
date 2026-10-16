import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'couverture_table.dart';

/// Une row de "Vos Tables" (megaprompt Bloc 3, règles 6-9, 74) : visuel
/// compact, nom, nombre de membres, UNE seule information utile — jamais
/// un empilement de compteurs sur la même ligne.
class TablLigneTable extends StatelessWidget {
  const TablLigneTable({
    super.key,
    required this.nom,
    required this.nombreMembres,
    required this.etatTexte,
    required this.actionRequise,
    required this.onTap,
    this.emoji,
    this.visuelUrls = const [],
  });

  final String nom;
  final String? emoji;
  final List<String> visuelUrls;
  final int nombreMembres;
  final String etatTexte;
  final bool actionRequise;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sousTitre = nombreMembres == 1
        ? '1 personne'
        : '$nombreMembres personnes';
    return Semantics(
      label: '$nom, Table de $nombreMembres personnes, $etatTexte.',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: TablCouvertureTable(urls: visuelUrls, arrondi: TablTokens.espaceS),
              ),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emoji == null ? nom : '$nom $emoji',
                      style: TablTokens.sousTitre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(sousTitre, style: TablTokens.legende.copyWith(color: TablTokens.texteDoux)),
                    Text(
                      etatTexte,
                      style: TablTokens.legende.copyWith(
                        color: actionRequise ? TablTokens.primaire : TablTokens.texteDoux,
                        fontWeight: actionRequise ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
