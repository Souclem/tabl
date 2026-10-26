import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les photos choisies pour un souvenir, en vignettes : la première est
/// la principale (étoile), toucher une autre la met à sa place, la croix
/// la retire. La case « + » en ajoute, tant qu'il reste de la place.
///
/// Composant pur : les photos arrivent déjà lues, chaque geste repart
/// par un callback.
class TablPhotosSouvenir extends StatelessWidget {
  const TablPhotosSouvenir({
    super.key,
    required this.photos,
    required this.libelle,
    required this.onChoisirPrincipale,
    required this.onRetirer,
    this.onAjouter,
  });

  final List<Uint8List> photos;

  /// "3 photos sur 10".
  final String libelle;
  final ValueChanged<int> onChoisirPrincipale;
  final ValueChanged<int> onRetirer;

  /// `null` : plus de place.
  final VoidCallback? onAjouter;

  static const double _cote = 76;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(libelle, style: TablTokens.legende)),
            if (photos.length > 1)
              Text(
                '★ principale',
                style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
              ),
          ],
        ),
        const SizedBox(height: TablTokens.espaceS),
        Wrap(
          spacing: TablTokens.espaceS,
          runSpacing: TablTokens.espaceS,
          children: [
            for (var i = 0; i < photos.length; i++)
              _Vignette(
                photo: photos[i],
                principale: i == 0,
                onPresse: () => onChoisirPrincipale(i),
                onRetirer: () => onRetirer(i),
              ),
            if (onAjouter != null)
              Semantics(
                button: true,
                label: 'Ajouter des photos',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onAjouter,
                  child: Container(
                    width: _cote,
                    height: _cote,
                    decoration: BoxDecoration(
                      color: TablTokens.surfaceBasse,
                      borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                      border: Border.all(color: TablTokens.bordure),
                    ),
                    child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: TablTokens.texteDoux,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({
    required this.photo,
    required this.principale,
    required this.onPresse,
    required this.onRetirer,
  });

  final Uint8List photo;
  final bool principale;
  final VoidCallback onPresse;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    const cote = TablPhotosSouvenir._cote;
    return Semantics(
      button: true,
      label: principale ? 'Photo principale' : 'En faire la photo principale',
      child: GestureDetector(
        onTap: onPresse,
        child: SizedBox(
          width: cote,
          height: cote,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                child: Image.memory(photo, fit: BoxFit.cover),
              ),
              if (principale)
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                    border: Border.all(color: TablTokens.texte, width: 2),
                  ),
                ),
              if (principale)
                const Positioned(
                  left: 6,
                  top: 4,
                  child: Text(
                    '★',
                    style: TextStyle(
                      color: TablTokens.texte,
                      fontSize: 15,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                    ),
                  ),
                ),
              Positioned(
                right: 2,
                top: 2,
                child: Semantics(
                  button: true,
                  label: 'Retirer cette photo',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: onRetirer,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: TablTokens.texte,
                      ),
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
