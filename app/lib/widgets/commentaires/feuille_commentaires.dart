import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'fil_commentaire.dart';

/// Les commentaires d'un moment dans une feuille qui monte par-dessus
/// l'écran, comme sur Instagram : la poignée et le titre en haut, les
/// fils qui défilent, le champ en bas, au-dessus du clavier. On la tire
/// vers le haut pour lire plus, vers le bas pour la fermer.
///
/// Composant pur : [controleurDefilement] vient de la feuille qui
/// l'accueille (c'est lui qui la fait suivre le doigt), les fils
/// arrivent prêts à afficher.
class TablFeuilleCommentaires extends StatelessWidget {
  const TablFeuilleCommentaires({
    super.key,
    required this.titre,
    required this.fils,
    required this.saisie,
    this.controleurDefilement,
  });

  /// "3 commentaires".
  final String titre;

  /// `null` pendant le chargement.
  final List<FilAffiche>? fils;

  /// Voir `TablSaisieCommentaire`.
  final Widget saisie;
  final ScrollController? controleurDefilement;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final fils = this.fils;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            controller: controleurDefilement,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // Dans le défilement : tirer l'en-tête tire la feuille.
              SliverPersistentHeader(
                pinned: true,
                delegate: _EnTete(titre: titre),
              ),
              if (fils == null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: c.primaire),
                  ),
                )
              else if (fils.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(TablTokens.espaceL),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Aucun commentaire pour l\'instant.',
                            style: c.titreAffichage.copyWith(fontSize: 20),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: TablTokens.espaceS),
                          Text('Lancez la conversation.', style: c.legende),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    TablTokens.espaceL - 4,
                    TablTokens.espaceS,
                    TablTokens.espaceS,
                    TablTokens.espaceM,
                  ),
                  sliver: SliverList.builder(
                    itemCount: fils.length,
                    itemBuilder: (_, i) => TablFilCommentaire(fil: fils[i]),
                  ),
                ),
            ],
          ),
        ),
        Divider(height: 1, color: c.bordure),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceM,
              TablTokens.espaceS,
              TablTokens.espaceM,
              TablTokens.espaceS,
            ),
            child: saisie,
          ),
        ),
      ],
    );
  }
}

class _EnTete extends SliverPersistentHeaderDelegate {
  const _EnTete({required this.titre});

  final String titre;

  static const _hauteur = 58.0;

  @override
  double get minExtent => _hauteur;

  @override
  double get maxExtent => _hauteur;

  @override
  bool shouldRebuild(_EnTete ancien) => ancien.titre != titre;

  @override
  Widget build(BuildContext context, double decalage, bool recouvre) {
    final c = TablCouleurs.of(context);
    return ColoredBox(
      color: c.surface,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: c.texteDoux.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(titre, style: c.corps.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          if (recouvre || decalage > 0) Divider(height: 1, color: c.bordure),
        ],
      ),
    );
  }
}
