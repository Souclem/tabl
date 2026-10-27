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
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
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

/// Habillages disponibles pour [TablBoutonSocial].
enum TablBoutonSocialStyle {
  /// Contour neutre, fond transparent — l'habillage historique.
  contour,

  /// Contour et texte dans la couleur d'accent, pour une action de
  /// création de compte mise en avant sans être un bouton plein.
  contourAccent,

  /// Fond clair, texte foncé — pour un bouton posé sur un fond sombre.
  clair,

  /// Fond sombre plein, texte clair.
  sombre,
}

/// Bouton d'authentification tierce (Apple, Google, e-mail...) : icône +
/// libellé, dans l'un des habillages de [TablBoutonSocialStyle].
class TablBoutonSocial extends StatelessWidget {
  const TablBoutonSocial({
    super.key,
    required this.libelle,
    required this.icone,
    this.onPresse,
    this.style = TablBoutonSocialStyle.contour,
    this.pilule = false,
  });

  final String libelle;
  final IconData icone;
  final VoidCallback? onPresse;
  final TablBoutonSocialStyle style;

  /// Coins entièrement arrondis (forme de pilule) plutôt que le rayon
  /// standard des boutons de formulaire.
  final bool pilule;

  @override
  Widget build(BuildContext context) {
    final forme = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        pilule ? TablTokens.hauteurControle / 2 : TablTokens.arrondiS,
      ),
    );
    final icone_ = Icon(icone, size: 20);
    final libelle_ = Text(libelle);

    final bouton = switch (style) {
      TablBoutonSocialStyle.clair => FilledButton.icon(
        onPressed: onPresse,
        icon: icone_,
        label: libelle_,
        style: FilledButton.styleFrom(
          backgroundColor: TablTokens.texte,
          foregroundColor: TablTokens.fond,
          shape: forme,
          textStyle: TablTokens.libelleBouton,
        ),
      ),
      TablBoutonSocialStyle.sombre => FilledButton.icon(
        onPressed: onPresse,
        icon: icone_,
        label: libelle_,
        style: FilledButton.styleFrom(
          backgroundColor: TablTokens.surface,
          foregroundColor: TablTokens.texte,
          shape: forme,
          textStyle: TablTokens.libelleBouton,
        ),
      ),
      TablBoutonSocialStyle.contourAccent => OutlinedButton.icon(
        onPressed: onPresse,
        icon: icone_,
        label: libelle_,
        style: OutlinedButton.styleFrom(
          foregroundColor: TablTokens.primaire,
          side: const BorderSide(color: TablTokens.primaire),
          shape: forme,
          textStyle: TablTokens.libelleBouton,
        ),
      ),
      TablBoutonSocialStyle.contour => OutlinedButton.icon(
        onPressed: onPresse,
        icon: icone_,
        label: libelle_,
        style: OutlinedButton.styleFrom(
          foregroundColor: TablTokens.texte,
          side: const BorderSide(color: TablTokens.bordure),
          shape: forme,
          textStyle: TablTokens.libelleBouton,
        ),
      ),
    };

    return SizedBox(
      width: double.infinity,
      height: TablTokens.hauteurControle,
      child: bouton,
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

/// Petit bouton de ligne (« Suivre », « Accepter », « Refuser ») : plein
/// et doré pour l'action attendue, sinon contour discret. Assez petit
/// pour tenir à droite d'une ligne de liste. `onPresse: null` le grise.
class TablPetitBouton extends StatelessWidget {
  const TablPetitBouton({
    super.key,
    required this.libelle,
    required this.onPresse,
    this.plein = false,
  });

  final String libelle;
  final VoidCallback? onPresse;
  final bool plein;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPresse != null,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: onPresse == null ? 0.5 : 1,
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: plein ? TablTokens.primaire : Colors.transparent,
              borderRadius: BorderRadius.circular(TablTokens.arrondiS + 2),
              border: plein ? null : Border.all(color: TablTokens.bordure),
            ),
            child: Text(
              libelle,
              style: TablTokens.legende.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: plein ? TablTokens.texteSurPrimaire : TablTokens.texte,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
