import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bouton_verre.dart';
import '../bulles_personnes.dart';
import '../publication.dart';
import 'grille_moments.dart';

/// Un moment agrandi depuis la grille d'un profil : la photo en grand
/// en haut (elle arrive de sa tuile, voir [TuileMoment.cleHero]), puis
/// le lieu, ceux qui étaient là, la légende, les impressions et les
/// actions habituelles.
///
/// Composant pur : tout arrive prêt à afficher, les gestes repartent par
/// callbacks. Le panneau du bas glisse en place en suivant l'animation
/// de la page qui l'affiche.
class TablVisionneuseMoment extends StatelessWidget {
  const TablVisionneuseMoment({
    super.key,
    required this.cleHero,
    required this.photoUrl,
    required this.restaurantNom,
    required this.details,
    required this.jaiReagi,
    required this.libelleReactions,
    required this.onReagir,
    required this.onCommenter,
    required this.onOuvrirLieu,
    required this.onFermer,
    this.emojiEmotion,
    this.bulles = const [],
    this.avecQui,
    this.legende,
    this.impressions = const [],
    this.enregistre = false,
    this.onEnregistrer,
    this.onOptions,
    this.audienceRestreinte = false,
  });

  final Object cleHero;
  final String? photoUrl;
  final String restaurantNom;

  /// "Liège · 16 octobre 2026 · Dîner".
  final String details;
  final String? emojiEmotion;
  final List<BullePersonne> bulles;

  /// "avec Arthur et Emma".
  final String? avecQui;

  /// Déjà entre guillemets.
  final String? legende;
  final List<String> impressions;
  final bool jaiReagi;
  final String libelleReactions;
  final bool enregistre;

  /// `null` : pas de bouton Enregistrer (son propre moment).
  final VoidCallback? onEnregistrer;
  final VoidCallback onReagir;
  final VoidCallback onCommenter;
  final VoidCallback onOuvrirLieu;
  final VoidCallback onFermer;

  /// Menu « ⋯ » (son propre moment) ; `null` : aucun.
  final VoidCallback? onOptions;
  final bool audienceRestreinte;

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final hauteurPhoto = math.min(taille.width * 1.08, taille.height * 0.56);
    final animation =
        ModalRoute.of(context)?.animation ?? kAlwaysCompleteAnimation;
    final arrivee = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
    );

    return Material(
      color: TablTokens.fond,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: hauteurPhoto,
                  child: Hero(
                    tag: cleHero,
                    createRectTween: volEnLigneDroite,
                    child: TablPhotoMoment(url: photoUrl),
                  ),
                ),
                FadeTransition(
                  opacity: arrivee,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(arrivee),
                    child: _Panneau(visionneuse: this),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: FadeTransition(
              opacity: arrivee,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TablTokens.espaceM,
                    vertical: TablTokens.espaceS,
                  ),
                  child: Row(
                    children: [
                      TablBoutonVerre(
                        icone: Icons.close_rounded,
                        libelle: 'Fermer',
                        onPresse: onFermer,
                      ),
                      const Spacer(),
                      if (onOptions != null)
                        TablBoutonVerre(
                          icone: Icons.more_horiz_rounded,
                          libelle: 'Options',
                          onPresse: onOptions!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panneau extends StatelessWidget {
  const _Panneau({required this.visionneuse});

  final TablVisionneuseMoment visionneuse;

  @override
  Widget build(BuildContext context) {
    final v = visionneuse;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        22,
        TablTokens.espaceL - 4,
        TablTokens.espaceXl + MediaQuery.paddingOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Voir ${v.restaurantNom}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: v.onOuvrirLieu,
                    child: Text(
                      v.restaurantNom,
                      style: TablTokens.titreAffichage.copyWith(
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ),
              if (v.emojiEmotion != null) ...[
                const SizedBox(width: TablTokens.espaceS),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TablTokens.surfaceBasse,
                    border: Border.all(
                      color: TablTokens.primaire.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    v.emojiEmotion!,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (v.audienceRestreinte) ...[
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: TablTokens.texteDoux,
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(
                  v.details,
                  style: TablTokens.legende.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          if (v.bulles.isNotEmpty) ...[
            const SizedBox(height: TablTokens.espaceM),
            Row(
              children: [
                TablBullesPersonnes(bulles: v.bulles, taille: 38),
                const SizedBox(width: 10),
                if (v.avecQui != null)
                  Expanded(
                    child: Text(
                      v.avecQui!,
                      style: TablTokens.corps.copyWith(
                        fontSize: 14,
                        color: TablTokens.texte.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (v.legende != null) ...[
            const SizedBox(height: 18),
            Text(
              v.legende!,
              style: TablTokens.titreAffichage.copyWith(
                fontSize: 20,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                height: 1.4,
                color: TablTokens.texte.withValues(alpha: 0.92),
              ),
            ),
          ],
          if (v.impressions.isNotEmpty) ...[
            const SizedBox(height: TablTokens.espaceM),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final impression in v.impressions)
                  TablPuceImpression(texte: impression),
              ],
            ),
          ],
          const SizedBox(height: 18),
          const Divider(height: 1, color: TablTokens.surface),
          const SizedBox(height: 10),
          TablActionsPublication(
            jaiReagi: v.jaiReagi,
            onReagir: v.onReagir,
            onCommenter: v.onCommenter,
            enregistre: v.enregistre,
            onEnregistrer: v.onEnregistrer,
          ),
          const SizedBox(height: 4),
          Text(v.libelleReactions, style: TablTokens.legende),
        ],
      ),
    );
  }
}
