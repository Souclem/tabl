import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bouton d'action principal : plein, couleur d'accent.
///
/// Passer `onPresse: null` le désactive. Passer `enCours: true` affiche
/// un indicateur de chargement et empêche les appuis multiples.
class TablBouton extends StatelessWidget {
  const TablBouton({
    super.key,
    required this.libelle,
    this.onPresse,
    this.enCours = false,
  });

  final String libelle;
  final VoidCallback? onPresse;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    final actif = onPresse != null && !enCours;

    return SizedBox(
      width: double.infinity,
      height: TablTokens.hauteurControle,
      child: FilledButton(
        onPressed: actif ? onPresse : null,
        style: FilledButton.styleFrom(
          backgroundColor: TablTokens.primaire,
          foregroundColor: TablTokens.texteSurPrimaire,
          disabledBackgroundColor: TablTokens.primaire.withValues(alpha: 0.4),
          disabledForegroundColor: TablTokens.texteSurPrimaire,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TablTokens.arrondiS),
          ),
          textStyle: TablTokens.libelleBouton,
        ),
        child: enCours
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: TablTokens.texteSurPrimaire,
                ),
              )
            : Text(libelle),
      ),
    );
  }
}

/// Bouton discret, sans fond : liens de bas de page, actions secondaires.
class TablBoutonTexte extends StatelessWidget {
  const TablBoutonTexte({
    super.key,
    required this.libelle,
    this.onPresse,
  });

  final String libelle;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPresse,
      style: TextButton.styleFrom(
        foregroundColor: TablTokens.primaire,
        textStyle: TablTokens.libelleBouton,
        padding: const EdgeInsets.symmetric(
          horizontal: TablTokens.espaceS,
          vertical: TablTokens.espaceXs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(libelle),
    );
  }
}
