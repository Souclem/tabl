import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Les onglets de la barre de navigation principale.
enum TablOnglet { feed, explorer, wishlist, profil }

/// Barre de navigation en bas de l'app connectée : Feed, Explorer, un
/// bouton central de publication, Wishlist et Profil.
///
/// Composant pur : reçoit l'onglet actif et des callbacks, ne décide rien.
class TablBarreNavigation extends StatelessWidget {
  const TablBarreNavigation({
    super.key,
    required this.ongletActif,
    required this.onSelection,
    required this.onPublier,
  });

  final TablOnglet ongletActif;
  final ValueChanged<TablOnglet> onSelection;
  final VoidCallback onPublier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: TablTokens.espaceS),
      decoration: BoxDecoration(
        color: TablTokens.surface,
        border: Border(top: BorderSide(color: TablTokens.bordure)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _item(TablOnglet.feed, Icons.home_outlined, 'Feed'),
              _item(TablOnglet.explorer, Icons.explore_outlined, 'Explorer'),
              _boutonPublier(),
              _item(
                TablOnglet.wishlist,
                Icons.bookmark_border_rounded,
                'Wishlist',
              ),
              _item(
                TablOnglet.profil,
                Icons.person_outline_rounded,
                'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(TablOnglet onglet, IconData icone, String libelle) {
    final actif = onglet == ongletActif;
    final couleur = actif ? TablTokens.primaire : TablTokens.texteDoux;

    return Expanded(
      child: InkWell(
        onTap: () => onSelection(onglet),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 21, color: couleur),
            const SizedBox(height: 4),
            Text(
              libelle,
              style: TablTokens.legende.copyWith(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonPublier() {
    return SizedBox(
      width: 64,
      child: Center(
        child: InkWell(
          onTap: onPublier,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: TablTokens.primaire,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_rounded,
              color: TablTokens.texteSurPrimaire,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
