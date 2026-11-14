import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'verre_camera.dart';

/// Une photo de la pile : son image, et si elle est encore « mouillée »
/// (prise, mais pas encore enregistrée sur le téléphone).
class VignettePile {
  const VignettePile({required this.image, this.mouillee = false});

  final ImageProvider image;
  final bool mouillee;
}

/// La miniature d'une photo, arrondie, cadrée au centre ; grise si l'image
/// ne se lit pas.
class MiniaturePhotoCamera extends StatelessWidget {
  const MiniaturePhotoCamera({
    super.key,
    required this.image,
    this.arrondi = 8,
  });

  final ImageProvider image;
  final double arrondi;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(arrondi),
      child: Image(
        image: image,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, erreur, trace) =>
            ColoredBox(color: TablCouleurs.sombre.surface),
      ),
    );
  }
}

/// Les photos du moment en cours, en pile à gauche du déclencheur : les
/// trois dernières, légèrement de travers, et leur nombre dès la deuxième.
/// La toucher ouvre l'éventail.
class PilePhotosCamera extends StatelessWidget {
  const PilePhotosCamera({
    super.key,
    required this.vignettes,
    required this.nombre,
    required this.libelle,
    this.onTap,
  });

  final List<VignettePile> vignettes;

  /// Le nombre de photos, affiché dès la deuxième.
  final int nombre;

  /// Lu par les lecteurs d'écran : « Voir les 3 photos de ce moment ».
  final String libelle;
  final VoidCallback? onTap;

  static const _inclinaisons = [
    (angle: 5.0, dx: 3.0, dy: -3.0),
    (angle: -6.0, dx: -3.0, dy: -2.0),
    (angle: 0.0, dx: 0.0, dy: 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final visibles = vignettes.length > 3
        ? vignettes.sublist(vignettes.length - 3)
        : vignettes;
    final decalage = 3 - visibles.length;
    return Semantics(
      button: onTap != null,
      label: libelle,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var k = 0; k < visibles.length; k++)
                  Transform.translate(
                    offset: Offset(
                      _inclinaisons[k + decalage].dx,
                      _inclinaisons[k + decalage].dy,
                    ),
                    child: Transform.rotate(
                      angle:
                          _inclinaisons[k + decalage].angle * 3.14159265 / 180,
                      child: AnimatedOpacity(
                        opacity: visibles[k].mouillee ? 0.7 : 1,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: c.texte.withValues(alpha: 0.9),
                                spreadRadius: 1,
                              ),
                              const BoxShadow(
                                color: Color(0x59000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: MiniaturePhotoCamera(image: visibles[k].image),
                        ),
                      ),
                    ),
                  ),
                if (nombre > 1)
                  Positioned(
                    right: 2,
                    top: 4,
                    child: _PastilleNombre(nombre: nombre),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PastilleNombre extends StatelessWidget {
  const _PastilleNombre({required this.nombre});

  final int nombre;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return TweenAnimationBuilder<double>(
      key: ValueKey(nombre),
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 360),
      builder: (context, t, child) {
        final echelle = t < 0.4
            ? 1 + 0.35 * (t / 0.4)
            : 1.35 - 0.35 * ((t - 0.4) / 0.6);
        return Transform.scale(scale: echelle, child: child);
      },
      child: VerreCamera(
        arrondi: 10,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: SizedBox(
          height: 20,
          child: Center(
            widthFactor: 1,
            child: Text(
              '$nombre',
              style: TextStyle(
                color: c.texte,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une photo qui vient d'être prise et s'envole du viseur vers la pile :
/// à poser directement dans le `Stack` de l'écran.
class PhotoEnVol extends StatelessWidget {
  const PhotoEnVol({
    super.key,
    required this.image,
    required this.depart,
    required this.arrivee,
    required this.onTermine,
  });

  final ImageProvider image;

  /// Où la photo apparaît (le viseur) et où elle se pose (la pile), dans
  /// le repère du `Stack`.
  final Rect depart;
  final Rect arrivee;
  final VoidCallback onTermine;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 440),
      curve: const Cubic(0.32, 0.72, 0.2, 1),
      onEnd: onTermine,
      builder: (context, t, _) => Positioned.fromRect(
        rect: Rect.lerp(depart, arrivee, t)!,
        child: IgnorePointer(
          child: MiniaturePhotoCamera(image: image, arrondi: 2 + 6 * t),
        ),
      ),
    );
  }
}
