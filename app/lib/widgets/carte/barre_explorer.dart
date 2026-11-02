import 'package:flutter/material.dart';

import '../../theme/apparence.dart';
import '../../theme/tokens.dart';

/// La barre qui flotte en bas de l'Explorer (maquette de Martin) :
/// « Rechercher » en grand, les filtres avec le nombre d'actifs, et le
/// choix entre la carte et la grille.
///
/// Composant pur : les gestes repartent par leurs callbacks.
class TablBarreExplorer extends StatelessWidget {
  const TablBarreExplorer({
    super.key,
    required this.onRechercher,
    required this.onFiltres,
    required this.enGrille,
    required this.onChoisirVue,
    this.filtresActifs = 0,
  });

  final VoidCallback onRechercher;
  final VoidCallback onFiltres;
  final int filtresActifs;
  final bool enGrille;

  /// `true` : la grille ; `false` : la carte.
  final ValueChanged<bool> onChoisirVue;

  static const _courbe = Cubic(0.2, 1.15, 0.3, 1);

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    return Container(
      height: 60,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.barre,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: TablTokens.encre.withValues(alpha: 0.32),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: 'Rechercher',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onRechercher,
                child: Container(
                  height: 50,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: TablTokens.texte,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        size: 21,
                        color: TablTokens.encre,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Rechercher',
                        style: TablTokens.corps.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: TablTokens.encre,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Semantics(
            button: true,
            label: filtresActifs == 0
                ? 'Filtres'
                : 'Filtres, $filtresActifs actifs',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onFiltres,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: palette.barreBouton,
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 21,
                      color: TablTokens.texte,
                    ),
                    if (filtresActifs > 0)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: TablTokens.primaire,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$filtresActifs',
                            style: TablTokens.legende.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: TablTokens.encre,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 5),
          Container(
            height: 50,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: palette.barreBouton,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 450),
                  curve: _courbe,
                  left: enGrille ? 44 : 0,
                  top: 0,
                  width: 44,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TablTokens.texte.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BoutonVue(
                      libelle: 'Carte',
                      icone: Icons.map_outlined,
                      choisi: !enGrille,
                      onPresse: () => onChoisirVue(false),
                    ),
                    _BoutonVue(
                      libelle: 'Grille',
                      icone: Icons.grid_view_rounded,
                      choisi: enGrille,
                      onPresse: () => onChoisirVue(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BoutonVue extends StatelessWidget {
  const _BoutonVue({
    required this.libelle,
    required this.icone,
    required this.choisi,
    required this.onPresse,
  });

  final String libelle;
  final IconData icone;
  final bool choisi;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: choisi,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icone, size: 20, color: TablTokens.texte),
        ),
      ),
    );
  }
}

/// « Constellation » en haut de l'Explorer : passer à ma carte à moi,
/// ville par ville, et en revenir. Allumé quand on y est.
class TablBoutonConstellation extends StatelessWidget {
  const TablBoutonConstellation({
    super.key,
    required this.actif,
    required this.onPresse,
  });

  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    final encre = actif ? palette.fond : palette.texte;
    return Semantics(
      button: true,
      selected: actif,
      label: 'Constellation',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: actif ? palette.texte : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: actif
                  ? palette.texte
                  : palette.texte.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: encre),
              const SizedBox(width: 6),
              Text(
                'Constellation',
                style: TablTokens.legende.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
