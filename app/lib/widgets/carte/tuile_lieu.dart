import 'package:flutter/material.dart';

import '../../theme/apparence.dart';
import '../../theme/tokens.dart';
import '../avatar.dart';

/// Ce qu'une tuile dit d'une adresse, par sa couleur.
enum GenreTuile {
  /// Mon cercle y est allé : nuit.
  cercle,

  /// Mes proches y retournent : braise.
  retour,

  /// J'y suis allé moi aussi : ivoire.
  vous,
}

/// Une adresse dans la grille de l'Explorer (maquette de Martin) : son
/// nom, les visages de ceux qui y sont allés, la distance et la cuisine,
/// la note dans l'encoche du coin, le marque-page des envies.
///
/// Composant pur : tout arrive prêt à afficher.
class TablTuileLieu extends StatelessWidget {
  const TablTuileLieu({
    super.key,
    required this.nom,
    required this.genre,
    required this.onPresse,
    this.visages = const [],
    this.autres,
    this.autresNombreux = false,
    this.etVous = false,
    this.enGras,
    this.detail,
    this.note,
    this.envie = false,
    this.onVisages,
    this.onEnvie,
  });

  final String nom;
  final GenreTuile genre;

  /// Trois au plus.
  final List<({String pseudo, String? photoUrl})> visages;

  /// "+4" ; `null` : personne de plus.
  final String? autres;

  /// Beaucoup de monde (« +10 ») : la pastille se dore.
  final bool autresNombreux;

  /// « et vous » après les visages.
  final bool etVous;

  /// "50 m", en gras, puis [detail] ("Japonais").
  final String? enGras;
  final String? detail;

  /// "4,0" ; `null` : pas d'encoche.
  final String? note;
  final bool envie;
  final VoidCallback onPresse;

