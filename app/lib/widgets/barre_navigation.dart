import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Les onglets de la barre de navigation principale.
enum TablOnglet { feed, tables, carte, profil }

/// Barre de navigation flottante — une pilule posée au-dessus du
/// contenu, jamais collée aux bords ni pleine largeur (voir
/// `instruction/Clément (2)/uploads/Capture d'écran 2026-08-25 à
/// 22.18.49.png`). Icônes seules, sans libellé ; l'onglet actif et le
/// bouton de publication se distinguent par un simple anneau doré, jamais
/// un aplat — cohérent avec « le champagne sert uniquement à... des
/// détails, jamais un aplat » (bible de design).
///
/// Composant pur : reçoit l'onglet actif et des callbacks, ne décide rien.
class TablBarreNavigation extends StatelessWidget {
  const TablBarreNavigation({
    super.key,
    required this.ongletActif,
    required this.onSelection,
    required this.onPublier,
  });

  final TablOnglet ongletActif;
  final ValueChanged<TablOnglet> onSelection;
  final VoidCallback onPublier;

  static const _hauteur = 60.0;

  /// Hauteur qu'occupe la barre flottante en bas de l'écran (marges et
  /// zone de sécurité du téléphone comprises) — pour qu'un écran place
  /// ses éléments du bas juste au-dessus.
  static double hauteurOccupee(BuildContext context) =>
      _hauteur + TablTokens.espaceM + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceXl,
        0,
        TablTokens.espaceXl,
        TablTokens.espaceM,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: _hauteur,
          decoration: BoxDecoration(
            color: TablTokens.surface.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: Border.all(color: TablTokens.bordure),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _item(TablOnglet.feed, Icons.home_rounded, Icons.home_outlined),
              _item(
                TablOnglet.tables,
                Icons.table_restaurant_rounded,
                Icons.table_restaurant_outlined,
              ),
              _boutonPublier(),
              _item(
                TablOnglet.carte,
                Icons.location_on_rounded,
                Icons.location_on_outlined,
              ),
              _item(
                TablOnglet.profil,
                Icons.person_rounded,
                Icons.person_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(TablOnglet onglet, IconData iconeActive, IconData iconeInactive) {
    final actif = onglet == ongletActif;
    return _Anneau(
      actif: actif,
      onTap: () => onSelection(onglet),
      icone: actif ? iconeActive : iconeInactive,
    );
  }

  Widget _boutonPublier() {
    return _Anneau(actif: true, onTap: onPublier, icone: Icons.add_rounded);
  }
}

/// Icône entourée d'un anneau doré si [actif], sinon simple icône grise —
/// jamais de fond rempli, juste un contour (voir la note de classe).
class _Anneau extends StatelessWidget {
  const _Anneau({required this.actif, required this.onTap, required this.icone});

  final bool actif;
  final VoidCallback onTap;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: actif
              ? Border.all(color: TablTokens.primaire, width: 1.5)
              : null,
        ),
        child: Icon(
          icone,
          size: 20,
          color: actif ? TablTokens.primaire : TablTokens.texteDoux,
        ),
      ),
    );
  }
}
