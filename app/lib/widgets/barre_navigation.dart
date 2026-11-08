import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Les onglets de la barre de navigation principale.
enum TablOnglet { feed, tables, carte, profil }

/// Barre de navigation flottante, reprise du prototype : une pilule de
/// verre dépoli posée au-dessus du contenu. Cinq places égales : Feed,
/// Tables, publier (au centre, dans un anneau doré), Explorer, Profil.
///
/// L'onglet actif a son icône remplie d'or, un halo doux derrière elle
/// et un petit trait lumineux dessous ; halo et trait glissent d'un
/// onglet à l'autre. Les autres restent en simple contour clair.
/// [compacte] : la barre se tasse un peu pendant qu'on fait défiler
/// vers le bas, et reprend sa taille dès qu'on s'arrête.
///
/// Composant pur : reçoit l'onglet actif et des callbacks, ne décide rien.
class TablBarreNavigation extends StatelessWidget {
  const TablBarreNavigation({
    super.key,
    required this.ongletActif,
    required this.onSelection,
    required this.onPublier,
    this.compacte = false,
    this.pastilleTables = false,
  });

  final TablOnglet ongletActif;
  final ValueChanged<TablOnglet> onSelection;
  final VoidCallback onPublier;
  final bool compacte;

  /// Petit point doré sur les Tables : du nouveau y attend.
  final bool pastilleTables;

  static const _hauteur = 70.0;
  static const _hauteurCompacte = 62.0;
  static const _largeurMax = 352.0;

  /// Distance au bas de l'écran : juste au-dessus du trait de l'iPhone.
  static double _marge(BuildContext context) {
    final securite = MediaQuery.paddingOf(context).bottom;
    return securite > 0 ? securite - 6 : TablTokens.espaceM;
  }

  /// Hauteur qu'occupe la barre en bas de l'écran (marge et zone de
  /// sécurité du téléphone comprises) — pour qu'un écran place ses
  /// éléments du bas juste au-dessus.
  static double hauteurOccupee(BuildContext context) =>
      _hauteur + _marge(context);

  static const _duree = Duration(milliseconds: 380);
  static const _courbe = Cubic(0.32, 1.05, 0.3, 1);

