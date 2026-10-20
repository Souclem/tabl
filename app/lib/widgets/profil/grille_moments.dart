import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bulles_personnes.dart';

/// L'en-tête d'un mois du journal, fait pour rester épinglé pendant
/// qu'on parcourt ses photos : « Octobre 2026 · 3 moments ».
class TablEnTeteMois extends StatelessWidget {
  const TablEnTeteMois({
    super.key,
    required this.titre,
    required this.annee,
    required this.compte,
  });

  static const double hauteur = 56;

  /// "Octobre".
  final String titre;

  /// "2026".
  final String annee;

  /// "3 moments".
  final String compte;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: hauteur,
          color: TablTokens.fond.withValues(alpha: 0.9),
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            14,
            TablTokens.espaceL - 4,
            6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                titre,
                style: TablTokens.titreAffichage.copyWith(fontSize: 26),
              ),
              const SizedBox(width: 8),
              Text(annee, style: TablTokens.legende.copyWith(fontSize: 15)),
              const Spacer(),
              Text(
                compte.toUpperCase(),
                style: TablTokens.legende.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sous l'en-tête d'un mois : les têtes de ceux qui étaient là, et le
/// récit en une ligne (« Arthur et Emma · Liège »).
class TablRecitMois extends StatelessWidget {
  const TablRecitMois({super.key, required this.bulles, required this.recit});

  final List<BullePersonne> bulles;
  final String recit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        2,
        TablTokens.espaceL - 4,
        12,
      ),
      child: Row(
        children: [
          if (bulles.isNotEmpty) ...[
            TablBullesPersonnes(bulles: bulles, taille: 34),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              recit,
              style: TablTokens.corps.copyWith(
                fontSize: 14,
                color: TablTokens.texte.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une photo de la grille.
class TuileMoment {
  const TuileMoment({
    required this.cleHero,
    required this.photoUrl,
    required this.libelle,
    required this.onPresse,
    this.marquant = false,
  });

  /// Relie la tuile au moment agrandi : la photo vole de l'une à l'autre.
  final Object cleHero;
  final String? photoUrl;

  /// "Forno Rosso, 16 octobre" — lu par les lecteurs d'écran.
  final String libelle;
  final VoidCallback onPresse;

  /// Coup de cœur : petit cœur doré dans le coin.
  final bool marquant;
}

/// Les photos d'un mois, collées en rangées de trois comme la galerie
/// de l'iPhone. Le moment vedette (s'il y en a un) prend la place de
/// quatre, avec deux petites à côté.
class TablGrilleMoments extends StatelessWidget {
  const TablGrilleMoments({super.key, required this.tuiles, this.indexVedette});

  final List<TuileMoment> tuiles;
  final int? indexVedette;

  static const double _espace = 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, contraintes) {
        final cote = (contraintes.maxWidth - 2 * _espace) / 3;
        final restantes = [...tuiles];
        final rangees = <Widget>[];
        var rang = 0;

        Widget tuile(TuileMoment t, double taille) =>
            _Tuile(tuile: t, taille: taille, rang: rang++);

        final vedette = indexVedette;
        if (vedette != null && tuiles.length >= 3) {
          final grande = restantes.removeAt(vedette);
          final petites = [restantes.removeAt(0), restantes.removeAt(0)];
          rangees.add(
            Row(
              children: [
                tuile(grande, cote * 2 + _espace),
                const SizedBox(width: _espace),
                Column(
                  children: [
                    tuile(petites[0], cote),
                    const SizedBox(height: _espace),
                    tuile(petites[1], cote),
                  ],
                ),
              ],
            ),
          );
        }
        for (var i = 0; i < restantes.length; i += 3) {
          final ligne = restantes.skip(i).take(3).toList();
          rangees.add(
            Row(
              children: [
                for (var j = 0; j < ligne.length; j++) ...[
                  if (j > 0) const SizedBox(width: _espace),
                  tuile(ligne[j], cote),
                ],
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < rangees.length; i++) ...[
              if (i > 0) const SizedBox(height: _espace),
              rangees[i],
            ],
          ],
        );
      },
    );
  }
}

class _Tuile extends StatelessWidget {
  const _Tuile({required this.tuile, required this.taille, required this.rang});

  final TuileMoment tuile;
  final double taille;

  /// Ordre d'apparition : les tuiles arrivent l'une après l'autre.
  final int rang;

  @override
  Widget build(BuildContext context) {
    final retard = (rang.clamp(0, 12)) * 35;
    final duree = 380 + retard;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: duree),
      curve: Interval(retard / duree, 1, curve: Curves.easeOutCubic),
      builder: (context, v, enfant) => Opacity(
        opacity: v,
        child: Transform.scale(scale: 0.94 + 0.06 * v, child: enfant),
      ),
      child: Semantics(
        button: true,
        label: tuile.libelle,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: tuile.onPresse,
          child: SizedBox(
            width: taille,
            height: taille,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: tuile.cleHero,
                  createRectTween: volEnLigneDroite,
                  child: _Photo(url: tuile.photoUrl),
                ),
                if (tuile.marquant)
                  const Positioned(
                    top: 7,
                    right: 7,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 17,
                      color: TablTokens.primaire,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La photo d'un moment, ou un fond neutre s'il n'en a pas — partagée
/// entre la tuile et le moment agrandi pour que le vol reste fluide.
class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TablTokens.surface,
      child: url == null
          ? const Center(
              child: Icon(
                Icons.restaurant_rounded,
                color: TablTokens.texteDoux,
              ),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
    );
  }
}

/// Le vol d'une photo entre sa tuile et le moment agrandi : en ligne
/// droite, comme la galerie de l'iPhone (l'arc par défaut de Material
/// fait un détour).
RectTween volEnLigneDroite(Rect? debut, Rect? fin) =>
    RectTween(begin: debut, end: fin);

/// La même photo, pour le moment agrandi (voir [TablGrilleMoments]).
class TablPhotoMoment extends StatelessWidget {
  const TablPhotoMoment({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) => _Photo(url: url);
}
