import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bouton_verre.dart';
import '../bulles_personnes.dart';
import 'explorer.dart';

/// Une petite étiquette de section, en capitales espacées
/// (« AVIS DU CERCLE »).
class TablEtiquetteFiche extends StatelessWidget {
  const TablEtiquetteFiche({
    super.key,
    required this.texte,
    this.doree = false,
  });

  final String texte;
  final bool doree;

  @override
  Widget build(BuildContext context) {
    return Text(
      texte.toUpperCase(),
      style: TablTokens.legende.copyWith(
        fontSize: 10.5,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        color: doree
            ? TablTokens.primaire
            : TablTokens.texte.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Une case de la fiche : un fond sombre, un léger trait.
class _Case extends StatelessWidget {
  const _Case({required this.child, this.onPresse, this.remplissage});

  final Widget child;
  final VoidCallback? onPresse;
  final EdgeInsets? remplissage;

  @override
  Widget build(BuildContext context) {
    final contenu = Container(
      padding: remplissage ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121318),
        borderRadius: BorderRadius.circular(TablTokens.arrondiM + 2),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.07)),
      ),
      child: child,
    );
    if (onPresse == null) return contenu;
    return GestureDetector(onTap: onPresse, child: contenu);
  }
}

/// Le bandeau nuit, haut de la fiche : la photo en grand sous un voile qui
/// se fond dans la nuit, le retour, le marque-page, le nom et où c'est ;
/// une mention dorée quand c'est l'une de mes adresses.
class TablHerosFiche extends StatelessWidget {
  const TablHerosFiche({
    super.key,
    required this.nom,
    required this.sousTitre,
    required this.photoUrl,
    required this.onRetour,
    this.mention,
    this.onMarquePage,
    this.gardee = false,
  });

  final String nom;

  /// "Liège · 19 rue Hors-Château".
  final String sousTitre;
  final String? photoUrl;

  /// "Votre adresse · 7 fois".
  final String? mention;
  final VoidCallback onRetour;

  /// Garde ou retire l'adresse de mes envies ; `null` : pas de marque-page.
  final VoidCallback? onMarquePage;

  /// L'adresse est dans mes envies : marque-page plein et doré.
  final bool gardee;

