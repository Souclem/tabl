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

/// Le lien entre la pilule « Rechercher » de la barre et le champ de la
/// page de recherche : l'une glisse jusqu'à l'autre.
const Object heroRechercheExplorer = 'recherche-explorer';

/// La pilule ivoire de la recherche : une loupe, puis [contenu] (le mot
/// « Rechercher » dans la barre, le champ de saisie sur la page).
class TablPiluleRecherche extends StatelessWidget {
  const TablPiluleRecherche({super.key, required this.contenu});

  final Widget contenu;

  /// Telle qu'elle est dans la barre, pendant qu'elle glisse.
  static Widget enVol(
    BuildContext context,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext depuis,
    BuildContext vers,
  ) => Material(
    type: MaterialType.transparency,
    child: TablPiluleRecherche(
      contenu: Text(
        'Rechercher',
        maxLines: 1,
        overflow: TextOverflow.clip,
        softWrap: false,
        style: TablTokens.corps.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: TablTokens.encre,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: TablTokens.texte,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 21, color: TablTokens.encre),
          const SizedBox(width: 10),
          Expanded(child: contenu),
        ],
      ),
    );
  }
}

/// Le champ de la page de recherche, arrivé de la barre.
class TablChampRechercheExplorer extends StatelessWidget {
  const TablChampRechercheExplorer({
    super.key,
    required this.controleur,
    required this.onChanged,
    required this.indication,
  });

  final TextEditingController controleur;
  final ValueChanged<String> onChanged;

  /// "Une ville, un quartier, une adresse".
  final String indication;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: heroRechercheExplorer,
      flightShuttleBuilder: TablPiluleRecherche.enVol,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          height: 52,
          child: TablPiluleRecherche(
            contenu: TextField(
              controller: controleur,
              autofocus: true,
              autocorrect: false,
              onChanged: onChanged,
              cursorColor: TablTokens.encre,
              style: TablTokens.corps.copyWith(
                fontSize: 16,
                color: TablTokens.encre,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: indication,
                hintStyle: TablTokens.corps.copyWith(
                  fontSize: 16,
                  color: TablTokens.encrePale,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un endroit proposé par la recherche (une ville, un quartier, une
/// adresse, « Autour de moi »), ou la proposition de chercher des
/// restaurants par leur nom.
class TablLigneEndroit extends StatelessWidget {
  const TablLigneEndroit({
    super.key,
    required this.icone,
    required this.nom,
    required this.onPresse,
    this.detail,
    this.enAvant = false,
  });

  final IconData icone;
  final String nom;
  final String? detail;
  final VoidCallback onPresse;

  /// La proposition du haut (« Chercher les restaurants… ») : en gras.
  final bool enAvant;

  @override
  Widget build(BuildContext context) {
    final palette = PaletteExplorer.of(context);
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
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: palette.texte.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 17, color: palette.texte),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.corps.copyWith(
                      fontSize: 16,
                      fontWeight: enAvant ? FontWeight.w700 : FontWeight.w600,
                      color: palette.texte,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
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
