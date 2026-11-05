import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// CTA "+ Instant" — visible uniquement sur sa propre publication,
/// pendant la fenêtre de création (megaprompt Bloc 2, règle 3-4). Ne
/// disparaît jamais en griséé ni en countdown : soit il est affiché,
/// soit il ne l'est pas (l'écran appelant décide).
class TablBoutonAjouterInstant extends StatelessWidget {
  const TablBoutonAjouterInstant({super.key, required this.onPresse});

  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPresse,
      style: TextButton.styleFrom(
        foregroundColor: TablCouleurs.of(context).primaire,
        padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceXs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.add_circle_outline_rounded, size: 17),
      label: const Text(
        'Instant',
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
