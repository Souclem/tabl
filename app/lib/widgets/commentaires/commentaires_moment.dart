import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'fil_commentaire.dart';

/// Les commentaires d'un moment, à la suite du moment lui-même, puis le
/// champ pour en ajouter un ([saisie]) : pas d'écran à part, on lit et
/// on répond sans quitter la photo.
///
/// Composant pur : les fils arrivent prêts à afficher.
class TablCommentairesMoment extends StatelessWidget {
  const TablCommentairesMoment({
    super.key,
    required this.titre,
    required this.fils,
    required this.saisie,
  });

  /// "3 commentaires".
  final String titre;

  /// `null` pendant le chargement.
  final List<FilAffiche>? fils;

  /// Voir `TablSaisieCommentaire`.
  final Widget saisie;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final fils = this.fils;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titre, style: c.sousTitre),
        const SizedBox(height: TablTokens.espaceM),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: fils == null
              ? SizedBox(
                  height: 48,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.primaire,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (final f in fils) TablFilCommentaire(fil: f)],
                ),
        ),
        const SizedBox(height: TablTokens.espaceS),
        saisie,
      ],
    );
  }
}
