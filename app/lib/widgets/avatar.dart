import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// La photo de profil d'une personne, ronde ; l'initiale de son pseudo
/// si elle n'en a pas (ou si la photo ne charge pas).
class TablAvatar extends StatelessWidget {
  const TablAvatar({
    super.key,
    required this.pseudo,
    required this.photoUrl,
    this.rayon = 12,
  });

  final String pseudo;
  final String? photoUrl;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final initiale = pseudo.isEmpty ? '?' : pseudo[0].toUpperCase();
    final repli = Text(
      initiale,
      style: c.legende.copyWith(
        fontSize: rayon * 0.9,
        color: c.texteSurPrimaire,
        fontWeight: FontWeight.w700,
      ),
    );
    return CircleAvatar(
      radius: rayon,
      backgroundColor: c.primaire.withValues(alpha: 0.85),
      child: photoUrl == null
          ? repli
          : ClipOval(
              child: Image.network(
                photoUrl!,
                width: rayon * 2,
                height: rayon * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: repli),
              ),
            ),
    );
  }
}
