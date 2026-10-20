import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les rubriques d'un profil, comme sur Strava : des mots répartis sur la
/// largeur, un trait doré sous celle qu'on regarde, qui glisse quand on
/// en change. Fait pour rester épinglé en haut pendant qu'on défile
/// (voir [TablDelegueHauteurFixe]).
class TablOngletsTexte extends StatelessWidget {
  const TablOngletsTexte({
    super.key,
    required this.libelles,
    required this.index,
    required this.onChoisir,
  });

  static const double hauteur = 52;

  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    const duree = Duration(milliseconds: 380);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: hauteur,
          decoration: BoxDecoration(
            color: TablTokens.fond.withValues(alpha: 0.92),
            border: const Border(bottom: BorderSide(color: TablTokens.surface)),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < libelles.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: InkWell(
                          onTap: () => onChoisir(i),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: duree,
                              style: TablTokens.corps.copyWith(
                                fontWeight: FontWeight.w600,
                                color: i == index
                                    ? TablTokens.texte
                                    : TablTokens.texteDoux,
                              ),
                              child: Text(libelles[i]),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              AnimatedAlign(
                duration: duree,
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  libelles.length == 1
                      ? 0
                      : -1 + 2 * index / (libelles.length - 1),
                  1,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / libelles.length,
                  child: Container(
                    height: 2.5,
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      color: TablTokens.primaire,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La période d'un bilan : « Depuis le début », puis chaque année, en
/// pastilles qui défilent ; celle choisie est dorée.
class TablChoixPeriode extends StatelessWidget {
  const TablChoixPeriode({
    super.key,
    required this.periodes,
    required this.index,
    required this.onChoisir,
  });

  final List<String> periodes;
  final int index;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: periodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: TablTokens.espaceS),
        itemBuilder: (context, i) {
          final choisie = i == index;
          return Semantics(
            button: true,
            selected: choisie,
            child: GestureDetector(
              onTap: () => onChoisir(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: choisie ? TablTokens.primaire : Colors.transparent,
                  borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
                  border: Border.all(
                    color: choisie ? TablTokens.primaire : TablTokens.bordure,
                  ),
                ),
                child: Text(
                  periodes[i],
                  style: TablTokens.corps.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: choisie
                        ? TablTokens.texteSurPrimaire
                        : TablTokens.texte,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Un en-tête épinglé de hauteur fixe pour une `SliverPersistentHeader`.
class TablDelegueHauteurFixe extends SliverPersistentHeaderDelegate {
  const TablDelegueHauteurFixe({required this.hauteur, required this.child});

  final double hauteur;
  final Widget child;

  @override
  double get minExtent => hauteur;

  @override
  double get maxExtent => hauteur;

  @override
  Widget build(BuildContext context, double decalage, bool chevauche) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(TablDelegueHauteurFixe ancien) =>
      ancien.hauteur != hauteur || ancien.child != child;
}
