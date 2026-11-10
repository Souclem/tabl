import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Les photos d'un moment en cours de création, plein écran : on glisse de
/// l'une à l'autre, un trait par photo en haut montre où l'on en est.
/// Sans photo, un fond uni. Toujours sombre : le dégradé du haut et du bas
/// garde le texte posé dessus lisible.
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
                  c.fond.withValues(alpha: 0.55),
                  c.fond.withValues(alpha: 0),
                  c.fond.withValues(alpha: 0),
                  c.fond.withValues(alpha: 0.92),
                ],
                stops: const [0, 0.2, 0.42, 1],
              ),
            ),
          ),
        ),
        if (images.length > 1)
          Positioned(
            left: TablTokens.espaceM,
            right: TablTokens.espaceM,
            top: MediaQuery.paddingOf(context).top + TablTokens.espaceS,
            child: Row(
              children: [
                for (var i = 0; i < images.length; i++)
                  Expanded(
                    child: Container(
                      key: ValueKey('trait-photo-$i'),
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: c.texte.withValues(
                          alpha: i == widget.page ? 0.95 : 0.35,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