  @override
  Widget build(BuildContext context) {
    final haut = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: 300 + haut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TablPhotoLieu(
            nom: nom,
            url: photoUrl,
            taille: null,
            rayon: 0,
            tailleLettre: 140,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.3, 0.62, 1],
                colors: [
                  Color(0x8C000000),
                  Color(0x00000000),
                  Color(0x33000000),
                  TablTokens.fond,
                ],
              ),
            ),
          ),
          Positioned(
            top: haut + TablTokens.espaceS,
            left: TablTokens.espaceM,
            child: TablBoutonVerre(
              icone: Icons.arrow_back_rounded,
              libelle: 'Retour',
              onPresse: onRetour,
            ),
          ),
          if (onMarquePage != null)
            Positioned(
              top: haut + TablTokens.espaceS,
              right: TablTokens.espaceM,
              child: TablBoutonVerre(
                icone: gardee
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                libelle: gardee
                    ? 'Retirer de mes envies'
                    : 'Garder pour plus tard',
                doree: gardee,
                onPresse: onMarquePage!,
              ),
            ),
          Positioned(
            left: TablTokens.espaceL - 4,
            right: TablTokens.espaceL - 4,
            bottom: TablTokens.espaceM,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mention != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        TablTokens.arrondiBouton,
                      ),
                      color: const Color(0x66000000),
                      border: Border.all(
                        color: TablTokens.primaire.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      mention!.toUpperCase(),
                      style: TablTokens.legende.copyWith(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        color: TablTokens.primaire,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(
                  nom,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TablTokens.titreAffichage.copyWith(
                    fontSize: 36,
                    height: 1.05,
                    letterSpacing: -0.6,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 14),
                    ],
                  ),
                ),
                if (sousTitre.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    sousTitre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.legende.copyWith(
                      fontSize: 13.5,
                      color: TablTokens.texte.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Une action de la fiche (« Garder », « Proposer », « Carte ») : une
/// icône au-dessus de son nom.
class ActionFiche {
  const ActionFiche({
    required this.icone,
    required this.libelle,
    required this.onPresse,
    this.active = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onPresse;

  /// Déjà faite (« Gardée ») : dorée.
  final bool active;
}

class TablActionsFiche extends StatelessWidget {
  const TablActionsFiche({super.key, required this.actions});

  final List<ActionFiche> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              label: actions[i].libelle,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: actions[i].onPresse,
                child: Container(
                  height: 58,
                  decoration: BoxDecoration(
                    color: actions[i].active
                        ? TablTokens.primaire.withValues(alpha: 0.12)
                        : const Color(0xFF121318),
                    borderRadius: BorderRadius.circular(TablTokens.arrondiM),
                    border: Border.all(
                      color: actions[i].active
                          ? TablTokens.primaire.withValues(alpha: 0.45)
                          : TablTokens.texte.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        actions[i].icone,
                        size: 18,
                        color: actions[i].active
                            ? TablTokens.primaire
                            : TablTokens.texte,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        actions[i].libelle,
                        style: TablTokens.legende.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: actions[i].active
                              ? TablTokens.primaire
                              : TablTokens.texte,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// L'avis du cercle (« 4,7 / 5 😍 »), à gauche, et à droite qui le
/// connaît et qui y retourne.
class TablAvisCercle extends StatelessWidget {
  const TablAvisCercle({
    super.key,
    required this.note,
    required this.emoji,
    required this.detailAvis,
    required this.connaissent,
    required this.visagesConnaissent,
    required this.yRetournent,
    required this.onConnaissent,
    required this.onYRetournent,
  });

  /// "4,7", `null` sans avis.
  final String? note;
  final String? emoji;

  /// "3 avis · 1 passage sans avis".
  final String detailAvis;
  final int connaissent;
  final List<BullePersonne> visagesConnaissent;
  final int yRetournent;
  final VoidCallback? onConnaissent;
  final VoidCallback? onYRetournent;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Case(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const TablEtiquetteFiche(
                    texte: 'Avis du cercle',
                    doree: true,
                  ),
                  const Spacer(),
                  if (note != null)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          note!,
                          style: TablTokens.titreAffichage.copyWith(
                            fontSize: 42,
                            height: 1,
                          ),
                        ),
                        Text(
                          ' / 5',
                          style: TablTokens.legende.copyWith(fontSize: 14),
                        ),
                        if (emoji != null) ...[
                          const SizedBox(width: 6),
                          Text(emoji!, style: const TextStyle(fontSize: 20)),
                        ],
                      ],
                    )
                  else
                    Text(
                      'Pas encore d\'avis',
                      style: TablTokens.titreAffichage.copyWith(fontSize: 20),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    detailAvis,
                    style: TablTokens.legende.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _Case(
                    onPresse: onConnaissent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$connaissent',
                              style: TablTokens.titreAffichage.copyWith(
                                fontSize: 24,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            TablEtiquetteFiche(
                              texte: connaissent == 1
                                  ? 'connaît'
                                  : 'connaissent',
                            ),
                          ],
                        ),
                        if (visagesConnaissent.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              TablBullesPersonnes(
                                bulles: visagesConnaissent,
                                taille: 22,
                              ),
                              const Spacer(),
                              if (onConnaissent != null)
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: TablTokens.texteDoux,
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _Case(
                    onPresse: onYRetournent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$yRetournent',
                              style: TablTokens.titreAffichage.copyWith(
                                fontSize: 24,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 6),
                            TablEtiquetteFiche(
                              texte: yRetournent == 1
                                  ? 'y retourne'
                                  : 'y retournent',
                            ),
                          ],
                        ),
                        if (onYRetournent != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Voir qui',
                                style: TablTokens.legende.copyWith(
                                  fontSize: 12.5,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: TablTokens.texteDoux,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
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

/// « Première découverte » : qui de mon cercle y est allé le premier.
class TablPremiereDecouverte extends StatelessWidget {
  const TablPremiereDecouverte({
    super.key,
    required this.visage,
    required this.annee,
    this.onPresse,
  });

  final BullePersonne visage;
  final String annee;
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    return _Case(
      onPresse: onPresse,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: TablTokens.primaire.withValues(alpha: 0.5),
              ),
            ),
            child: const Icon(
              Icons.explore_outlined,
              size: 17,
              color: TablTokens.primaire,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TablEtiquetteFiche(
                  texte: 'Première découverte',
                  doree: true,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    TablBullesPersonnes(bulles: [visage], taille: 22),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        visage.pseudo,
                        overflow: TextOverflow.ellipsis,
                        style: TablTokens.titreAffichage.copyWith(fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            annee,
            style: TablTokens.titreAffichage.copyWith(
              fontSize: 15,
              letterSpacing: 1,
              color: TablTokens.primaire.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mon histoire ici : combien de fois, depuis quand je n'y suis pas
/// retourné — ou « Pas encore dans votre histoire ».
class TablMonHistoireFiche extends StatelessWidget {
  const TablMonHistoireFiche({
    super.key,
    required this.fois,
    required this.depuis,
    required this.detail,
  });

  final int fois;

  /// ("2", "mois") depuis la dernière fois ; `null` : aujourd'hui.
  final ({String nombre, String unite})? depuis;

  /// "Depuis janvier 2026 · dernière fois le 21 août 2026".
  final String detail;

  @override
  Widget build(BuildContext context) {
    if (fois == 0) {
      return _Case(
        child: Text(
          'Pas encore dans votre histoire.',
          style: TablTokens.corps.copyWith(
            fontSize: 14,
            color: TablTokens.texte.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    final d = depuis;
    return _Case(
      remplissage: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$fois',
                      style: TablTokens.titreAffichage.copyWith(
                        fontSize: 30,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const TablEtiquetteFiche(texte: 'fois ici'),
                  ],
                ),
                const SizedBox(width: 16),
                VerticalDivider(
                  width: 1,
                  color: TablTokens.texte.withValues(alpha: 0.12),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d == null ? 'Aujourd\'hui' : '${d.nombre} ${d.unite}',
                        style: TablTokens.titreAffichage.copyWith(
                          fontSize: 30,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TablEtiquetteFiche(
                        texte: d == null
                            ? 'votre dernière fois'
                            : 'depuis votre dernière fois',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(detail, style: TablTokens.legende.copyWith(fontSize: 12.5)),
          ],
        ],
      ),
    );
  }
}

/// « Ce qui ressort » : chaque impression, combien de fois elle a été
/// dite, et un trait doré à sa mesure.
class TablCeQuiRessort extends StatelessWidget {
  const TablCeQuiRessort({super.key, required this.impressions});

  final List<({String libelle, int fois})> impressions;

  @override
  Widget build(BuildContext context) {
    final max = impressions.isEmpty
        ? 1
        : impressions.map((i) => i.fois).reduce((a, b) => a > b ? a : b);
    return Column(
      children: [
        for (final i in impressions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.libelle,
                        style: TablTokens.corps.copyWith(
                          fontSize: 14,
                          color: TablTokens.texte,
                        ),
                      ),
                    ),
                    Text(
                      i.fois == 1 ? '1 fois' : '${i.fois} fois',
                      style: TablTokens.legende.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: i.fois / max,
                    minHeight: 2,
                    color: TablTokens.primaire,
                    backgroundColor: TablTokens.texte.withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
