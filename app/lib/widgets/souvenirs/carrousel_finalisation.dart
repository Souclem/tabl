import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les photos d'un moment en cours de création, plein écran : on glisse de
/// l'une à l'autre. Pas de traits en haut : on publie, ce n'est pas une
/// story.
/// Sans photo, un fond uni. Toujours sombre : le voile du haut (de hauteur
/// fixe, il couvre tout l'en-tête : lieu, date, mot sur deux lignes) et le
/// dégradé du bas gardent le texte blanc lisible, même sur une photo
/// claire.
class TablCarrouselFinalisation extends StatefulWidget {
  const TablCarrouselFinalisation({
    super.key,
    required this.images,
    required this.page,
    required this.onPage,
  });

  final List<ImageProvider> images;
  final int page;
  final ValueChanged<int> onPage;

  @override
  State<TablCarrouselFinalisation> createState() =>
      _TablCarrouselFinalisationState();
}

/// Sous la zone sûre : « Plus tard », puis l'en-tête (lieu, date, mot sur
/// deux lignes), avec de quoi s'effacer.
const _hauteurVoileHaut = 300.0;

class _TablCarrouselFinalisationState extends State<TablCarrouselFinalisation> {
  late final PageController _controleur = PageController(
    initialPage: widget.page,
  );

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final images = widget.images;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: TablTokens.fond),
        if (images.isNotEmpty)
          PageView.builder(
            controller: _controleur,
            itemCount: images.length,
            onPageChanged: widget.onPage,
            itemBuilder: (context, i) => Image(
              image: images[i],
              fit: BoxFit.cover,
              errorBuilder: (context, erreur, pile) =>
                  const ColoredBox(color: TablTokens.surface),
            ),
          ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.fond.withValues(alpha: 0),
                  c.fond.withValues(alpha: 0.92),
                ],
                stops: const [0.42, 1],
              ),
            ),
          ),
        ),
        // Le haut : sombre derrière le texte, puis s'efface en douceur.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: MediaQuery.paddingOf(context).top + _hauteurVoileHaut,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    c.fond.withValues(alpha: 0.72),
                    c.fond.withValues(alpha: 0.66),
                    c.fond.withValues(alpha: 0.5),
                    c.fond.withValues(alpha: 0.2),
                    c.fond.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.5, 0.72, 0.88, 1],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
