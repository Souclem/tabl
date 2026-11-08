import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'avatar.dart';

/// Un proche à qui demander un avis : sa tête, son nom, sa dernière
/// visite, son ressenti, et une coche dorée s'il est choisi.
class TablChoixProche extends StatelessWidget {
  const TablChoixProche({
    super.key,
    required this.pseudo,
    required this.photoUrl,
    required this.detail,
    required this.choisi,
    required this.onPresse,
    this.emoji,
  });

  final String pseudo;
  final String? photoUrl;

  /// "Dernière visite il y a 3 semaines".
  final String detail;
  final String? emoji;
  final bool choisi;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: choisi,
      label: '$pseudo. $detail',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: choisi
                ? c.primaire.withValues(alpha: 0.08)
                : c.texte.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
            border: Border.all(
              color: choisi
                  ? c.primaire.withValues(alpha: 0.55)
                  : c.texte.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              TablAvatar(pseudo: pseudo, photoUrl: photoUrl, rayon: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pseudo,
                      style: c.corps.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.texte,
                      ),
                    ),
                    Text(detail, style: c.legende.copyWith(fontSize: 12)),
                  ],
                ),
              ),
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
              ],
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: choisi ? c.primaire : Colors.transparent,
                  border: Border.all(
                    color: choisi ? c.primaire : c.bordure,
                    width: 1.5,
                  ),
                ),
                child: choisi
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: c.texteSurPrimaire,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une réponse en un toucher (« 😍 Oui, vas-y ») : grande, dorée quand
/// on l'a choisie.
class TablChoixReponse extends StatelessWidget {
  const TablChoixReponse({
    super.key,
    required this.emoji,
    required this.libelle,
    required this.choisie,
    required this.onPresse,
  });

  final String emoji;
  final String libelle;
  final bool choisie;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: choisie,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: choisie
                ? c.primaire.withValues(alpha: 0.12)
                : c.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
            border: Border.all(
              color: choisie
                  ? c.primaire.withValues(alpha: 0.7)
                  : c.texte.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Text(
                libelle,
                style: c.corps.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: choisie ? c.primaire : c.texte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
