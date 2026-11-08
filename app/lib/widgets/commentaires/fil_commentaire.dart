import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';
import '../bouton_reaction.dart';

/// Un commentaire prêt à afficher.
class CommentaireAffiche {
  const CommentaireAffiche({
    required this.pseudo,
    required this.texte,
    required this.quand,
    required this.onAimer,
    required this.onRepondre,
    this.photoUrl,
    this.jaiAime = false,
    this.libelleJaime,
    this.onSupprimer,
    this.onTapAuteur,
  });

  final String pseudo;
  final String? photoUrl;
  final String texte;

  /// "3 h", "hier", "12 mars".
  final String quand;

  final bool jaiAime;

  /// "3 j'aime" ; `null` : personne ne l'a aimé.
  final String? libelleJaime;

  final VoidCallback onAimer;
  final VoidCallback onRepondre;

  /// `null` : pas le sien, rien à supprimer.
  final VoidCallback? onSupprimer;

  /// Ouvre le profil de l'auteur ; `null` : pas touchable.
  final VoidCallback? onTapAuteur;
}

/// Un commentaire et ses réponses, prêts à afficher.
class FilAffiche {
  const FilAffiche({
    required this.commentaire,
    this.reponses = const [],
    this.reponsesVisibles = false,
    this.libelleVoirReponses,
    this.onBasculerReponses,
  });

  final CommentaireAffiche commentaire;
  final List<CommentaireAffiche> reponses;

  /// Les réponses sont dépliées.
  final bool reponsesVisibles;

  /// "Voir les 3 réponses" ; `null` : aucune réponse.
  final String? libelleVoirReponses;
  final VoidCallback? onBasculerReponses;
}

/// Un commentaire, puis ses réponses en retrait — repliées derrière
/// « Voir les 3 réponses » tant qu'on ne les demande pas, comme sur
/// Instagram. Chacun s'aime, et l'on répond à chacun.
///
/// Composant pur : ce qui est déplié vient de l'écran, les gestes y
/// repartent.
class TablFilCommentaire extends StatelessWidget {
  const TablFilCommentaire({super.key, required this.fil});

  final FilAffiche fil;

  /// Le retrait des réponses : sous le texte du commentaire, pas sous sa
  /// tête.
  static const _retrait = 46.0;

  @override
  Widget build(BuildContext context) {
    final couleurs = TablCouleurs.of(context);
    final libelle = fil.libelleVoirReponses;
    final basculer = fil.onBasculerReponses;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LigneCommentaire(commentaire: fil.commentaire),
        if (libelle != null && basculer != null)
          Padding(
            padding: const EdgeInsets.only(left: _retrait, bottom: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _LienDiscret(
                // Le trait rappelle Instagram : ce qui suit en dépend.
                avant: Container(
                  width: 24,
                  height: 1,
                  margin: const EdgeInsets.only(right: TablTokens.espaceS),
                  color: couleurs.texteDoux.withValues(alpha: 0.5),
                ),
                texte: fil.reponsesVisibles ? 'Masquer les réponses' : libelle,
                onPresse: basculer,
              ),
            ),
          ),
        if (fil.reponsesVisibles)
          for (final reponse in fil.reponses)
            Padding(
              padding: const EdgeInsets.only(left: _retrait),
              child: _LigneCommentaire(commentaire: reponse, reponse: true),
            ),
      ],
    );
  }
}

class _LigneCommentaire extends StatelessWidget {
  const _LigneCommentaire({required this.commentaire, this.reponse = false});

  final CommentaireAffiche commentaire;

  /// Une réponse : un peu plus petite.
  final bool reponse;

  @override
  Widget build(BuildContext context) {
    final c = commentaire;
    final couleurs = TablCouleurs.of(context);
    final discret = couleurs.legende.copyWith(fontSize: 12.5);
    final libelleJaime = c.libelleJaime;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: c.onTapAuteur != null,
            label: c.onTapAuteur != null
                ? 'Voir le profil de ${c.pseudo}'
                : c.pseudo,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: c.onTapAuteur,
              behavior: HitTestBehavior.opaque,
              child: TablAvatar(
                pseudo: c.pseudo,
                photoUrl: c.photoUrl,
                rayon: reponse ? 13 : 17,
              ),
            ),
          ),
          SizedBox(width: reponse ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: c.pseudo,
                        style: couleurs.corps.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: '  ${c.quand}', style: discret),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.texte,
                  style: couleurs.corps.copyWith(fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (libelleJaime != null) ...[
                      Text(
                        libelleJaime,
                        style: discret.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: TablTokens.espaceM),
                    ],
                    _LienDiscret(texte: 'Répondre', onPresse: c.onRepondre),
                    if (c.onSupprimer != null) ...[
                      const SizedBox(width: TablTokens.espaceM),
                      _LienDiscret(
                        texte: 'Supprimer',
                        onPresse: c.onSupprimer!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Les mêmes verres qui trinquent que sur un moment, en petit.
          TablBoutonReaction(actif: c.jaiAime, onPresse: c.onAimer, taille: 18),
        ],
      ),
    );
  }
}

/// Un petit texte gris qui se touche : « Répondre », « Supprimer »,
/// « Voir les 3 réponses ».
class _LienDiscret extends StatelessWidget {
  const _LienDiscret({required this.texte, required this.onPresse, this.avant});

  final String texte;
  final VoidCallback onPresse;
  final Widget? avant;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // Une zone de tap plus haute que le texte.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ?avant,
              Text(
                texte,
                style: c.legende.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
