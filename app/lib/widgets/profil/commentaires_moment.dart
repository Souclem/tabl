import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';

/// Un commentaire prêt à afficher sous un moment agrandi.
class CommentaireAffiche {
  const CommentaireAffiche({
    required this.pseudo,
    required this.photoUrl,
    required this.texte,
    required this.quand,
    this.onSupprimer,
  });

  final String pseudo;
  final String? photoUrl;
  final String texte;

  /// "3 h", "hier", "12 mars".
  final String quand;

  /// `null` : pas le sien, rien à supprimer.
  final VoidCallback? onSupprimer;
}

/// Les commentaires d'un moment, à la suite du moment lui-même, puis le
/// champ pour en ajouter un : pas d'écran à part, on lit et on répond
/// sans quitter la photo.
///
/// Ne garde que l'état de sa saisie (texte en cours, envoi) ; publier
/// repart par [onEnvoyer].
class TablCommentairesMoment extends StatefulWidget {
  const TablCommentairesMoment({
    super.key,
    required this.titre,
    required this.commentaires,
    required this.onEnvoyer,
    this.focusNode,
  });

  /// "3 commentaires".
  final String titre;

  /// `null` pendant le chargement.
  final List<CommentaireAffiche>? commentaires;

  /// Publie le texte saisi ; `true` une fois publié, et le champ se vide.
  final Future<bool> Function(String texte) onEnvoyer;

  /// Pour que « Commenter » place directement le curseur dans le champ.
  final FocusNode? focusNode;

  @override
  State<TablCommentairesMoment> createState() => _TablCommentairesMomentState();
}

class _TablCommentairesMomentState extends State<TablCommentairesMoment> {
  final _texte = TextEditingController();
  bool _envoi = false;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final texte = _texte.text.trim();
    if (texte.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    final publie = await widget.onEnvoyer(texte);
    if (!mounted) return;
    setState(() => _envoi = false);
    if (publie) _texte.clear();
  }

  @override
  Widget build(BuildContext context) {
    final commentaires = widget.commentaires;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.titre, style: TablTokens.sousTitre),
        const SizedBox(height: TablTokens.espaceM),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: commentaires == null
              ? const SizedBox(
                  height: 48,
                  child: Center(
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TablTokens.primaire,
                      ),
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in commentaires) _LigneCommentaire(c),
                  ],
                ),
        ),
        const SizedBox(height: TablTokens.espaceS),
        TextField(
          controller: _texte,
          focusNode: widget.focusNode,
          enabled: !_envoi,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _envoyer(),
          style: TablTokens.corps,
          cursorColor: TablTokens.primaire,
          decoration: InputDecoration(
            hintText: 'Ajouter un commentaire…',
            hintStyle: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
            filled: true,
            fillColor: TablTokens.surfaceBasse,
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
            enabledBorder: _bord(TablTokens.bordure),
            disabledBorder: _bord(TablTokens.bordure),
            focusedBorder: _bord(TablTokens.primaire.withValues(alpha: 0.6)),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _envoi
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: TablTokens.primaire,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Publier le commentaire',
                      onPressed: _envoyer,
                      icon: const Icon(
                        Icons.arrow_upward_rounded,
                        color: TablTokens.primaire,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _bord(Color couleur) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(TablTokens.arrondiL),
    borderSide: BorderSide(color: couleur),
  );
}

class _LigneCommentaire extends StatelessWidget {
  const _LigneCommentaire(this.commentaire);

  final CommentaireAffiche commentaire;

  @override
  Widget build(BuildContext context) {
    final c = commentaire;
    final discret = TablTokens.legende.copyWith(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TablAvatar(pseudo: c.pseudo, photoUrl: c.photoUrl, rayon: 17),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.pseudo,
                  style: TablTokens.corps.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.texte,
                  style: TablTokens.corps.copyWith(fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(c.quand, style: discret),
                    if (c.onSupprimer != null) ...[
                      Text('  ·  ', style: discret),
                      Semantics(
                        button: true,
                        child: GestureDetector(
                          onTap: c.onSupprimer,
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'Supprimer',
                            style: discret.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
