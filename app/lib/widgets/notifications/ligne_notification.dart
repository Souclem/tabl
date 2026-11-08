import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';
import '../bulles_personnes.dart';

/// Une notification : la tête de qui l'a faite (deux têtes pour
/// plusieurs j'aime), la phrase — les noms en gras —, quand, et à droite
/// la vignette du moment concerné ou de quoi répondre à une demande.
/// Une notification nouvelle a un petit point doré.
///
/// Composant pur : la phrase arrive en morceaux prêts, les gestes
/// repartent par callbacks.
class TablLigneNotification extends StatelessWidget {
  const TablLigneNotification({
    super.key,
    required this.visages,
    required this.phrase,
    required this.quand,
    required this.onPresse,
    this.nouvelle = false,
    this.vignetteUrl,
    this.onAccepter,
    this.onRefuser,
    this.libelleAccepter = 'Accepter',
  });

  /// Une ou deux têtes.
  final List<BullePersonne> visages;

  /// Les morceaux de la phrase, les noms en gras.
  final List<({String texte, bool gras})> phrase;

  /// "3 h", "hier".
  final String quand;
  final bool nouvelle;

  /// La photo du moment concerné.
  final String? vignetteUrl;
  final VoidCallback onPresse;

  /// Une demande : de quoi y répondre (« Accepter » et « Refuser » pour
  /// un suivi, « Répondre » pour un avis).
  final VoidCallback? onAccepter;
  final VoidCallback? onRefuser;
  final String libelleAccepter;

  @override
  Widget build(BuildContext context) {
    final style = TablTokens.corps.copyWith(
      fontSize: 14,
      height: 1.35,
      color: TablTokens.texte.withValues(alpha: 0.86),
    );
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TablTokens.espaceL - 4,
          vertical: 10,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 44,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (visages.length > 1)
                    Positioned(
                      left: 12,
                      top: 10,
                      child: TablBullesPersonnes(
                        bulles: [visages[1]],
                        taille: 34,
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: TablBullesPersonnes(
                      bulles: [visages.first],
                      taille: visages.length > 1 ? 34 : 44,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final m in phrase)
                      TextSpan(
                        text: m.texte,
                        style: m.gras
                            ? style.copyWith(
                                fontWeight: FontWeight.w700,
                                color: TablTokens.texte,
                              )
                            : null,
                      ),
                    TextSpan(
                      text: '  $quand',
                      style: style.copyWith(
                        fontSize: 12.5,
                        color: TablTokens.texteDoux,
                      ),
                    ),
                  ],
                ),
                style: style,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (nouvelle) ...[
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: TablTokens.primaire,
                ),
              ),
            ],
            if (onAccepter != null) ...[
              const SizedBox(width: 10),
              TablPetitBouton(
                libelle: libelleAccepter,
                plein: true,
                onPresse: onAccepter,
              ),
              if (onRefuser != null) ...[
                const SizedBox(width: 6),
                TablPetitBouton(libelle: 'Refuser', onPresse: onRefuser),
              ],
            ] else if (vignetteUrl != null) ...[
              const SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                child: Image.network(
                  vignetteUrl!,
                  width: 46,
                  height: 46,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const SizedBox(width: 46, height: 46),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
