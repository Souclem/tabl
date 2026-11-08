import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Un trait de séparation avec un texte centré ("Ou", "Déjà membre ?"...).
class TablSeparateurTexte extends StatelessWidget {
  const TablSeparateurTexte({
    super.key,
    required this.texte,
    this.espacementLettres,
  });

  final String texte;

  /// `letterSpacing` du texte, quand il doit être aéré (ex. petites
  /// majuscules). `null` garde l'espacement par défaut de `TablTokens.legende`.
  final double? espacementLettres;

  @override
  Widget build(BuildContext context) {
    final style = espacementLettres == null
        ? TablTokens.legende
        : TablTokens.legende.copyWith(letterSpacing: espacementLettres);

    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: TablTokens.espaceM,
          ),
          child: Text(texte, style: style),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
