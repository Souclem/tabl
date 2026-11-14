import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'verre_camera.dart';

/// Hauteur des pilules de verre (« Plus tard », l'audience).
const _hauteurPilule = 40.0;

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
    return Semantics(
      button: true,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: VerreCamera(
          arrondi: _hauteurPilule / 2,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: SizedBox(
            height: _hauteurPilule,
            child: Center(
              widthFactor: 1,
              child: Text(
                libelle,
                maxLines: 1,
                style: TablTokens.policeCreation.copyWith(fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un bouton rond en verre qui porte une icône (l'appareil photo qui
/// ramène à la caméra), à la hauteur de « Plus tard ».
class TablBoutonIconeVerre extends StatelessWidget {
  const TablBoutonIconeVerre({
    super.key,
    required this.icone,
    required this.libelle,
    required this.onPresse,
  });

  final IconData icone;

  /// Lu par les lecteurs d'écran, montré à l'appui long.
  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Tooltip(
      message: libelle,
      child: Semantics(
        button: true,
        label: libelle,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onPresse,
          child: VerreCamera(
            arrondi: _hauteurPilule / 2,
            padding: EdgeInsets.zero,
            child: SizedBox.square(
              dimension: _hauteurPilule,
              child: Icon(icone, size: 19, color: c.texte),
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: VerreCamera(
            arrondi: _hauteurPilule / 2,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: SizedBox(
              height: _hauteurPilule,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    restreinte
                        ? Icons.lock_outline_rounded
                        : Icons.public_rounded,
                    size: 17,
                    color: restreinte ? c.primaire : c.texte,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      libelle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.policeCreation.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
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
/// (« Publier », « Enregistrer ») : une
/// pilule de 50 px, à sa largeur (128 px au moins).
///
/// [grise] : l'action n'est pas encore permise (l'émotion manque) ; le
/// bouton reste touchable — l'écran s'en sert pour rappeler ce qui manque —
/// mais s'efface à moitié. [vitre] : une étape qui prépare la publication
/// plutôt que la publier, en verre plutôt qu'en or.
class TablBoutonPrincipalFinalisation extends StatelessWidget {
  const TablBoutonPrincipalFinalisation({
    super.key,
    required this.libelle,
    required this.onPresse,
    this.grise = false,
    this.vitre = false,
    this.enCours = false,
  });

  static const double hauteur = 50;

  final String libelle;
  final VoidCallback? onPresse;
  final bool grise;
  final bool vitre;
  final bool enCours;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final texte = vitre ? c.texte : c.texteSurPrimaire;
    final contenu = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 128),
      child: SizedBox(
        height: hauteur,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Center(
            widthFactor: 1,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.policeCreation.copyWith(
                        fontSize: 16,
                        color: texte,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !grise && !enCours,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: enCours ? null : onPresse,
        child: AnimatedOpacity(
          opacity: grise ? 0.4 : 1,
          duration: const Duration(milliseconds: 200),
          child: vitre
              ? VerreCamera(arrondi: hauteur / 2, child: contenu)
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.primaire,
                    borderRadius: BorderRadius.circular(hauteur / 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: contenu,
                ),
        ),
      ),
    );
  }
}
