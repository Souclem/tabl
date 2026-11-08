import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Une personne montrée par sa tête, dans une bulle.
class BullePersonne {
  const BullePersonne({required this.pseudo, this.photoUrl, this.onPresse});

  final String pseudo;
  final String? photoUrl;

  /// Ouvre son profil ; `null` : pas touchable.
  final VoidCallback? onPresse;
}

/// Les têtes de plusieurs personnes, qui se chevauchent un peu — « avec
/// qui » se lit d'un coup d'œil, comme les « aimé par » d'Instagram. La
/// première est au-dessus des autres.
class TablBullesPersonnes extends StatelessWidget {
  const TablBullesPersonnes({
    super.key,
    required this.bulles,
    this.taille = 32,
  });

  final List<BullePersonne> bulles;

  /// Diamètre d'une bulle, contour compris.
  final double taille;

  @override
  Widget build(BuildContext context) {
    if (bulles.isEmpty) return const SizedBox.shrink();
    final pas = taille * 0.7;
    return SizedBox(
      width: taille + pas * (bulles.length - 1),
      height: taille,
      child: Stack(
        children: [
          // Peintes de la dernière à la première : la première recouvre
          // les suivantes.
          for (var i = bulles.length - 1; i >= 0; i--)
            Positioned(
              left: pas * i,
              child: _Bulle(bulle: bulles[i], taille: taille),
            ),
        ],
      ),
    );
  }
}

class _Bulle extends StatelessWidget {
  const _Bulle({required this.bulle, required this.taille});

  final BullePersonne bulle;
  final double taille;

  @override
  Widget build(BuildContext context) {
    final tete = Container(
      width: taille,
      height: taille,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: TablCouleurs.of(context).fond,
        shape: BoxShape.circle,
      ),
      child: TablAvatar(
        pseudo: bulle.pseudo,
        photoUrl: bulle.photoUrl,
        rayon: taille / 2 - 2,
      ),
    );
    return Semantics(
      button: bulle.onPresse != null,
      label: bulle.onPresse != null
          ? 'Voir le profil de ${bulle.pseudo}'
          : bulle.pseudo,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: bulle.onPresse,
        behavior: HitTestBehavior.opaque,
        child: tete,
      ),
    );
  }
}
