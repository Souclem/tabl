import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../indicateur_page.dart';

/// Les photos d'un souvenir en train d'être ajouté, en grand et bord à
/// bord, comme il apparaîtra une fois sur le profil : on les fait
/// défiler du doigt, le bas se fond dans la page.
///
/// [page] est celle affichée : la changer (vignette touchée) y amène ;
/// un défilement la renvoie par [onPage].
class TablApercuPhotos extends StatefulWidget {
  const TablApercuPhotos({
    super.key,
    required this.photos,
    required this.page,
    required this.onPage,
  });

  final List<Uint8List> photos;
  final int page;
  final ValueChanged<int> onPage;

  @override
  State<TablApercuPhotos> createState() => _TablApercuPhotosState();
}

class _TablApercuPhotosState extends State<TablApercuPhotos> {
  late final _controleur = PageController(initialPage: widget.page);

  @override
  void didUpdateWidget(TablApercuPhotos ancien) {
    super.didUpdateWidget(ancien);
    final actuelle = _controleur.hasClients ? _controleur.page?.round() : null;
    if (actuelle != null && actuelle != widget.page) {
      _controleur.animateToPage(
        widget.page,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controleur,
          itemCount: photos.length,
          onPageChanged: widget.onPage,
          itemBuilder: (_, i) =>
              Image.memory(photos[i], fit: BoxFit.cover, gaplessPlayback: true),
        ),
        // Le haut s'assombrit pour les boutons, le bas se fond dans la
        // page pour le nom du restaurant.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.22, 0.6, 1],
                colors: [
                  Colors.black.withValues(alpha: 0.38),
                  Colors.transparent,
                  Colors.transparent,
                  TablTokens.fond,
                ],
              ),
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: TablTokens.espaceL,
            child: IgnorePointer(
              child: Center(
                child: TablIndicateurPage(
                  total: photos.length,
                  index: widget.page,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// À la place des photos, pour un souvenir sans photo : une carte sombre
/// et sobre — jamais une image inventée —, et de quoi en ajouter.
class TablApercuSansPhoto extends StatelessWidget {
  const TablApercuSansPhoto({
    super.key,
    required this.libelle,
    required this.onAjouter,
  });

  /// "Ajouter des photos".
  final String libelle;
  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: TablTokens.surfaceBasse),
        CustomPaint(painter: _Quadrillage()),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.55, 1],
              colors: [Colors.transparent, TablTokens.fond],
            ),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TablTokens.surface,
                  border: Border.all(
                    color: TablTokens.texte.withValues(alpha: 0.12),
                  ),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: TablTokens.texte,
                ),
              ),
              const SizedBox(height: TablTokens.espaceM),
              TablPiluleVerre(
                icone: Icons.photo_library_outlined,
                libelle: libelle,
                onPresse: onAjouter,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un quadrillage discret, comme une carte vue de nuit.
class _Quadrillage extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = TablTokens.texte.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const pas = 36.0;
    for (var x = pas / 2; x < size.width; x += pas) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), trait);
    }
    for (var y = pas / 2; y < size.height; y += pas) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), trait);
    }
  }

  @override
  bool shouldRepaint(_Quadrillage ancien) => false;
}

/// Pilule en verre dépoli posée sur une photo ou une carte
/// (« ★ Principale », « Retirer ») : lisible sur n'importe quelle image.
class TablPiluleVerre extends StatelessWidget {
  const TablPiluleVerre({
    super.key,
    required this.icone,
    required this.libelle,
    this.onPresse,
  });

  final IconData icone;
  final String libelle;

  /// `null` : une simple mention, qu'on ne touche pas.
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: TablTokens.fond.withValues(alpha: 0.45),
          shape: StadiumBorder(
            side: BorderSide(color: TablTokens.texte.withValues(alpha: 0.14)),
          ),
          child: InkWell(
            onTap: onPresse,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 16, color: TablTokens.texte),
                  const SizedBox(width: 6),
                  Text(
                    libelle,
                    style: TablTokens.corps.copyWith(
                      fontSize: 13,
                      color: TablTokens.texte,
                    ),
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

/// Les photos d'un souvenir en petit, sous l'aperçu : on touche une
/// vignette pour la voir en grand ; la principale porte une étoile.
class TablBandeVignettes extends StatelessWidget {
  const TablBandeVignettes({
    super.key,
    required this.photos,
    required this.page,
    required this.onChoisir,
    this.onAjouter,
  });

  /// La première est la principale.
  final List<Uint8List> photos;
  final int page;
  final ValueChanged<int> onChoisir;

  /// `null` : plus de place.
  final VoidCallback? onAjouter;

  static const double _cote = 54;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _cote,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceL - 4),
        children: [
          for (var i = 0; i < photos.length; i++) ...[
            if (i > 0) const SizedBox(width: TablTokens.espaceS),
            Semantics(
              button: true,
              selected: i == page,
              label: i == 0 ? 'Photo principale' : 'Photo ${i + 1}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChoisir(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _cote,
                  height: _cote,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      TablTokens.arrondiS + 2,
                    ),
                    border: Border.all(
                      color: i == page ? TablTokens.texte : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          TablTokens.arrondiS,
                        ),
                        child: Opacity(
                          opacity: i == page ? 1 : 0.6,
                          child: Image.memory(photos[i], fit: BoxFit.cover),
                        ),
                      ),
                      if (i == 0)
                        const Positioned(
                          left: 4,
                          top: 2,
                          child: Text(
                            '★',
                            style: TextStyle(
                              color: TablTokens.texte,
                              fontSize: 12,
                              shadows: [
                                Shadow(color: Colors.black87, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (onAjouter != null) ...[
            const SizedBox(width: TablTokens.espaceS),
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
                    borderRadius: BorderRadius.circular(
                      TablTokens.arrondiS + 2,
                    ),
                    border: Border.all(color: TablTokens.bordure),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: TablTokens.texteDoux,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
