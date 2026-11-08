import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Champ de saisie de Tabl.
///
/// Composant PUR : il affiche ce qu'on lui donne et signale les frappes.
/// Il ne valide rien lui-même — le message d'erreur lui est fourni tout
/// prêt via [erreur], parce que décider qu'un e-mail est invalide est une
/// règle métier, pas une question d'apparence.
class TablChampTexte extends StatelessWidget {
  const TablChampTexte({
    super.key,
    required this.libelle,
    this.controleur,
    this.indication,
    this.erreur,
    this.masque = false,
    this.typeClavier,
    this.actionClavier,
    this.iconePrefixe,
    this.suffixe,
    this.onChanged,
    this.onSoumis,
    this.actif = true,
    this.lignes = 1,
  });

  /// Libellé affiché au-dessus du champ.
  final String libelle;

  final TextEditingController? controleur;

  /// Texte gris affiché tant que le champ est vide.
  final String? indication;

  /// Message d'erreur à afficher sous le champ. `null` = pas d'erreur.
  final String? erreur;

  /// Masque la saisie (mot de passe).
  final bool masque;

  final TextInputType? typeClavier;
  final TextInputAction? actionClavier;
  final IconData? iconePrefixe;

  /// Widget affiché à droite dans le champ (ex : œil pour révéler
  /// le mot de passe).
  final Widget? suffixe;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSoumis;
  final bool actif;

  /// Nombre de lignes du champ. `1` (défaut) = champ simple ; plus pour
  /// une zone de texte multiligne (ex. une légende).
  final int lignes;

  @override
  Widget build(BuildContext context) {
    final enErreur = erreur != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sans libellé (le titre autour dit déjà ce qu'on y tape) : pas
        // d'espace vide au-dessus du champ.
        if (libelle.isNotEmpty) ...[
          Text(libelle, style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
        ],
        TextField(
          controller: controleur,
          obscureText: masque,
          keyboardType: typeClavier,
          textInputAction: actionClavier,
          enabled: actif,
          style: TablTokens.corps,
          onChanged: onChanged,
          onSubmitted: onSoumis,
          maxLines: lignes,
          decoration: InputDecoration(
            hintText: indication,
            hintStyle: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
            filled: true,
            fillColor: TablTokens.surface,
            prefixIcon: iconePrefixe != null
                ? Icon(iconePrefixe, size: 20, color: TablTokens.texteDoux)
                : null,
            suffixIcon: suffixe,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceM,
              vertical: TablTokens.espaceM,
            ),
            enabledBorder: _bordure(
              enErreur ? TablTokens.erreur : TablTokens.bordure,
            ),
            focusedBorder: _bordure(
              enErreur ? TablTokens.erreur : TablTokens.primaire,
              epaisseur: 2,
            ),
            disabledBorder: _bordure(TablTokens.bordure),
            border: _bordure(TablTokens.bordure),
            // On gère l'erreur nous-mêmes en dessous, pour maîtriser
            // l'espacement et le style.
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (enErreur) ...[
          const SizedBox(height: TablTokens.espaceXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 14,
                color: TablTokens.erreur,
              ),
              const SizedBox(width: TablTokens.espaceXs),
              Expanded(
                child: Text(
                  erreur!,
                  style: TablTokens.legende.copyWith(color: TablTokens.erreur),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _bordure(Color couleur, {double epaisseur = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(TablTokens.arrondiS),
      borderSide: BorderSide(color: couleur, width: epaisseur),
    );
  }
}
