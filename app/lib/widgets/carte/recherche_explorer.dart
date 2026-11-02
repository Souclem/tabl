import 'package:flutter/material.dart';

import '../../theme/apparence.dart';
import '../../theme/tokens.dart';
import '../avatar.dart';
import 'tuile_lieu.dart';

/// Le titre d'une section de la recherche (« Restaurants de votre
/// cercle », « Ailleurs », « Vos proches »).
class TablTitreRecherche extends StatelessWidget {
  const TablTitreRecherche(this.titre, {super.key});

  final String titre;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
      child: Text(
        titre,
        style: TablTokens.legende.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: PaletteExplorer.of(context).texteDoux,
        ),
      ),
    );
  }
}

/// Une adresse trouvée : un point de la couleur de sa tuile, son nom, et
/// en dessous qui y va, la cuisine et la ville.
class TablLigneAdresse extends StatelessWidget {
  const TablLigneAdresse({
    super.key,
    required this.nom,
    required this.resume,
    required this.genre,
    required this.onPresse,
  });

  final String nom;
  final String resume;
  final GenreTuile genre;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    final point = switch (genre) {
      GenreTuile.cercle => palette.tuileCercle,
      GenreTuile.retour => palette.tuileRetour,
      GenreTuile.vous => palette.tuileVous,
    };
    return InkWell(
      onTap: onPresse,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.trait)),
        ),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: point,
                shape: BoxShape.circle,
                border: genre == GenreTuile.vous
                    ? Border.all(color: palette.texte, width: 1.5)
                    : null,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.corps.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.texte,
                    ),
                  ),
                  Text(
                    resume,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.legende.copyWith(
                      fontSize: 13,
                      color: palette.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un proche trouvé : sa tête, son prénom, et de quoi voir ses adresses.
class TablLigneProcheRecherche extends StatelessWidget {
  const TablLigneProcheRecherche({
    super.key,
    required this.pseudo,
    required this.onPresse,
    this.photoUrl,
  });

  final String pseudo;
  final String? photoUrl;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            TablAvatar(pseudo: pseudo, photoUrl: photoUrl, rayon: 18),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pseudo,
                    style: TablTokens.corps.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: palette.texte,
                    ),
                  ),
                  Text(
                    'Voir ses adresses',
                    style: TablTokens.legende.copyWith(
                      fontSize: 13,
                      color: palette.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
