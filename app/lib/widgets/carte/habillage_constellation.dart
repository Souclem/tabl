import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

const _ivoireDoux = Color.fromRGBO(245, 240, 232, 0.64);
const _verre = Color.fromRGBO(13, 19, 34, 0.78);
const _trait = Color.fromRGBO(245, 240, 232, 0.14);

/// « Constellation », en grand, et ce qu'elle compte (« 298 tables ·
/// 971 repas · 55 villes »), posés sur le ciel.
class TablTitreConstellation extends StatelessWidget {
  const TablTitreConstellation({super.key, required this.compteurs});

  final String compteurs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Constellation',
          style: TablTokens.titreSerre.copyWith(
            fontSize: 34,
            height: 0.95,
            letterSpacing: -0.68,
            shadows: const [
              Shadow(
                color: Color.fromRGBO(0, 0, 0, 0.6),
                offset: Offset(0, 2),
                blurRadius: 18,
              ),
            ],
          ),
        ),
        if (compteurs.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            compteurs,
            style: const TextStyle(
              fontFamily: 'BricolageGrotesque',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontVariations: [FontVariation('wght', 500)],
              color: _ivoireDoux,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ],
    );
  }
}

/// « Pincez pour zoomer · touchez une ville pour l'ouvrir », qui s'efface
/// au premier geste.
class TablAideConstellation extends StatelessWidget {
  const TablAideConstellation({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 600),
      child: const Text(
        'Pincez pour zoomer · touchez une ville pour l\'ouvrir',
        style: TextStyle(
          fontFamily: 'BricolageGrotesque',
          fontSize: 13,
          color: _ivoireDoux,
          shadows: [
            Shadow(color: Color.fromRGBO(0, 0, 0, 0.8), blurRadius: 10),
          ],
        ),
      ),
    );
  }
}

/// La fiche d'une étoile touchée : son nom, sa ville et ses repas, depuis
/// quand ; « Vous y retournez » à partir de trois repas.
class TablFicheEtoile extends StatelessWidget {
  const TablFicheEtoile({
    super.key,
    required this.nom,
    required this.detail,
    required this.depuis,
    required this.retour,
    this.onPresse,
  });

  final String nom;

  /// « Liège · 5 repas ».
  final String detail;

  /// « Première fois en mars 2022 ».
  final String depuis;
  final bool retour;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    const texte = TextStyle(
      fontFamily: 'BricolageGrotesque',
      fontSize: 14,
      color: _ivoireDoux,
    );
    return GestureDetector(
      onTap: onPresse,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _verre,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _trait),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      nom,
                      style: const TextStyle(
                        fontFamily: 'BricolageGrotesque',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontVariations: [
                          FontVariation('wght', 750),
                          FontVariation('wdth', 82),
                        ],
                        letterSpacing: -0.22,
                        color: TablTokens.texte,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(detail, style: texte),
                    const SizedBox(height: 4),
                    Text(depuis, style: texte),
                    if (retour) ...[
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: TablTokens.primaire,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          child: Text(
                            'Vous y retournez',
                            style: TextStyle(
                              fontFamily: 'BricolageGrotesque',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontVariations: [FontVariation('wght', 600)],
                              color: Color(0xFF05070D),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
