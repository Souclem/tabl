import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';
import '../boutons.dart';

/// Une suggestion prête à afficher.
class SuggestionAffichee {
  const SuggestionAffichee({
    required this.pseudo,
    required this.raison,
    required this.libelleBouton,
    required this.onOuvrir,
    this.photoUrl,
    this.boutonPlein = true,
    this.onBouton,
    this.onEcarter,
  });

  final String pseudo;
  final String? photoUrl;

  /// « Vous suit », « Suivi par emma et 2 autres ».
  final String raison;

  /// « Suivre », « Suivre en retour », puis « Abonné »…
  final String libelleBouton;

  /// Plein tant qu'on ne la suit pas encore.
  final bool boutonPlein;

  /// `null` : le bouton attend (une action est en cours).
  final VoidCallback? onBouton;

  /// Le « ✕ » ; `null` : pas de croix.
  final VoidCallback? onEcarter;

  /// Ouvre son profil.
  final VoidCallback onOuvrir;
}

/// « Vous les connaissez peut-être » : des vignettes qui défilent de
/// côté, chacune avec sa tête, pourquoi on la propose, de quoi la suivre
/// et la croix pour ne plus la voir. Dans le Feed, le Feed vide et
/// l'écran Abonnés.
///
/// Composant pur : les suggestions arrivent prêtes à afficher, les
/// gestes repartent par leurs callbacks.
class TablCarteSuggestions extends StatelessWidget {
  const TablCarteSuggestions({
    super.key,
    required this.suggestions,
    this.titre = 'Vous les connaissez peut-être',
  });

  final List<SuggestionAffichee> suggestions;
  final String titre;

  static const double _largeurVignette = 152;
  static const double _hauteurVignette = 214;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            0,
            TablTokens.espaceL - 4,
            TablTokens.espaceS + 4,
          ),
          child: Text(titre, style: c.titreAffichage.copyWith(fontSize: 19)),
        ),
        SizedBox(
          height: _hauteurVignette,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceL - 4,
            ),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(
              width: _largeurVignette,
              child: _Vignette(suggestion: suggestions[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette({required this.suggestion});

  final SuggestionAffichee suggestion;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final c = TablCouleurs.of(context);
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        side: BorderSide(color: c.bordure),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: s.onOuvrir,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 12),
              child: Column(
                children: [
                  TablAvatar(pseudo: s.pseudo, photoUrl: s.photoUrl, rayon: 34),
                  const SizedBox(height: 10),
                  Text(
                    s.pseudo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: c.corps.copyWith(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.raison,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: c.legende.copyWith(fontSize: 12, height: 1.3),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: TablPetitBouton(
                      libelle: s.libelleBouton,
                      plein: s.boutonPlein,
                      onPresse: s.onBouton,
                    ),
                  ),
                ],
              ),
            ),
            if (s.onEcarter != null)
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  tooltip: 'Ne plus suggérer',
                  visualDensity: VisualDensity.compact,
                  onPressed: s.onEcarter,
                  icon: Icon(Icons.close_rounded, size: 16, color: c.texteDoux),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
