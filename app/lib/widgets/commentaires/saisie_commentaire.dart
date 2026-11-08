import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le champ pour écrire un commentaire, et le publier. Quand on répond à
/// quelqu'un, une ligne le rappelle au-dessus, avec de quoi y renoncer.
///
/// Composant pur : le texte ([controleur]) et la réponse en cours
/// viennent de l'écran, l'envoi y repart.
class TablSaisieCommentaire extends StatelessWidget {
  const TablSaisieCommentaire({
    super.key,
    required this.controleur,
    required this.onEnvoyer,
    this.focusNode,
    this.enCours = false,
    this.enReponseA,
    this.onAnnulerReponse,
  });

  final TextEditingController controleur;
  final FocusNode? focusNode;
  final VoidCallback onEnvoyer;

  /// Le commentaire part : le champ attend.
  final bool enCours;

  /// Le pseudo de celui à qui l'on répond ; `null` : on commente le
  /// moment.
  final String? enReponseA;
  final VoidCallback? onAnnulerReponse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final destinataire = enReponseA;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (destinataire != null)
          Padding(
            padding: const EdgeInsets.only(
              left: TablTokens.espaceM,
              bottom: TablTokens.espaceXs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'En réponse à $destinataire',
                    overflow: TextOverflow.ellipsis,
                    style: c.legende.copyWith(fontSize: 13),
                  ),
                ),
                if (onAnnulerReponse != null)
                  IconButton(
                    tooltip: 'Ne plus répondre',
                    onPressed: onAnnulerReponse,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: c.texteDoux,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        TextField(
          controller: controleur,
          focusNode: focusNode,
          enabled: !enCours,
          minLines: 1,
          maxLines: 4,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => onEnvoyer(),
          style: c.corps,
          cursorColor: c.primaire,
          decoration: InputDecoration(
            hintText: destinataire == null
                ? 'Ajouter un commentaire…'
                : 'Votre réponse…',
            hintStyle: c.corps.copyWith(color: c.texteDoux),
            // La limite est là pour la base ; le compteur, lui, ne
            // ferait que du bruit.
            counterText: '',
            filled: true,
            fillColor: c.surfaceBasse,
            contentPadding: const EdgeInsets.fromLTRB(20, 14, 4, 14),
            enabledBorder: _bord(c.bordure),
            disabledBorder: _bord(c.bordure),
            focusedBorder: _bord(c.primaire.withValues(alpha: 0.6)),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: enCours
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: c.primaire,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Publier le commentaire',
                      onPressed: onEnvoyer,
                      icon: Icon(Icons.arrow_upward_rounded, color: c.primaire),
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
