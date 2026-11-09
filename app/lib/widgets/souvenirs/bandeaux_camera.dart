import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'pile_photos_camera.dart';
import 'verre_camera.dart';

/// Sous la barre du haut : « Suite du repas de 12 h 30 » et la sortie
/// « Autre repas » — ou, pour un repas plus ancien, « Nouveau repas » et
/// « C'est la suite de 12 h 30 ».
class BandeauSuiteRepas extends StatelessWidget {
  const BandeauSuiteRepas({
    super.key,
    required this.titre,
    required this.libelleAction,
    required this.onAction,
  });

  final String titre;
  final String libelleAction;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return VerreCamera(
      arrondi: 16,
      padding: const EdgeInsets.fromLTRB(13, 4, 4, 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              titre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.texte,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _BoutonDiscret(libelle: libelleAction, onPresse: onAction),
        ],
      ),
    );
  }
}

class _BoutonDiscret extends StatelessWidget {
  const _BoutonDiscret({required this.libelle, required this.onPresse});

  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Material(
      color: c.texte.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPresse,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            libelle,
            style: TextStyle(
              color: c.texte,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Le retour sur un brouillon après un moment : sa dernière photo, le
/// lieu, et trois gestes — le finaliser, en commencer un autre, masquer
/// la carte.
class CarteRepriseBrouillon extends StatelessWidget {
  const CarteRepriseBrouillon({
    super.key,
    required this.image,
    required this.titre,
    required this.detail,
    required this.invitation,
    required this.libelleFinaliser,
    required this.libelleNouveau,
    required this.libelleMasquer,
    required this.onFinaliser,
    required this.onNouveau,
    required this.onMasquer,
  });

  final ImageProvider image;
  final String titre;
  final String detail;
  final String invitation;
  final String libelleFinaliser;
  final String libelleNouveau;
  final String libelleMasquer;
  final VoidCallback onFinaliser;
  final VoidCallback onNouveau;
  final VoidCallback onMasquer;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        VerreCamera(
          arrondi: 22,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(
                          color: c.texte.withValues(alpha: 0.85),
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: MiniaturePhotoCamera(image: image, arrondi: 7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.texte,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          style: TextStyle(
                            color: c.texte.withValues(alpha: 0.7),
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invitation,
                          style: TextStyle(
                            color: c.texte.withValues(alpha: 0.86),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _BoutonCarte(
                      libelle: libelleFinaliser,
                      onPresse: onFinaliser,
                      principal: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BoutonCarte(
                      libelle: libelleNouveau,
                      onPresse: onNouveau,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: Semantics(
            button: true,
            label: libelleMasquer,
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onMasquer,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: c.fond.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 12, color: c.texte),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoutonCarte extends StatelessWidget {
  const _BoutonCarte({
    required this.libelle,
    required this.onPresse,
    this.principal = false,
  });

  final String libelle;
  final VoidCallback onPresse;
  final bool principal;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Material(
      color: principal ? c.primaire : c.texte.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPresse,
        child: SizedBox(
          height: 32,
          child: Center(
            child: Text(
              libelle,
              maxLines: 1,
              style: TextStyle(
                color: principal ? c.texteSurPrimaire : c.texte,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
