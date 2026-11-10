import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Un bouton en verre qui porte un mot (« Plus tard »), posé sur la photo.
class TablBoutonTexteVerre extends StatelessWidget {
  const TablBoutonTexteVerre({
    super.key,
    required this.libelle,
    required this.onPresse,
  });

  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(
                horizontal: TablTokens.espaceM,
              ),
              decoration: BoxDecoration(
                color: c.fond.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
                border: Border.all(color: c.texte.withValues(alpha: 0.14)),
              ),
              child: Text(libelle, style: c.corps.copyWith(fontSize: 15)),
            ),
          ),
        ),
      ),
    );
  }
}

/// La pilule d'audience de la finalisation : qui verra ce moment, un tap
/// ouvre la feuille « Qui peut voir ? ». En verre, posée sur la photo.
class TablPiluleAudience extends StatelessWidget {
  const TablPiluleAudience({
    super.key,
    required this.libelle,
    required this.restreinte,
    required this.onPresse,
  });

  final String libelle;
  final bool restreinte;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Semantics(
      button: true,
      label: 'Qui peut voir ? $libelle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              height: TablTokens.hauteurControle,
              constraints: const BoxConstraints(maxWidth: 190),
              padding: const EdgeInsets.symmetric(
                horizontal: TablTokens.espaceM,
              ),
              decoration: BoxDecoration(
                color: c.fond.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
                border: Border.all(color: c.texte.withValues(alpha: 0.14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    restreinte
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    size: 18,
                    color: restreinte ? c.primaire : c.texte,
                  ),
                  const SizedBox(width: TablTokens.espaceS),
                  Flexible(
                    child: Text(
                      libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.corps.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: TablTokens.espaceXs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: c.texte,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Le bouton principal de la finalisation, dont le libellé suit l'étape
/// (« Choisir les photos », « Où étiez-vous ? », « Publier »).
///
/// [grise] : l'action n'est pas encore permise (l'émotion manque) ; le
/// bouton reste touchable — l'écran s'en sert pour rappeler ce qui manque —
/// mais ne ressemble plus à un bouton prêt. [vitre] : une étape qui prépare
/// la publication plutôt que la publier, en verre plutôt qu'en or.
class TablBoutonPrincipalFinalisation extends StatelessWidget {
  const TablBoutonPrincipalFinalisation({
    super.key,
    required this.libelle,
    required this.onPresse,
    this.grise = false,
    this.vitre = false,
    this.enCours = false,
  });

  final String libelle;
  final VoidCallback? onPresse;
  final bool grise;
  final bool vitre;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final fond = vitre
        ? c.texte.withValues(alpha: 0.16)
        : c.primaire.withValues(alpha: grise ? 0.35 : 1);
    final texte = vitre
        ? c.texte
        : (grise
              ? c.texteSurPrimaire.withValues(alpha: 0.6)
              : c.texteSurPrimaire);
    return Semantics(
      button: true,
      enabled: !grise && !enCours,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enCours ? null : onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: TablTokens.hauteurControle,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fond,
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: vitre
                ? Border.all(color: c.texte.withValues(alpha: 0.24))
                : null,
          ),
          child: enCours
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: texte,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Text(
                    libelle,
                    key: ValueKey(libelle),
                    style: TablTokens.libelleBouton.copyWith(color: texte),
                  ),
                ),
        ),
      ),
    );
  }
}
