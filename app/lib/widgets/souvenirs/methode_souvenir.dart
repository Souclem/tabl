import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';

/// Trois photos posées l'une sur l'autre, légèrement de biais : ses
/// propres photos quand on en a, des cadres vides sinon.
class TablPileDePhotos extends StatelessWidget {
  const TablPileDePhotos({super.key, this.urls = const [], this.hauteur = 120});

  /// Au plus trois, la première au-dessus.
  final List<String> urls;
  final double hauteur;

  @override
  Widget build(BuildContext context) {
    final largeur = hauteur * 0.78;
    // De la photo du fond à celle du dessus.
    const angles = [-0.16, 0.13, -0.02];
    const decalages = [-0.42, 0.42, 0.0];
    return SizedBox(
      height: hauteur + 16,
      width: largeur * 2.1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(decalages[i] * largeur, i == 2 ? -4 : 6),
              child: Transform.rotate(
                angle: angles[i],
                child: _Cadre(
                  url: 2 - i < urls.length ? urls[2 - i] : null,
                  largeur: largeur,
                  hauteur: hauteur,
                  teinte: i,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Cadre extends StatelessWidget {
  const _Cadre({
    required this.url,
    required this.largeur,
    required this.hauteur,
    required this.teinte,
  });

  final String? url;
  final double largeur;
  final double hauteur;
  final int teinte;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final vide = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(c.surface, c.primaire, 0.08 + 0.06 * teinte)!,
            c.surfaceBasse,
          ],
        ),
      ),
    );
    return Container(
      width: largeur,
      height: hauteur,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TablTokens.arrondiM - 2),
        border: Border.all(color: c.texte.withValues(alpha: 0.16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TablTokens.arrondiM - 3),
        child: url == null
            ? vide
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => vide,
              ),
      ),
    );
  }
}

/// La façon principale d'ajouter un souvenir : par ses photos. Une pile
/// de photos, un titre, ce que Tabl en fera, et le bouton pour les
/// choisir.
class TablCarteAjoutSouvenir extends StatelessWidget {
  const TablCarteAjoutSouvenir({
    super.key,
    required this.titre,
    required this.texte,
    required this.libelleBouton,
    required this.onChoisirPhotos,
    this.photosUrls = const [],
  });

  final String titre;
  final String texte;
  final String libelleBouton;
  final VoidCallback onChoisirPhotos;

  /// De quoi garnir la pile : ses dernières photos.
  final List<String> photosUrls;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
        TablTokens.espaceL - 4,
        TablTokens.espaceL - 4,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TablTokens.arrondiL + 4),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(c.surface, c.fond, 0.2)!, c.surfaceBasse],
        ),
        border: Border.all(color: c.texte.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: TablPileDePhotos(urls: photosUrls)),
          const SizedBox(height: TablTokens.espaceL),
          Text(
            titre,
            style: c.titreAffichage.copyWith(fontSize: 28, height: 1.15),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Text(
            texte,
            style: c.corps.copyWith(
              fontSize: 14,
              height: 1.45,
              color: c.texte.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: TablTokens.espaceL - 4),
          TablBouton(libelle: libelleBouton, onPresse: onChoisirPhotos),
        ],
      ),
    );
  }
}

/// Une autre façon d'ajouter des souvenirs, plus discrète, en ligne :
/// [mention] (« Bientôt ») tant qu'elle n'est pas disponible.
class TablMethodeSouvenir extends StatelessWidget {
  const TablMethodeSouvenir({
    super.key,
    required this.icone,
    required this.titre,
    required this.texte,
    this.mention,
    this.onPresse,
  });

  final IconData icone;
  final String titre;
  final String texte;
  final String? mention;

  /// `null` : pas encore disponible.
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final active = onPresse != null;
    return Semantics(
      button: true,
      enabled: active,
      child: GestureDetector(
        onTap: onPresse,
        child: Container(
          padding: const EdgeInsets.all(TablTokens.espaceM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TablTokens.arrondiL),
            border: Border.all(color: c.bordure),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surfaceBasse,
                ),
                child: Icon(
                  icone,
                  size: 19,
                  color: active ? c.texte : c.texteDoux,
                ),
              ),
              const SizedBox(width: TablTokens.espaceM - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: c.corps.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: active ? c.texte : c.texteDoux,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(texte, style: c.legende.copyWith(fontSize: 13)),
                  ],
                ),
              ),
              if (mention != null)
                Container(
                  margin: const EdgeInsets.only(left: TablTokens.espaceS),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceBasse,
                    borderRadius: BorderRadius.circular(
                      TablTokens.arrondiBouton,
                    ),
                  ),
                  child: Text(
                    mention!,
                    style: c.legende.copyWith(fontSize: 12),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: c.texteDoux),
            ],
          ),
        ),
      ),
    );
  }
}

/// Le petit bouton « ☾ Ajouter un souvenir » en tête de ses souvenirs.
class TablPiluleAjoutSouvenir extends StatelessWidget {
  const TablPiluleAjoutSouvenir({
    super.key,
    required this.libelle,
    required this.onPresse,
  });

  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: libelle,
      child: GestureDetector(
        onTap: onPresse,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
          decoration: BoxDecoration(
            color: c.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: Border.all(color: c.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nightlight_round, size: 15, color: c.texte),
              const SizedBox(width: TablTokens.espaceS),
              Text(
                libelle,
                style: c.corps.copyWith(fontSize: 14, color: c.texte),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un profil encore vide : une invitation à y ranger ses premiers
/// souvenirs, plutôt qu'un message d'absence.
class TablInvitationSouvenirs extends StatelessWidget {
  const TablInvitationSouvenirs({
    super.key,
    required this.titre,
    required this.texte,
    required this.libelleBouton,
    required this.onPresse,
  });

  final String titre;
  final String texte;
  final String libelleBouton;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
        TablTokens.espaceL - 4,
        TablTokens.espaceL - 4,
      ),
      decoration: BoxDecoration(
        color: c.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiL + 4),
        border: Border.all(color: c.texte.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: TablPileDePhotos(hauteur: 96)),
          const SizedBox(height: TablTokens.espaceL),
          Text(
            titre,
            style: c.titreAffichage.copyWith(fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Text(
            texte,
            style: c.corps.copyWith(
              fontSize: 14,
              height: 1.45,
              color: c.texte.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: TablTokens.espaceL - 4),
          TablBouton(libelle: libelleBouton, onPresse: onPresse),
        ],
      ),
    );
  }
}
