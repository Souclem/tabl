import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';

/// Les pièces de l'onglet Bilan d'un profil. Toutes pures : elles
/// reçoivent des textes et des parts déjà calculés.

/// Petit titre doré en capitales au-dessus d'une section.
class TablTitreSection extends StatelessWidget {
  const TablTitreSection({super.key, required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texte.toUpperCase(),
        style: c.legende.copyWith(
          fontSize: 11,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w700,
          color: c.primaire,
        ),
      ),
    );
  }
}

/// La personne avec qui on partage le plus de tables, mise en avant.
class TablCarteBinome extends StatelessWidget {
  const TablCarteBinome({
    super.key,
    required this.role,
    required this.nom,
    required this.detail,
    required this.onPresse,
    this.photoUrl,
  });

  /// "Ton binôme de table".
  final String role;
  final String nom;
  final String? photoUrl;

  /// "5 moments · 4 adresses".
  final String detail;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return _Carte(
      onPresse: onPresse,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.primaire, width: 1.5),
            ),
            child: TablAvatar(pseudo: nom, photoUrl: photoUrl, rayon: 36),
          ),
          const SizedBox(width: TablTokens.espaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.toUpperCase(),
                  style: c.legende.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: c.primaire,
                  ),
                ),
                const SizedBox(height: 4),
                Text(nom, style: c.titreAffichage.copyWith(fontSize: 26)),
                const SizedBox(height: 2),
                Text(detail, style: c.legende),
              ],
            ),
          ),
          if (onPresse != null)
            Icon(Icons.chevron_right_rounded, color: c.texteDoux),
        ],
      ),
    );
  }
}

/// Une personne proche, en petite carte (trois côte à côte).
class TablCarteProche extends StatelessWidget {
  const TablCarteProche({
    super.key,
    required this.nom,
    required this.detail,
    required this.onPresse,
    this.photoUrl,
  });

  final String nom;
  final String? photoUrl;

