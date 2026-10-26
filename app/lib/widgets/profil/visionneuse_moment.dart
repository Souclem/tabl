import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bouton_verre.dart';
import '../bulles_personnes.dart';
import '../indicateur_page.dart';
import '../publication.dart';
import 'commentaires_moment.dart';
import 'grille_moments.dart';

/// Un moment agrandi depuis la grille d'un profil : la photo en grand
/// en haut (elle arrive de sa tuile, voir [TuileMoment.cleHero]) — les
/// suivantes d'un souvenir se font défiler du doigt —, puis
/// le lieu, ceux qui étaient là, la légende, les impressions, les
/// actions habituelles, puis les commentaires et de quoi en ajouter un
/// (« Commenter » y place directement le curseur).
///
/// Composant pur : tout arrive prêt à afficher, les gestes repartent par
/// callbacks. Le panneau du bas glisse en place en suivant l'animation
/// de la page qui l'affiche.
class TablVisionneuseMoment extends StatefulWidget {
  const TablVisionneuseMoment({
    super.key,
    required this.cleHero,
    required this.photoUrl,
    required this.restaurantNom,
    required this.details,
    required this.jaiReagi,
    required this.libelleReactions,
    required this.onReagir,
    required this.titreCommentaires,
    required this.commentaires,
    required this.onEnvoyerCommentaire,
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
    this.autresPhotosUrls = const [],
    this.estSouvenir = false,
  });

  final Object cleHero;
  final String? photoUrl;

  /// Après [photoUrl], dans l'ordre.
  final List<String> autresPhotosUrls;

  /// Un repas passé : « ☾ Souvenir » au-dessus du nom.
  final bool estSouvenir;
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

  /// "3 commentaires".
  final String titreCommentaires;

  /// `null` pendant le chargement.
  final List<CommentaireAffiche>? commentaires;

  /// `true` une fois le commentaire publié.
  final Future<bool> Function(String texte) onEnvoyerCommentaire;
  final VoidCallback onOuvrirLieu;
  final VoidCallback onFermer;

  /// Menu « ⋯ » (son propre moment) ; `null` : aucun.
  final VoidCallback? onOptions;
  final bool audienceRestreinte;

  @override
  State<TablVisionneuseMoment> createState() => _TablVisionneuseMomentState();
}

class _TablVisionneuseMomentState extends State<TablVisionneuseMoment> {
  final _focusCommentaire = FocusNode();

  /// La photo affichée, quand il y en a plusieurs.
  int _page = 0;

  @override
  void dispose() {
    _focusCommentaire.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget;
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: hauteurPhoto,
                  child: v.autresPhotosUrls.isEmpty
                      ? Hero(
                          tag: v.cleHero,
                          createRectTween: volEnLigneDroite,
                          child: TablPhotoMoment(url: v.photoUrl),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: Hero(
                                tag: v.cleHero,
                                createRectTween: volEnLigneDroite,
                                // Le vol montre la principale, celle de
                                // la tuile, quelle que soit la page.
                                flightShuttleBuilder: (_, _, _, _, _) =>
                                    TablPhotoMoment(url: v.photoUrl),
                                child: PageView(
                                  onPageChanged: (page) =>
                                      setState(() => _page = page),
                                  children: [
                                    TablPhotoMoment(url: v.photoUrl),
                                    for (final url in v.autresPhotosUrls)
                                      TablPhotoMoment(url: url),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: TablTokens.espaceM,
                              child: FadeTransition(
                                opacity: arrivee,
                                child: Center(
                                  child: TablIndicateurPage(
                                    total: v.autresPhotosUrls.length + 1,
                                    index: _page,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                FadeTransition(
                  opacity: arrivee,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.06),
                      end: Offset.zero,
                    ).animate(arrivee),
                    child: _Panneau(
                      visionneuse: v,
                      focusCommentaire: _focusCommentaire,
                    ),
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
                        onPresse: v.onFermer,
                      ),
                      const Spacer(),
                      if (v.onOptions != null)
                        TablBoutonVerre(
                          icone: Icons.more_horiz_rounded,
                          libelle: 'Options',
                          onPresse: v.onOptions!,
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
  const _Panneau({required this.visionneuse, required this.focusCommentaire});

  final TablVisionneuseMoment visionneuse;
  final FocusNode focusCommentaire;

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
          if (v.estSouvenir) ...[
            Row(
              children: [
                const Icon(
                  Icons.nightlight_round,
                  size: 13,
                  color: TablTokens.texteDoux,
                ),
                const SizedBox(width: 6),
                Text(
                  'SOUVENIR',
                  style: TablTokens.legende.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
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
            onCommenter: focusCommentaire.requestFocus,
            enregistre: v.enregistre,
            onEnregistrer: v.onEnregistrer,
          ),
          const SizedBox(height: 4),
          Text(v.libelleReactions, style: TablTokens.legende),
          const SizedBox(height: TablTokens.espaceL + 4),
          TablCommentairesMoment(
            titre: v.titreCommentaires,
            commentaires: v.commentaires,
            onEnvoyer: v.onEnvoyerCommentaire,
            focusNode: focusCommentaire,
          ),
        ],
      ),
    );
  }
}
