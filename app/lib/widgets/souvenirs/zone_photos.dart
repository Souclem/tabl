import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'apercu_photos.dart';

/// Les photos d'un souvenir ou d'un moment en cours de création (ou de
/// modification) : en grand, la photo regardée — « ★ Principale » et
/// « Retirer » posés dessus, quand on peut les ranger —, les vignettes
/// dessous. Après la dernière photo, on glisse sur une page pour en
/// ajouter une ; la vignette « + » y mène aussi. Sans photo, toute la
/// place est à cette page d'ajout.
///
/// Composant pur : la page affichée et les photos viennent de l'écran,
/// les gestes y repartent.
class TablZonePhotos extends StatelessWidget {
  const TablZonePhotos({
    super.key,
    required this.photos,
    required this.page,
    required this.hauteur,
    required this.onPage,
    required this.actionsAjout,
    this.onRendrePrincipale,
    this.onRetirer,
    this.titreAjout,
  });

  /// La première est la principale.
  final List<ImageProvider> photos;

  /// La page affichée ; `photos.length` : celle d'ajout.
  final int page;
  final double hauteur;
  final ValueChanged<int> onPage;

  /// `null` : les photos ne se rangent pas (« ★ Principale » absent).
  final VoidCallback? onRendrePrincipale;

  /// `null` : les photos ne se retirent pas.
  final VoidCallback? onRetirer;

  /// Les façons d'ajouter une photo ; vide : il n'y a plus de place.
  final List<ActionAjoutPhoto> actionsAjout;

  /// Sur la page d'ajout, avant la première photo : « Le plat, la
  /// table, la tablée ». Après, c'est « Une autre photo ? ».
  final String? titreAjout;

  @override
  Widget build(BuildContext context) {
    final ajout = actionsAjout.isEmpty
        ? null
        : TablApercuSansPhoto(
            actions: actionsAjout,
            titre: photos.isEmpty ? titreAjout : 'Une autre photo ?',
          );
    final surUnePhoto = page < photos.length;
    final principale = page > 0 ? onRendrePrincipale : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: hauteur,
          child: photos.isEmpty
              ? ajout ?? const SizedBox.shrink()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    TablApercuPhotos(
                      photos: photos,
                      page: page,
                      onPage: onPage,
                      pageAjout: ajout,
                    ),
                    if (surUnePhoto &&
                        (principale != null || onRetirer != null))
                      Positioned(
                        right: TablTokens.espaceM,
                        bottom: TablTokens.espaceL + 22,
                        child: Row(
                          children: [
                            if (principale != null)
                              TablPiluleVerre(
                                icone: Icons.star_rounded,
                                libelle: 'Principale',
                                onPresse: principale,
                              ),
                            if (principale != null && onRetirer != null)
                              const SizedBox(width: TablTokens.espaceS),
                            if (onRetirer != null)
                              TablPiluleVerre(
                                icone: Icons.delete_outline_rounded,
                                libelle: 'Retirer',
                                onPresse: onRetirer,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        if (photos.length > 1 || (photos.isNotEmpty && ajout != null)) ...[
          const SizedBox(height: TablTokens.espaceXs),
          TablBandeVignettes(
            photos: photos,
            page: page,
            onChoisir: onPage,
            onAjouter: ajout == null ? null : () => onPage(photos.length),
          ),
        ],
      ],
    );
  }
}
