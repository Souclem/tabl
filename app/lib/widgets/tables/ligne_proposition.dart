import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une proposition dans "On y va ?" (megaprompt Bloc 3, règle 26-27, 77).
///
/// GO / Je passe restent visibles seulement pendant que [active] — une
/// fois l'état terminal (annulée, déclinée, expirée...), seul
/// [etatTexte] s'affiche, jamais les boutons de réponse.
class TablLigneProposition extends StatelessWidget {
  const TablLigneProposition({
    super.key,
    required this.restaurantNom,
    required this.ville,
    required this.proposePar,
    required this.etatTexte,
    required this.active,
    required this.nombreGo,
    this.monInteret,
    this.onGo,
    this.onJePasse,
    this.onTap,
  });

  final String restaurantNom;
  final String ville;
  final String proposePar;
  final String etatTexte;
  final bool active;
  final int nombreGo;
  final bool? monInteret;
  final VoidCallback? onGo;
  final VoidCallback? onJePasse;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      label: '$restaurantNom $ville, proposé par $proposePar.',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(restaurantNom, style: c.corps),
              const SizedBox(height: 2),
              Text(
                '$ville · Proposé par $proposePar',
                style: c.legende.copyWith(color: c.texteDoux),
              ),
              const SizedBox(height: TablTokens.espaceS),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombreGo == 0 ? etatTexte : '$etatTexte · $nombreGo GO',
                      style: c.legende,
                    ),
                  ),
                  if (active) ...[
                    _boutonReponse(
                      context,
                      libelle: 'GO',
                      selectionne: monInteret == true,
                      onTap: onGo,
                    ),
                    const SizedBox(width: TablTokens.espaceXs),
                    _boutonReponse(
                      context,
                      libelle: 'Je passe',
                      selectionne: monInteret == false,
                      onTap: onJePasse,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boutonReponse(
    BuildContext context, {
    required String libelle,
    required bool selectionne,
    required VoidCallback? onTap,
  }) {
    final c = TablCouleurs.of(context);
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selectionne ? c.primaire : null,
        foregroundColor: selectionne ? c.texteSurPrimaire : c.texte,
        side: BorderSide(color: selectionne ? c.primaire : c.bordure),
        padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceS),
      ),
      child: Text(libelle),
    );
  }
}