  /// "4 moments".
  final String detail;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return _Carte(
      onPresse: onPresse,
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 14),
      child: Column(
        children: [
          TablAvatar(pseudo: nom, photoUrl: photoUrl, rayon: 28),
          const SizedBox(height: TablTokens.espaceS),
          Text(
            nom,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: c.corps.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(detail, style: c.legende.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

/// Une adresse où l'on revient : sa photo en fond, le nombre de visites
/// en grand et en points dorés.
class TablCarteRetour extends StatelessWidget {
  const TablCarteRetour({
    super.key,
    required this.nom,
    required this.lieu,
    required this.nombreVisites,
    required this.total,
    this.photoUrl,
  });

  final String nom;

  /// "Milan · depuis novembre 2025".
  final String lieu;
  final int nombreVisites;

  /// "3 visites au total".
  final String total;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(TablTokens.arrondiL),
      child: SizedBox(
        height: 136,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: c.surface),
            if (photoUrl != null)
              Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withValues(alpha: 0.38),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c.fond.withValues(alpha: 0.88),
                    c.fond.withValues(alpha: 0.3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nom,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: c.titreAffichage.copyWith(fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lieu,
                              style: c.legende.copyWith(
                                color: c.texte.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '×$nombreVisites',
                        style: c.titreAffichage.copyWith(
                          fontSize: 30,
                          color: c.primaire,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      for (var i = 0; i < math.min(nombreVisites, 12); i++)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 5),
                          decoration: BoxDecoration(
                            color: c.primaire,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 4),
                      Text(
                        total,
                        style: c.legende.copyWith(
                          fontSize: 12,
                          color: c.texte.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ville et sa barre, qui se remplit à l'arrivée.
class TablBarreVille extends StatelessWidget {
  const TablBarreVille({
    super.key,
    required this.nom,
    required this.compte,
    required this.part,
    this.rang = 0,
  });

  final String nom;

  /// "6 moments".
  final String compte;

  /// De 0 à 1.
  final double part;

  /// Décale le remplissage : les barres partent l'une après l'autre.
  final int rang;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final retard = 250 + rang * 100;
    final duree = retard + 900;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(nom, style: c.titreAffichage.copyWith(fontSize: 19)),
              const Spacer(),
              Text(compte, style: c.legende),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.surface)),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: part),
                    duration: Duration(milliseconds: duree),
                    curve: Interval(
                      retard / duree,
                      1,
                      curve: Curves.easeOutCubic,
                    ),
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: ColoredBox(color: c.primaire),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une part de l'anneau des moments.
class PartAnneau {
  const PartAnneau({
    required this.libelle,
    required this.detail,
    required this.part,
  });

  /// "Dîner".
  final String libelle;

  /// "8 · 67 %".
  final String detail;

  /// De 0 à 1.
  final double part;
}

/// Déjeuners et dîners de l'année, en anneau qui se dessine, avec le
/// total au centre.
class TablAnneauMoments extends StatelessWidget {
  const TablAnneauMoments({
    super.key,
    required this.parts,
    required this.total,
  });

  final List<PartAnneau> parts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final couleurs = [c.primaire, c.primaireFoncee, c.texte];
    return _Carte(
      child: Row(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: const Interval(0.2, 1, curve: Curves.easeInOutCubic),
                  builder: (context, v, _) => CustomPaint(
                    size: const Size.square(132),
                    painter: _PeintreAnneau(
                      parts: [for (final p in parts) p.part],
                      couleurs: couleurs,
                      fond: c.surface,
                      avancee: v,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$total',
                      style: c.titreAffichage.copyWith(fontSize: 32, height: 1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      total > 1 ? 'MOMENTS' : 'MOMENT',
                      style: c.legende.copyWith(
                        fontSize: 10.5,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < parts.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: couleurs[i % couleurs.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(parts[i].libelle, style: c.corps),
                            Text(
                              parts[i].detail,
                              style: c.legende.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeintreAnneau extends CustomPainter {
  _PeintreAnneau({
    required this.parts,
    required this.couleurs,
    required this.fond,
    required this.avancee,
  });

  final List<double> parts;
  final List<Color> couleurs;
  final Color fond;
  final double avancee;

  @override
  void paint(Canvas canvas, Size size) {
    const epaisseur = 14.0;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - epaisseur / 2,
    );
    final pinceau = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = epaisseur;
    canvas.drawArc(rect, 0, 2 * math.pi, false, pinceau..color = fond);
    // Un petit espace entre les parts, et chacune se dessine à son tour.
    const ecart = 0.05;
    var debut = -math.pi / 2;
    var cumul = 0.0;
    for (var i = 0; i < parts.length; i++) {
      final balayage = parts[i] * 2 * math.pi;
      final visible = ((avancee - cumul) / parts[i]).clamp(0.0, 1.0);
      if (visible > 0 && balayage > ecart) {
        canvas.drawArc(
          rect,
          debut,
          (balayage - ecart) * visible,
          false,
          pinceau..color = couleurs[i % couleurs.length],
        );
      }
      debut += balayage;
      cumul += parts[i];
    }
  }

  @override
  bool shouldRepaint(_PeintreAnneau ancien) =>
      ancien.avancee != avancee ||
      ancien.fond != fond ||
      ancien.couleurs != couleurs;
}

/// Une cuisine ("Italien · 3") ; la plus fréquente est mise en avant.
class TablPastilleCuisine extends StatelessWidget {
  const TablPastilleCuisine({
    super.key,
    required this.texte,
    this.enAvant = false,
  });

  final String texte;
  final bool enAvant;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: enAvant
            ? c.primaire.withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
        border: Border.all(color: enAvant ? c.primaire : c.bordure),
      ),
      child: Text(
        texte,
        style: c.corps.copyWith(
          fontSize: 14,
          color: enAvant ? c.primaire : c.texte.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

/// Ce que deux personnes ont vécu ensemble à table, en haut du profil de
/// l'autre : « Toi & Arthur ».
class TablCarteDuo extends StatelessWidget {
  const TablCarteDuo({
    super.key,
    required this.monPseudo,
    required this.sonPseudo,
    required this.depuis,
    required this.resume,
    required this.onRevoir,
    this.maPhotoUrl,
    this.saPhotoUrl,
  });

  final String monPseudo;
  final String? maPhotoUrl;
  final String sonPseudo;
  final String? saPhotoUrl;

  /// "À table ensemble depuis mars 2025".
  final String depuis;

  /// "7 moments ensemble, dans 5 adresses. Le dernier : …".
  final String resume;
  final VoidCallback onRevoir;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    Widget tete(String pseudo, String? photo) => Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.surfaceBasse, shape: BoxShape.circle),
      child: TablAvatar(pseudo: pseudo, photoUrl: photo, rayon: 22),
    );
    return _Carte(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 74,
                height: 48,
                child: Stack(
                  children: [
                    Positioned(left: 26, child: tete(sonPseudo, saPhotoUrl)),
                    tete(monPseudo, maPhotoUrl),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Toi & $sonPseudo',
                      style: c.titreAffichage.copyWith(fontSize: 21),
                    ),
                    const SizedBox(height: 2),
                    Text(depuis, style: c.legende),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resume,
            style: c.corps.copyWith(
              fontSize: 14,
              color: c.texte.withValues(alpha: 0.82),
            ),
          ),
          TextButton.icon(
            onPressed: onRevoir,
            style: TextButton.styleFrom(
              foregroundColor: c.primaire,
              padding: EdgeInsets.zero,
            ),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            label: const Text('Revoir vos moments'),
          ),
        ],
      ),
    );
  }
}

/// Fond commun des cartes du profil : discret, posé à même le fond.
class _Carte extends StatelessWidget {
  const _Carte({
    required this.child,
    this.onPresse,
    this.padding = const EdgeInsets.all(TablTokens.espaceM),
  });

  final Widget child;
  final VoidCallback? onPresse;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Material(
      color: c.surfaceBasse,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        side: BorderSide(color: c.surface),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPresse,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
