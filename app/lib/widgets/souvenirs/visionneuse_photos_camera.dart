import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bouton_verre.dart';
import 'commandes_camera.dart';
import 'eventail_photos_camera.dart';
import 'verre_camera.dart';

/// Les mots de la visionneuse, déjà prêts à l'affichage.
class TextesVisionneusePhotos {
  const TextesVisionneusePhotos({
    required this.retour,
    required this.supprimer,
    required this.etat,
    required this.ok,
    required this.titreConfirmation,
    required this.detailConfirmation,
    required this.confirmer,
    required this.annuler,
  });

  /// Lu par les lecteurs d'écran sur la flèche de retour.
  final String retour;

  /// « Supprimer… » : ouvre la confirmation.
  final String supprimer;

  /// « Dans ce brouillon · privée ».
  final String etat;
  final String ok;

  final String titreConfirmation;
  final String detailConfirmation;
  final String confirmer;
  final String annuler;
}

/// Une photo du moment en grand, sur fond noir : on feuillette en glissant,
/// « 2 / 5 » en haut, « Supprimer… » demande confirmation. À poser sur tout
/// l'écran (`Positioned.fill`).
///
/// Les photos sont dans l'ordre du brouillon ; la suppression part en
/// callback et c'est à l'écran de retirer la photo de [vignettes] (la
/// visionneuse recadre alors sur la photo voisine).
class VisionneusePhotosCamera extends StatefulWidget {
  const VisionneusePhotosCamera({
    super.key,
    required this.vignettes,
    required this.indexInitial,
    required this.textes,
    required this.onFermer,
    required this.onSupprimer,
  });

  final List<VignetteEventail> vignettes;
  final int indexInitial;
  final TextesVisionneusePhotos textes;
  final VoidCallback onFermer;

  /// Rendue quand la suppression est faite.
  final Future<void> Function(String id) onSupprimer;

  @override
  State<VisionneusePhotosCamera> createState() =>
      _VisionneusePhotosCameraState();
}

class _VisionneusePhotosCameraState extends State<VisionneusePhotosCamera> {
  late int _index = widget.indexInitial.clamp(0, widget.vignettes.length - 1);
  late final PageController _pages = PageController(initialPage: _index);
  var _confirmation = false;
  var _suppressionEnCours = false;

  @override
  void didUpdateWidget(VisionneusePhotosCamera ancienne) {
    super.didUpdateWidget(ancienne);
    final dernier = widget.vignettes.length - 1;
    if (dernier >= 0 && _index > dernier) {
      _index = dernier;
      _pages.jumpToPage(dernier);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _supprimer() async {
    if (_suppressionEnCours) return;
    _suppressionEnCours = true;
    setState(() => _confirmation = false);
    try {
      await widget.onSupprimer(widget.vignettes[_index].id);
    } finally {
      _suppressionEnCours = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final marges = MediaQuery.paddingOf(context);
    final textes = widget.textes;
    final vignettes = widget.vignettes;
    if (vignettes.isEmpty) return const SizedBox.shrink();
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: Colors.black)),
        Positioned.fill(
          top: marges.top + 50,
          bottom: marges.bottom + 110,
          child: PageView.builder(
            controller: _pages,
            itemCount: vignettes.length,
            onPageChanged: (i) => setState(() => _index = i),
            findChildIndexCallback: (cle) {
              if (cle is! ValueKey<String>) return null;
              final i = vignettes.indexWhere((v) => v.id == cle.value);
              return i < 0 ? null : i;
            },
            itemBuilder: (context, i) => Semantics(
              key: ValueKey(vignettes[i].id),
              image: true,
              label: vignettes[i].libelle,
              child: Image(
                image: vignettes[i].image,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, erreur, trace) =>
                    ColoredBox(color: c.surface),
              ),
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          top: marges.top + 4,
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TablBoutonVerre(
                icone: Icons.arrow_back_ios_new_rounded,
                libelle: textes.retour,
                onPresse: widget.onFermer,
              ),
              Text(
                '${_index + 1} / ${vignettes.length}',
                style: TextStyle(
                  color: c.texte,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _confirmation = true),
                child: Semantics(
                  button: true,
                  label: textes.supprimer,
                  child: ExcludeSemantics(
                    child: VerreCamera(
                      arrondi: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: SizedBox(
                        height: 36,
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            textes.supprimer,
                            style: const TextStyle(
                              color: Color(0xFFF0B4A0),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: marges.bottom + 70,
          child: Text(
            textes.etat,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.texte.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: marges.bottom + 12,
          child: Align(
            alignment: Alignment.centerRight,
            child: BoutonContinuerCamera(
              libelle: textes.ok,
              onPresse: widget.onFermer,
            ),
          ),
        ),
        if (_confirmation)
          Positioned.fill(
            child: _BoiteConfirmation(
              textes: textes,
              onConfirmer: _supprimer,
              onAnnuler: () => setState(() => _confirmation = false),
            ),
          ),
      ],
    );
  }
}

class _BoiteConfirmation extends StatelessWidget {
  const _BoiteConfirmation({
    required this.textes,
    required this.onConfirmer,
    required this.onAnnuler,
  });

  final TextesVisionneusePhotos textes;
  final VoidCallback onConfirmer;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onAnnuler,
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: GestureDetector(
              onTap: () {},
              child: VerreCamera(
                arrondi: 20,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      textes.titreConfirmation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.texte,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      textes.detailConfirmation,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: c.texte.withValues(alpha: 0.75),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ActionBoite(
                      libelle: textes.confirmer,
                      couleur: const Color(0xFFF0B4A0),
                      onPresse: onConfirmer,
                    ),
                    _ActionBoite(
                      libelle: textes.annuler,
                      couleur: c.texte,
                      onPresse: onAnnuler,
                    ),
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

class _ActionBoite extends StatelessWidget {
  const _ActionBoite({
    required this.libelle,
    required this.couleur,
    required this.onPresse,
  });

  final String libelle;
  final Color couleur;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPresse,
      child: SizedBox(
        height: 46,
        child: Center(
          child: Text(
            libelle,
            style: TextStyle(
              color: couleur,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
