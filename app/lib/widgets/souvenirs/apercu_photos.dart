import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../indicateur_page.dart';

/// Une façon d'ajouter des photos : « Prendre une photo »,
/// « Photothèque »…
typedef ActionAjoutPhoto = ({
  IconData icone,
  String libelle,
  VoidCallback onPresse,
});

/// Les photos d'un souvenir ou d'un moment en train d'être créé, en
/// grand et bord à bord, comme il apparaîtra une fois publié : on les
/// fait défiler du doigt, le bas se fond dans la page.
///
/// [page] est celle affichée : la changer (vignette touchée) y amène ;
/// un défilement la renvoie par [onPage]. Avec [pageAjout], une page de
/// plus attend après la dernière photo : on glisse pour en ajouter une
/// (son numéro est alors `photos.length`).
class TablApercuPhotos extends StatefulWidget {
  const TablApercuPhotos({
    super.key,
    required this.photos,
    required this.page,
    required this.onPage,
    this.pageAjout,
  });

  /// Celles du téléphone (en cours de création) ou déjà en ligne.
  final List<ImageProvider> photos;
  final int page;
  final ValueChanged<int> onPage;
  final Widget? pageAjout;

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
    final c = TablCouleurs.of(context);
    final photos = widget.photos;
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _controleur,
          itemCount: photos.length + (widget.pageAjout == null ? 0 : 1),
          onPageChanged: widget.onPage,
          itemBuilder: (_, i) => i < photos.length
              ? Image(
                  image: photos[i],
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  // Une photo en ligne qui ne vient pas : le fond, pas
                  // une erreur.
                  errorBuilder: (_, _, _) => const SizedBox(),
                )
              : widget.pageAjout!,
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
                  c.fond,
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

/// À la place d'une photo : une carte sombre et sobre — jamais une image
/// inventée —, et de quoi en ajouter. Sert avant la première photo, et
/// comme page d'ajout après la dernière ([TablApercuPhotos.pageAjout]).
class TablApercuSansPhoto extends StatelessWidget {
  const TablApercuSansPhoto({super.key, required this.actions, this.titre});

  /// La première donne son icône au rond du milieu.
  final List<ActionAjoutPhoto> actions;

  /// Au-dessus des boutons : « Une autre photo ? ».
  final String? titre;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.surfaceBasse),
        CustomPaint(painter: _Quadrillage(c.texte)),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.55, 1],
              colors: [Colors.transparent, c.fond],
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
                  color: c.surface,
                  border: Border.all(color: c.texte.withValues(alpha: 0.12)),
                ),
                child: Icon(
                  actions.firstOrNull?.icone ??
                      Icons.add_photo_alternate_outlined,
                  color: c.texte,
                ),
              ),
              if (titre != null) ...[
                const SizedBox(height: TablTokens.espaceM),
                Text(titre!, style: c.titreAffichage.copyWith(fontSize: 20)),
              ],
              const SizedBox(height: TablTokens.espaceM),
              Wrap(
                spacing: TablTokens.espaceS,
                runSpacing: TablTokens.espaceS,
                alignment: WrapAlignment.center,
                children: [
                  for (final action in actions)
                    TablPiluleVerre(
                      icone: action.icone,
                      libelle: action.libelle,
                      onPresse: action.onPresse,
                    ),
                ],
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
  _Quadrillage(this.couleur);

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final trait = Paint()
      ..color = couleur.withValues(alpha: 0.05)
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
  bool shouldRepaint(_Quadrillage ancien) => ancien.couleur != couleur;
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
    final c = TablCouleurs.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: c.fond.withValues(alpha: 0.45),
          shape: StadiumBorder(
            side: BorderSide(color: c.texte.withValues(alpha: 0.14)),
          ),
          child: InkWell(
            onTap: onPresse,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icone, size: 16, color: c.texte),
                  const SizedBox(width: 6),
                  Text(
                    libelle,
                    style: c.corps.copyWith(fontSize: 13, color: c.texte),
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
  final List<ImageProvider> photos;
  final int page;
  final ValueChanged<int> onChoisir;

  /// `null` : plus de place.
  final VoidCallback? onAjouter;

  static const double _cote = 54;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
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
                      color: i == page ? c.texte : Colors.transparent,
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
                          child: Image(
                            image: photos[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ),
                      if (i == 0)
                        const Positioned(
                          left: 4,
                          top: 2,
                          child: Text(
                            '★',
                            style: TextStyle(
                              color: Colors.white,
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
                    border: Border.all(color: c.bordure),
                  ),
                  child: Icon(Icons.add_rounded, color: c.texteDoux),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
