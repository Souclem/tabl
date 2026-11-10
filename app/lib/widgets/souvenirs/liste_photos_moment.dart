import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une photo de « Photos du moment », prête à l'affichage.
typedef PhotoMomentAffichee = ({
  String id,
  ImageProvider image,

  /// « Couverture », « Photo 2 »…
  String titre,

  /// Gardée dans le brouillon mais pas publiée.
  bool retiree,
});

/// Les photos d'un moment, une par ligne : on les range en tirant la
/// poignée (la première est la couverture), on en retire une de la
/// publication sans la perdre, ou on la supprime. Les gestes n'ont pas de
/// libellé écrit : une icône, et son nom pour les lecteurs d'écran.
class TablListePhotosMoment extends StatelessWidget {
  const TablListePhotosMoment({
    super.key,
    required this.photos,
    required this.libelleRetirer,
    required this.libelleRemettre,
    required this.libelleSupprimer,
    required this.libellePhotoRetiree,
    required this.onReordonner,
    required this.onBasculerRetrait,
    required this.onSupprimer,
  });

  final List<PhotoMomentAffichee> photos;
  final String libelleRetirer;
  final String libelleRemettre;
  final String libelleSupprimer;

  /// Sous le titre d'une photo retirée (« Pas dans la publication »).
  final String libellePhotoRetiree;

  /// Une photo est passée de la place [ancienne] à la place [nouvelle]
  /// (déjà corrigée du retrait de la photo déplacée).
  final void Function(int ancienne, int nouvelle) onReordonner;
  final ValueChanged<String> onBasculerRetrait;
  final ValueChanged<String> onSupprimer;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: photos.length,
      onReorderItem: onReordonner,
      itemBuilder: (context, i) {
        final photo = photos[i];
        return Padding(
          key: ValueKey(photo.id),
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceXs),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(right: TablTokens.espaceS),
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    color: c.texteDoux,
                    semanticLabel: 'Déplacer ${photo.titre}',
                  ),
                ),
              ),
              Opacity(
                opacity: photo.retiree ? 0.4 : 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                  child: Image(
                    image: photo.image,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, erreur, pile) => SizedBox(
                      width: 56,
                      height: 56,
                      child: ColoredBox(color: c.surfaceBasse),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photo.titre,
                      style: c.corps.copyWith(
                        fontWeight: FontWeight.w600,
                        color: photo.retiree ? c.texteDoux : c.texte,
                      ),
                    ),
                    if (photo.retiree)
                      Text(libellePhotoRetiree, style: c.legende),
                  ],
                ),
              ),
              IconButton(
                tooltip: photo.retiree ? libelleRemettre : libelleRetirer,
                onPressed: () => onBasculerRetrait(photo.id),
                icon: Icon(
                  photo.retiree
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: photo.retiree ? c.primaire : c.texte,
                ),
              ),
              IconButton(
                tooltip: libelleSupprimer,
                onPressed: () => onSupprimer(photo.id),
                icon: Icon(Icons.delete_outline_rounded, color: c.erreur),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Un message bref avec un seul geste pour revenir en arrière
/// (« Photo supprimée · récupérable 30 jours » — « Annuler »), dans la
/// feuille elle-même : un message posé sous une feuille ne se verrait pas.
class TablBandeauAnnulation extends StatelessWidget {
  const TablBandeauAnnulation({
    super.key,
    required this.texte,
    required this.libelleAnnuler,
    required this.onAnnuler,
  });

  final String texte;
  final String libelleAnnuler;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: TablTokens.espaceM,
        vertical: TablTokens.espaceS,
      ),
      decoration: BoxDecoration(
        color: c.fond,
        borderRadius: BorderRadius.circular(TablTokens.arrondiS + 2),
        border: Border.all(color: c.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(texte, style: c.legende.copyWith(color: c.texte)),
          ),
          TextButton(
            onPressed: onAnnuler,
            child: Text(libelleAnnuler, style: TextStyle(color: c.primaire)),
          ),
        ],
      ),
    );
  }
}
