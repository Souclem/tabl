import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Une option de la feuille "Qui peut voir ?" : un rond à cocher, un
/// titre, une précision, et — seulement si elle est cochée — son
/// contenu détaillé juste en dessous ([detail]), pour ne jamais montrer
/// plus que nécessaire.
class TablOptionAudience extends StatelessWidget {
  const TablOptionAudience({
    super.key,
    required this.titre,
    required this.selectionnee,
    required this.onSelection,
    this.sousTitre,
    this.detail,
  });

  final String titre;
  final String? sousTitre;
  final bool selectionnee;
  final VoidCallback onSelection;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onSelection,
          borderRadius: BorderRadius.circular(TablTokens.arrondiM),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selectionnee ? c.primaire : c.texteDoux,
                      width: selectionnee ? 6.5 : 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: TablTokens.espaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        style: c.corps.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (sousTitre != null) Text(sousTitre!, style: c.legende),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: selectionnee && detail != null
              ? Padding(
                  padding: const EdgeInsets.only(
                    left: 22 + TablTokens.espaceM,
                    bottom: TablTokens.espaceS,
                  ),
                  child: detail,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Pastille qu'on coche ou décoche (une Table, une personne...).
class TablPuceSelection extends StatelessWidget {
  const TablPuceSelection({
    super.key,
    required this.libelle,
    required this.selectionnee,
    required this.onBascule,
  });

  final String libelle;
  final bool selectionnee;
  final VoidCallback onBascule;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return FilterChip(
      label: Text(libelle),
      selected: selectionnee,
      onSelected: (_) => onBascule(),
      backgroundColor: c.surface,
      selectedColor: c.primaire.withValues(alpha: 0.2),
      labelStyle: c.legende.copyWith(color: c.texte),
      side: BorderSide(color: c.bordure),
    );
  }
}

/// La ligne "Qui peut voir" du formulaire de publication : résume
/// l'audience choisie en quelques mots, un tap ouvre la feuille.
class TablLigneAudience extends StatelessWidget {
  const TablLigneAudience({
    super.key,
    required this.libelle,
    required this.restreinte,
    required this.onPresse,
  });

  /// Déjà composé ("Tout le monde", "Seulement Marbella"...).
  final String libelle;

  /// Cadenas plutôt qu'œil quand l'audience n'est pas "Tout le monde".
  final bool restreinte;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        side: BorderSide(color: c.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPresse,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceM,
            vertical: TablTokens.espaceM,
          ),
          child: Row(
            children: [
              Icon(
                restreinte
                    ? Icons.lock_outline_rounded
                    : Icons.visibility_outlined,
                size: 18,
                color: c.primaire,
              ),
              const SizedBox(width: TablTokens.espaceS),
              Text('Qui peut voir', style: c.corps),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: Text(
                  libelle,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: c.corps.copyWith(color: c.texteDoux),
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: c.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}
