import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';

/// Une façon d'ajouter des souvenirs (« Ajouter un souvenir », « Ajouter
/// plusieurs de manière intelligente »), en carte : un tap la choisit.
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

  /// Petite pastille en haut à droite (« Bientôt »).
  final String? mention;

  /// `null` : pas encore disponible, la carte est éteinte.
  final VoidCallback? onPresse;

  @override
  Widget build(BuildContext context) {
    final active = onPresse != null;
    return Semantics(
      button: true,
      enabled: active,
      child: GestureDetector(
        onTap: onPresse,
        child: Opacity(
          opacity: active ? 1 : 0.55,
          child: Container(
            padding: const EdgeInsets.all(TablTokens.espaceM + 2),
            decoration: BoxDecoration(
              color: TablTokens.surfaceBasse,
              borderRadius: BorderRadius.circular(TablTokens.arrondiL),
              border: Border.all(color: TablTokens.bordure),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: TablTokens.surface,
                  ),
                  child: Icon(icone, color: TablTokens.texte, size: 21),
                ),
                const SizedBox(width: TablTokens.espaceM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(titre, style: TablTokens.sousTitre),
                      const SizedBox(height: 2),
                      Text(texte, style: TablTokens.legende),
                    ],
                  ),
                ),
                const SizedBox(width: TablTokens.espaceS),
                if (mention != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: TablTokens.surface,
                      borderRadius: BorderRadius.circular(
                        TablTokens.arrondiBouton,
                      ),
                    ),
                    child: Text(
                      mention!,
                      style: TablTokens.legende.copyWith(fontSize: 12),
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: TablTokens.texteDoux,
                  ),
              ],
            ),
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
            color: TablTokens.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: Border.all(color: TablTokens.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.nightlight_round,
                size: 15,
                color: TablTokens.texte,
              ),
              const SizedBox(width: TablTokens.espaceS),
              Text(
                libelle,
                style: TablTokens.corps.copyWith(
                  fontSize: 14,
                  color: TablTokens.texte,
                ),
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
    return Container(
      padding: const EdgeInsets.all(TablTokens.espaceL - 4),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        border: Border.all(color: TablTokens.bordure),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titre,
            style: TablTokens.titreAffichage.copyWith(
              fontSize: 26,
              height: 1.2,
            ),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: TablTokens.texteDoux,
                ),
              ),
              const SizedBox(width: TablTokens.espaceS),
              Expanded(child: Text(texte, style: TablTokens.legende)),
            ],
          ),
          const SizedBox(height: TablTokens.espaceL - 4),
          TablBouton(libelle: libelleBouton, onPresse: onPresse),
        ],
      ),
    );
  }
}