  @override
  Widget build(BuildContext context) {
    final hauteur = compacte ? _hauteurCompacte : _hauteur;
    final rayon = compacte ? 28.0 : 32.0;
    return Padding(
      padding: EdgeInsets.only(bottom: _marge(context)),
      child: Center(
        heightFactor: 1,
        child: LayoutBuilder(
          builder: (context, contraintes) {
            final largeur = (contraintes.maxWidth - 2 * TablTokens.espaceM)
                .clamp(0.0, _largeurMax);
            final largeurCase = (largeur - 16) / 5;
            final rang = switch (ongletActif) {
              TablOnglet.feed => 0,
              TablOnglet.tables => 1,
              TablOnglet.carte => 3,
              TablOnglet.profil => 4,
            };
            final centreActif = 8 + largeurCase * rang + largeurCase / 2;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              width: largeur,
              height: hauteur,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rayon),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x75000000),
                    blurRadius: 54,
                    offset: Offset(0, 22),
                  ),
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(rayon),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(rayon),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x801A1A1D), Color(0xB808090C)],
                      ),
                      border: Border.all(
                        color: TablTokens.texte.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Un reflet en haut, comme sur du verre.
                        const Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 1,
                          child: FractionallySizedBox(
                            widthFactor: 0.84,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0x00FFFFFF),
                                    Color(0x80FFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0, -1.4),
                                radius: 1.1,
                                colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
                                stops: [0, 0.62],
                              ),
                            ),
                          ),
                        ),
                        // Le halo de l'onglet actif.
                        AnimatedPositioned(
                          duration: _duree,
                          curve: _courbe,
                          left: centreActif - 26,
                          top: hauteur / 2 - 26,
                          width: 52,
                          height: 52,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x38D9AC67),
                                    Color(0x14D9AC67),
                                    Color(0x00D9AC67),
                                  ],
                                  stops: [0, 0.46, 0.72],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Et son petit trait lumineux.
                        AnimatedPositioned(
                          duration: _duree,
                          curve: _courbe,
                          left: centreActif - 8,
                          bottom: 12,
                          width: 16,
                          height: 2,
                          child: const IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0x33D9AC67),
                                    TablTokens.primaire,
                                    Color(0x33D9AC67),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x73D9AC67),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            children: [
                              _onglet(TablOnglet.feed, 'Feed', _Icone.feed),
                              _onglet(
                                TablOnglet.tables,
                                'Tables',
                                _Icone.tables,
                                pastille: pastilleTables,
                              ),
                              Expanded(
                                child: _BoutonPublier(onPresse: onPublier),
                              ),
                              _onglet(
                                TablOnglet.carte,
                                'Explorer',
                                _Icone.explorer,
                              ),
                              _onglet(
                                TablOnglet.profil,
                                'Profil',
                                _Icone.profil,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _onglet(
    TablOnglet onglet,
    String libelle,
    _Icone icone, {
    bool pastille = false,
  }) {
    return Expanded(
      child: _Onglet(
        libelle: libelle,
        icone: icone,
        actif: onglet == ongletActif,
        pastille: pastille,
        onPresse: () => onSelection(onglet),
      ),
    );
  }
}

class _Onglet extends StatefulWidget {
  const _Onglet({
    required this.libelle,
    required this.icone,
    required this.actif,
    required this.pastille,
    required this.onPresse,
  });

  final String libelle;
  final _Icone icone;
  final bool actif;
  final bool pastille;
  final VoidCallback onPresse;

  @override
  State<_Onglet> createState() => _OngletState();
}

class _OngletState extends State<_Onglet> {
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.actif,
      label: widget.libelle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _enfonce = true),
        onTapCancel: () => setState(() => _enfonce = false),
        onTapUp: (_) => setState(() => _enfonce = false),
        onTap: widget.onPresse,
        child: AnimatedScale(
          scale: _enfonce ? 0.9 : 1,
          duration: const Duration(milliseconds: 120),
          child: Center(
            child: AnimatedSlide(
              offset: Offset(0, widget.actif ? -1 / 26 : 0),
              duration: const Duration(milliseconds: 220),
              curve: const Cubic(0.34, 1.1, 0.32, 1),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: widget.actif ? 1 : 0),
                    duration: const Duration(milliseconds: 220),
                    builder: (_, t, _) => CustomPaint(
                      size: const Size.square(26),
                      painter: _PeintreIcone(widget.icone, t),
                    ),
                  ),
                  if (widget.pastille)
                    const Positioned(
                      top: -1,
                      right: -3,
                      child: SizedBox(
                        width: 6,
                        height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TablTokens.primaire,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xCCD9AC67),
                                blurRadius: 7,
                              ),
                            ],
                          ),
                        ),
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

/// Le « + » de publication : un anneau doré, qui s'illumine un instant
/// sous le doigt.
class _BoutonPublier extends StatefulWidget {
  const _BoutonPublier({required this.onPresse});

  final VoidCallback onPresse;

  @override
  State<_BoutonPublier> createState() => _BoutonPublierState();
}