  /// Les visages ouvrent « Qui y est allé ».
  final VoidCallback? onVisages;
  final VoidCallback? onEnvie;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    final fond = switch (genre) {
      GenreTuile.cercle => palette.tuileCercle,
      GenreTuile.retour => palette.tuileRetour,
      GenreTuile.vous => palette.tuileVous,
    };
    final clair = genre == GenreTuile.vous;
    final encre = clair ? TablTokens.encre : TablTokens.texte;
    final encreDouce = switch (genre) {
      GenreTuile.cercle => const Color(0xFFB3BAC6),
      GenreTuile.retour => TablTokens.texte,
      GenreTuile.vous => TablTokens.encreDouce,
    };
    final note = this.note;
    return Semantics(
      button: true,
      label: nom,
      child: GestureDetector(
        onTap: onPresse,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 146),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _FondTuile(
                    couleur: fond,
                    contour: clair ? palette.contourVous : null,
                    encoche: note != null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 15, 13),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 26),
                      child: Text(
                        nom,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TablTokens.titreSerre.copyWith(
                          fontSize: nom.length > 22 ? 17.5 : 21,
                          color: encre,
                        ),
                      ),
                    ),
                    if (visages.isNotEmpty || autres != null || etVous)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: GestureDetector(
                          onTap: onVisages,
                          behavior: HitTestBehavior.opaque,
                          child: _Visages(
                            visages: visages,
                            autres: autres,
                            autresNombreux: autresNombreux,
                            etVous: etVous,
                            fondTuile: fond,
                            genre: genre,
                          ),
                        ),
                      ),
                    if (enGras != null || detail != null)
                      Padding(
                        padding: EdgeInsets.only(
                          top: 6,
                          bottom: note != null ? 32 : 0,
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              if (enGras != null)
                                TextSpan(
                                  text: enGras,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: encre,
                                  ),
                                ),
                              if (enGras != null && detail != null)
                                const TextSpan(text: ' · '),
                              if (detail != null) TextSpan(text: detail),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TablTokens.legende.copyWith(
                            fontSize: 13,
                            color: encreDouce,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  tooltip: envie
                      ? 'Retirer de mes envies'
                      : 'Garder pour plus tard',
                  visualDensity: VisualDensity.compact,
                  onPressed: onEnvie,
                  icon: Icon(
                    envie
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 19,
                    color: envie ? encre : encre.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (note != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  width: 94,
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: palette.etoile),
                      const SizedBox(width: 3),
                      Text(
                        note,
                        style: TablTokens.corps.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: palette.texte,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Visages extends StatelessWidget {
  const _Visages({
    required this.visages,
    required this.autres,
    required this.autresNombreux,
    required this.etVous,
    required this.fondTuile,
    required this.genre,
  });

  final List<({String pseudo, String? photoUrl})> visages;
  final String? autres;
  final bool autresNombreux;
  final bool etVous;
  final Color fondTuile;
  final GenreTuile genre;

  @override
  Widget build(BuildContext context) {
    final clair = genre == GenreTuile.vous;
    final autres = this.autres;
    final (fondPlus, textePlus) = switch ((genre, autresNombreux)) {
      (GenreTuile.vous, false) => (const Color(0x1407111F), TablTokens.encre),
      (GenreTuile.vous, true) => (TablTokens.encre, TablTokens.primaire),
      (GenreTuile.retour, false) => (const Color(0x33F5F0E8), TablTokens.texte),
      (GenreTuile.retour, true) => (TablTokens.texte, const Color(0xFF7E3420)),
      (GenreTuile.cercle, false) => (const Color(0x1FF5F0E8), TablTokens.texte),
      (GenreTuile.cercle, true) => (
        const Color(0x2EE9C88E),
        TablTokens.primaire,
      ),
    };
    Widget visage(int i) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: fondTuile, shape: BoxShape.circle),
      child: TablAvatar(
        pseudo: visages[i].pseudo,
        photoUrl: visages[i].photoUrl,
        rayon: 13,
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < visages.length; i++)
          // Chaque visage mord de 7 points sur le précédent.
          i == 0
              ? visage(i)
              : Align(
                  alignment: Alignment.centerRight,
                  widthFactor: 23 / 30,
                  child: visage(i),
                ),
        if (autres != null)
          Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              height: 22,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fondPlus,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                autres,
                style: TablTokens.legende.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: textePlus,
                ),
              ),
            ),
          ),
        if (etVous)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Text(
                'et vous',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TablTokens.legende.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: clair ? TablTokens.encre : TablTokens.texte,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Le fond d'une tuile : arrondi, avec l'encoche du coin bas-droit où se
/// pose la note (forme reprise de la maquette).
class _FondTuile extends CustomPainter {
  const _FondTuile({
    required this.couleur,
    required this.encoche,
    this.contour,
  });

  final Color couleur;
  final bool encoche;
  final Color? contour;

  Path _forme(Size taille) {
    final fond = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & taille,
          const Radius.circular(24),
        ),
      );
    if (!encoche) return fond;
    // Chemin de la maquette, 100 × 58, collé au coin bas-droit.
    final dx = taille.width - 100;
    final dy = taille.height - 58;
    final coin = Path()
      ..moveTo(dx, dy + 58)
      ..lineTo(dx + 100, dy + 58)
      ..lineTo(dx + 100, dy)
      ..cubicTo(dx + 100, dy + 6.7, dx + 93.3, dy + 16, dx + 84, dy + 16)
      ..lineTo(dx + 35.2, dy + 16)
      ..cubicTo(dx + 17.6, dy + 16, dx + 16.8, dy + 58, dx, dy + 58)
      ..close();
    return Path.combine(PathOperation.difference, fond, coin);
  }

  @override
  void paint(Canvas canvas, Size taille) {
    final forme = _forme(taille);
    canvas.drawPath(forme, Paint()..color = couleur);
    final contour = this.contour;
    if (contour != null && contour.a > 0) {
      canvas.drawPath(
        forme,
        Paint()
          ..color = contour
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_FondTuile ancien) =>
      ancien.couleur != couleur ||
      ancien.encoche != encoche ||
      ancien.contour != contour;
}
