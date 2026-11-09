import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'verre_camera.dart';

/// « Importer », à gauche du déclencheur tant qu'aucune photo n'est prise :
/// la photothèque du téléphone.
class BoutonImporterCamera extends StatelessWidget {
  const BoutonImporterCamera({
    super.key,
    required this.libelle,
    required this.onPresse,
  });

  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPresse,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VerreCamera(
            arrondi: 12,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.photo_library_outlined,
                size: 20,
                color: c.texte,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            libelle,
            style: TextStyle(
              color: c.texte,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Color(0x66000000))],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Continuer · 3 » : passer à la finalisation du moment.
class BoutonContinuerCamera extends StatelessWidget {
  const BoutonContinuerCamera({
    super.key,
    required this.libelle,
    required this.onPresse,
  });

  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Material(
      color: c.texte,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onPresse,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 44,
            child: Center(
              widthFactor: 1,
              child: Text(
                libelle,
                maxLines: 1,
                style: TextStyle(
                  color: c.fond,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ce qui apparaît un instant au-dessus de la pile après chaque photo :
/// « 3 photos gardées ».
class CompteurPhotosCamera extends StatelessWidget {
  const CompteurPhotosCamera({
    super.key,
    required this.nombre,
    required this.libelle,
    required this.visible,
  });

  final int nombre;
  final String libelle;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.3),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: VerreCamera(
            arrondi: 15,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              height: 30,
              child: Center(
                widthFactor: 1,
                child: Text(
                  '$nombre $libelle',
                  maxLines: 1,
                  style: TextStyle(
                    color: c.texte,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Au centre du viseur, quand il n'y a pas d'image à montrer : caméra
/// refusée ou absente.
class MessageViseurCamera extends StatelessWidget {
  const MessageViseurCamera({
    super.key,
    required this.titre,
    required this.detail,
  });

  final String titre;
  final String detail;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.no_photography_outlined, size: 34, color: c.texteDoux),
          const SizedBox(height: 12),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.texte,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.texteDoux, fontSize: 13.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}