class _BoutonPublierState extends State<_BoutonPublier> {
  bool _enfonce = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Publier un moment',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _enfonce = true),
        onTapCancel: () => setState(() => _enfonce = false),
        onTapUp: (_) => setState(() => _enfonce = false),
        onTap: widget.onPresse,
        child: Center(
          child: AnimatedScale(
            scale: _enfonce ? 0.96 : 1,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TablTokens.primaire.withValues(
                  alpha: _enfonce ? 0.14 : 0.05,
                ),
                border: Border.all(
                  color: TablTokens.primaire.withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: _enfonce
                    ? [
                        BoxShadow(
                          color: TablTokens.primaire.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ]
                    : null,
              ),
              // Centré : sans lui, le dessin prendrait toute la place de
              // l'anneau.
              child: const Center(
                child: CustomPaint(
                  size: Size.square(23),
                  painter: _PeintrePlus(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Icone { feed, tables, explorer, profil }

/// Les icônes de la barre, dessinées comme dans le prototype (grille de
/// 24, trait arrondi). [actif] de 0 à 1 : du contour clair à l'icône
/// pleine, dorée.
class _PeintreIcone extends CustomPainter {
  const _PeintreIcone(this.icone, this.actif);

  final _Icone icone;
  final double actif;

  static const _inactif = Color(0x9EF5F0E8);
  static const _or = TablTokens.primaire;
  static const _orPlein = Color(0xE6D9AC67);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7 - 0.2 * actif
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(_inactif, _or, actif)!;
    final plein = Paint()
      ..style = PaintingStyle.fill
      ..color = _orPlein.withValues(alpha: 0.9 * actif);

    void dessiner(Path chemin, {bool remplir = true}) {
      if (remplir && actif > 0) canvas.drawPath(chemin, plein);
      canvas.drawPath(chemin, trait);
    }

    switch (icone) {
      case _Icone.feed:
        dessiner(
          Path()
            ..moveTo(3.9, 10.9)
            ..lineTo(12, 4.2)
            ..lineTo(20.1, 10.9)
            ..lineTo(20.1, 18.5)
            ..arcToPoint(
              const Offset(18.5, 20.1),
              radius: const Radius.circular(1.6),
            )
            ..lineTo(14.9, 20.1)
            ..lineTo(14.9, 14.7)
            ..arcToPoint(
              const Offset(13.6, 13.4),
              radius: const Radius.circular(1.3),
              clockwise: false,
            )
            ..lineTo(10.4, 13.4)
            ..arcToPoint(
              const Offset(9.1, 14.7),
              radius: const Radius.circular(1.3),
              clockwise: false,
            )
            ..lineTo(9.1, 20.1)
            ..lineTo(5.5, 20.1)
            ..arcToPoint(
              const Offset(3.9, 18.5),
              radius: const Radius.circular(1.6),
            )
            ..close(),
        );
      case _Icone.tables:
        dessiner(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(9.3, 8.5), radius: 3),
          ),
        );
        dessiner(
          Path()
            ..moveTo(3.7, 18.8)
            ..cubicTo(4.3, 15.4, 6.5, 13.5, 9.3, 13.5)
            ..cubicTo(12.1, 13.5, 14.3, 15.4, 14.9, 18.8)
            ..close(),
        );
        dessiner(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(17.2, 9.6), radius: 2.15),
          ),
        );
        dessiner(
          Path()
            ..moveTo(15.6, 14.2)
            ..cubicTo(18, 14.4, 19.6, 16.1, 20.2, 18.8),
          remplir: false,
        );
      case _Icone.explorer:
        dessiner(
          Path()
            ..moveTo(12, 20.4)
            ..cubicTo(8.4, 16.1, 6.4, 12.9, 6.4, 10.5)
            ..arcToPoint(
              const Offset(17.6, 10.5),
              radius: const Radius.circular(5.6),
            )
            ..cubicTo(17.6, 12.9, 15.6, 16.1, 12, 20.4)
            ..close(),
        );
        // Le cœur de l'épingle : un trou sombre quand elle est pleine.
        final coeur = Path()
          ..addOval(
            Rect.fromCircle(center: const Offset(12, 10.2), radius: 2.05),
          );
        if (actif > 0) {
          canvas.drawPath(
            coeur,
            Paint()..color = const Color(0xFF12141A).withValues(alpha: actif),
          );
        }
        canvas.drawPath(
          coeur,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = _inactif.withValues(alpha: 0.62 * (1 - actif)),
        );
      case _Icone.profil:
        dessiner(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(12, 8.1), radius: 3.5),
          ),
        );
        dessiner(
          Path()
            ..moveTo(4.9, 19.8)
            ..cubicTo(5.8, 15.5, 8.5, 13.4, 12, 13.4)
            ..cubicTo(15.5, 13.4, 18.2, 15.5, 19.1, 19.8)
            ..close(),
        );
    }
  }

  @override
  bool shouldRepaint(_PeintreIcone ancien) =>
      ancien.icone != icone || ancien.actif != actif;
}

class _PeintrePlus extends CustomPainter {
  const _PeintrePlus();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 18);
    final trait = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xE6E2C48A);
    canvas.drawLine(const Offset(9, 3), const Offset(9, 15), trait);
    canvas.drawLine(const Offset(3, 9), const Offset(15, 9), trait);
  }

  @override
  bool shouldRepaint(_PeintrePlus ancien) => false;
}
