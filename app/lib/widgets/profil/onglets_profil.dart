import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une année proposée dans le sélecteur, avec son nombre de moments.
class AnneeProposee {
  const AnneeProposee({required this.annee, required this.compte});

  final int annee;

  /// "12 moments".
  final String compte;
}

/// Journal / Bilan, avec une pastille dorée qui glisse de l'un à
/// l'autre, et l'année affichée à côté. Fait pour rester épinglé en haut
/// du profil pendant qu'on défile (voir [TablDelegueHauteurFixe]).
class TablOngletsProfil extends StatelessWidget {
  const TablOngletsProfil({
    super.key,
    required this.bilan,
    required this.onChoisirBilan,
    required this.annee,
    required this.annees,
    required this.onChoisirAnnee,
  });

  /// Hauteur totale, marges comprises.
  static const double hauteur = 66;

  /// `false` : Journal.
  final bool bilan;
  final ValueChanged<bool> onChoisirBilan;
  final int annee;
  final List<AnneeProposee> annees;
  final ValueChanged<int> onChoisirAnnee;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: hauteur,
          color: TablTokens.fond.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceL - 4,
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: _Segments(bilan: bilan, onChoisirBilan: onChoisirBilan),
              ),
              const SizedBox(width: 10),
              _ChoixAnnee(
                annee: annee,
                annees: annees,
                onChoisirAnnee: onChoisirAnnee,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Segments extends StatelessWidget {
  const _Segments({required this.bilan, required this.onChoisirBilan});

  final bool bilan;
  final ValueChanged<bool> onChoisirBilan;

  @override
  Widget build(BuildContext context) {
    const duree = Duration(milliseconds: 450);
    Widget segment(
      String libelle, {
      required bool actif,
      required bool versBilan,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: actif,
          child: InkWell(
            onTap: () => onChoisirBilan(versBilan),
            borderRadius: BorderRadius.circular(20),
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: duree,
                style: TablTokens.corps.copyWith(
                  fontWeight: FontWeight.w600,
                  color: actif
                      ? TablTokens.texteSurPrimaire
                      : TablTokens.texteDoux,
                ),
                child: Text(libelle),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: TablTokens.surface),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: duree,
            curve: Curves.easeOutCubic,
            alignment: bilan ? Alignment.centerRight : Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: TablTokens.primaire,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: TablTokens.primaire.withValues(alpha: 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              segment('Journal', actif: !bilan, versBilan: false),
              segment('Bilan', actif: bilan, versBilan: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoixAnnee extends StatelessWidget {
  const _ChoixAnnee({
    required this.annee,
    required this.annees,
    required this.onChoisirAnnee,
  });

  final int annee;
  final List<AnneeProposee> annees;
  final ValueChanged<int> onChoisirAnnee;

  @override
  Widget build(BuildContext context) {
    final pilule = Container(
      height: 46,
      padding: const EdgeInsets.only(left: 16, right: 12),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: TablTokens.surface),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$annee',
            style: TablTokens.titreAffichage.copyWith(fontSize: 18),
          ),
          if (annees.length > 1) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: TablTokens.primaire,
            ),
          ],
        ],
      ),
    );
    if (annees.length <= 1) return pilule;
    return PopupMenuButton<int>(
      tooltip: "Choisir l'année",
      onSelected: onChoisirAnnee,
      color: TablTokens.surface,
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        side: const BorderSide(color: TablTokens.bordure),
      ),
      itemBuilder: (_) => [
        for (final a in annees)
          PopupMenuItem<int>(
            value: a.annee,
            child: SizedBox(
              width: 150,
              child: Row(
                children: [
                  Text(
                    '${a.annee}',
                    style: TablTokens.titreAffichage.copyWith(
                      fontSize: 18,
                      color: a.annee == annee
                          ? TablTokens.primaire
                          : TablTokens.texte,
                    ),
                  ),
                  const Spacer(),
                  Text(a.compte, style: TablTokens.legende),
                ],
              ),
            ),
          ),
      ],
      child: pilule,
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
