import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'boutons.dart';

/// Ligne "Question ? Action" en bas d'un formulaire (ex. "Pas encore de
/// compte ? S'inscrire").
class TablLienBasDePage extends StatelessWidget {
  const TablLienBasDePage({
    super.key,
    required this.question,
    required this.libelleAction,
    this.onAction,
  });

  final String question;
  final String libelleAction;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: TablTokens.legende),
        TablBoutonTexte(libelle: libelleAction, onPresse: onAction),
      ],
    );
  }
}
