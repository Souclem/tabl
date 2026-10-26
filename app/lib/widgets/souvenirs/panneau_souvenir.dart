import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';

/// « ☾ SOUVENIR », au-dessus du nom d'un souvenir.
class TablSurtitreSouvenir extends StatelessWidget {
  const TablSurtitreSouvenir({super.key, required this.texte});

  /// "Souvenir", "Souvenir · d'après vos photos".
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.nightlight_round, size: 13, color: TablTokens.texte),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texte.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: TablTokens.legende.copyWith(
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w600,
              color: TablTokens.texte.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

/// Le restaurant d'un souvenir, en grand : son nom (ou la question
/// « Quel restaurant ? » tant qu'il n'est pas choisi), ce qui aide à le
/// reconnaître, et de quoi en changer. Tout se touche.
class TablTitreLieuSouvenir extends StatelessWidget {
  const TablTitreLieuSouvenir({
    super.key,
    required this.nom,
    required this.detail,
    required this.indication,
    required this.action,
    required this.onPresse,
  });

  /// `null` : pas encore choisi, [indication] le remplace.
  final String? nom;

  /// "Végétarien · Liège · à 40 m de la photo".
  final String? detail;
  final String indication;

  /// "Changer", "Choisir".
  final String action;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: nom ?? indication,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPresse,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nom ?? indication,
              style: TablTokens.titreAffichage.copyWith(
                fontSize: 32,
                height: 1.1,
                color: nom == null ? TablTokens.texteDoux : TablTokens.texte,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (detail != null && detail!.isNotEmpty) ...[
                  Flexible(
                    child: Text(
                      detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.legende.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: TablTokens.espaceS),
                ],
                Text(
                  action,
                  style: TablTokens.legende.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: TablTokens.primaire,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Le « quand » d'un souvenir sur une ligne (« 3 novembre 2023 ·
/// Dîner »), avec d'où il vient (« D'après vos photos · 20 h 41 »).
class TablLigneQuandSouvenir extends StatelessWidget {
  const TablLigneQuandSouvenir({
    super.key,
    required this.texte,
    required this.onPresse,
    this.detail,
    this.vide = false,
  });

  final String texte;
  final String? detail;

  /// Rien de choisi : [texte] est une invitation (« Quand était-ce ? »).
  final bool vide;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onPresse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS + 2),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TablTokens.surfaceBasse,
                  border: Border.all(color: TablTokens.bordure),
                ),
                child: const Icon(
                  Icons.event_outlined,
                  size: 19,
                  color: TablTokens.texte,
                ),
              ),
              const SizedBox(width: TablTokens.espaceM - 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texte,
                      style: TablTokens.corps.copyWith(
                        color: vide ? TablTokens.texteDoux : TablTokens.texte,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: TablTokens.legende.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: TablTokens.texteDoux,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quelques mots sur un souvenir, écrits comme ils s'afficheront : en
/// italique, sans cadre.
class TablChampLegende extends StatelessWidget {
  const TablChampLegende({
    super.key,
    required this.controleur,
    required this.indication,
  });

  final TextEditingController controleur;
  final String indication;

  @override
  Widget build(BuildContext context) {
    final style = TablTokens.titreAffichage.copyWith(
      fontSize: 19,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      height: 1.4,
    );
    return TextField(
      controller: controleur,
      minLines: 1,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      style: style,
      cursorColor: TablTokens.primaire,
      decoration: InputDecoration(
        hintText: indication,
        hintStyle: style.copyWith(color: TablTokens.texteDoux),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }
}

/// Le restaurant touché sur la carte, en carte posée en bas : son nom,
/// ce qui le situe, et le bouton pour le choisir.
class TablCarteChoixLieu extends StatelessWidget {
  const TablCarteChoixLieu({
    super.key,
    required this.nom,
    required this.detail,
    required this.libelleBouton,
    required this.onChoisir,
  });

  final String nom;

  /// "Végétarien · Liège · à 40 m de la photo".
  final String detail;
  final String libelleBouton;
  final VoidCallback onChoisir;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TablTokens.espaceM),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            nom,
            style: TablTokens.titreAffichage.copyWith(
              fontSize: 22,
              height: 1.15,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail, style: TablTokens.legende.copyWith(fontSize: 13)),
          ],
          const SizedBox(height: TablTokens.espaceM),
          TablBouton(libelle: libelleBouton, onPresse: onChoisir),
        ],
      ),
    );
  }
}
