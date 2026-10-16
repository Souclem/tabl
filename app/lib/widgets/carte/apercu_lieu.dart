import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// L'aperçu d'un lieu touché sur la carte, posé en bas de l'écran. La
/// fiche complète du restaurant viendra plus tard ; ici, l'essentiel et
/// l'envie.
class TablApercuLieu extends StatelessWidget {
  const TablApercuLieu({
    super.key,
    required this.nom,
    required this.description,
    required this.resume,
    required this.duReseau,
    required this.estEnvie,
    required this.onEnvie,
    required this.onFermer,
    this.enCours = false,
    this.onOuvrir,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String description;

  /// "Emma et Thomas y sont allés".
  final String resume;

  /// Visité par mon réseau : le résumé passe en doré.
  final bool duReseau;
  final bool estEnvie;
  final bool enCours;
  final VoidCallback onEnvie;
  final VoidCallback onFermer;

  /// Ouvre la page du restaurant (tap sur l'aperçu). `null` : aperçu
  /// non cliquable.
  final VoidCallback? onOuvrir;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TablTokens.surface,
      elevation: 8,
      shadowColor: Colors.black54,
      borderRadius: BorderRadius.circular(TablTokens.arrondiL),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOuvrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL,
            TablTokens.espaceM,
            TablTokens.espaceS,
            TablTokens.espaceM,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nom, style: TablTokens.sousTitre),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TablTokens.legende,
                      ),
                    ],
                    const SizedBox(height: TablTokens.espaceS),
                    Text(
                      resume,
                      style: TablTokens.legende.copyWith(
                        color: duReseau
                            ? TablTokens.primaire
                            : TablTokens.texteDoux,
                        fontWeight: duReseau
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: TablTokens.espaceS),
                    TextButton.icon(
                      onPressed: enCours ? null : onEnvie,
                      style: TextButton.styleFrom(
                        foregroundColor: estEnvie
                            ? TablTokens.primaire
                            : TablTokens.texte,
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: Icon(
                        estEnvie
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                      ),
                      label: Text(
                        estEnvie ? 'Dans mes envies' : 'Ajouter à mes envies',
                      ),
                    ),
                  ],
                ),
              ),
              if (onOuvrir != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: TablTokens.texteDoux,
                  ),
                ),
              IconButton(
                onPressed: onFermer,
                tooltip: 'Fermer',
                icon: const Icon(Icons.close_rounded, size: 20),
                color: TablTokens.texteDoux,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
