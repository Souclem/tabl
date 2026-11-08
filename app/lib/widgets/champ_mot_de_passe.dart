import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'champ_texte.dart';

/// [TablChampTexte] spécialisé pour un mot de passe : icône cadenas et
/// bouton œil pour révéler/masquer la saisie déjà câblés.
///
/// La visibilité est un état purement visuel, pas une règle métier : elle
/// est tout de même laissée au parent (`visible` / `onToggleVisible`)
/// plutôt que gérée en interne, pour permettre à deux champs (mot de passe
/// + confirmation) de partager le même bouton œil, comme sur l'écran
/// d'inscription.
class TablChampMotDePasse extends StatelessWidget {
  const TablChampMotDePasse({
    super.key,
    required this.libelle,
    required this.controleur,
    required this.visible,
    required this.onToggleVisible,
    this.indication,
    this.erreur,
    this.actionClavier = TextInputAction.done,
    this.actif = true,
    this.onChanged,
    this.onSoumis,
  });

  final String libelle;
  final TextEditingController controleur;
  final bool visible;
  final VoidCallback onToggleVisible;
  final String? indication;
  final String? erreur;
  final TextInputAction actionClavier;
  final bool actif;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSoumis;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return TablChampTexte(
      libelle: libelle,
      controleur: controleur,
      indication: indication,
      erreur: erreur,
      masque: !visible,
      actionClavier: actionClavier,
      iconePrefixe: Icons.lock_outline_rounded,
      actif: actif,
      onChanged: onChanged,
      onSoumis: onSoumis,
      suffixe: IconButton(
        icon: Icon(
          visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 20,
          color: c.texteDoux,
        ),
        onPressed: onToggleVisible,
      ),
    );
  }
}
