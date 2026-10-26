import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../boutons.dart';

/// Une étape expliquée avant de commencer (« Vous choisissez des
/// photos »…).
typedef EtapeImport = ({IconData icone, String titre, String texte});

/// Les étapes d'un import, l'une sous l'autre dans une carte : ce qui va
/// se passer, avant de le demander.
class TablEtapesImport extends StatelessWidget {
  const TablEtapesImport({super.key, required this.etapes});

  final List<EtapeImport> etapes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < etapes.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: TablTokens.surface),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TablTokens.surface,
                      border: Border.all(color: TablTokens.bordure),
                    ),
                    child: Icon(
                      etapes[i].icone,
                      size: 20,
                      color: TablTokens.texte,
                    ),
                  ),
                  const SizedBox(width: TablTokens.espaceM - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          etapes[i].titre,
                          style: TablTokens.corps.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: TablTokens.texte,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          etapes[i].texte,
                          style: TablTokens.legende.copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un repas retrouvé dans les photos, à vérifier : quand, ses photos,
/// le restaurant proposé (à changer d'un tap), puis l'ajouter ou
/// l'ignorer. Une fois ajouté, la carte se fait discrète.
///
/// Composant pur : tout arrive prêt à afficher ; toucher une photo
/// ([onToucherPhoto]) ouvre ce qu'on peut en faire.
class TablCarteRepas extends StatelessWidget {
  const TablCarteRepas({
    super.key,
    required this.quand,
    required this.photos,
    required this.nomLieu,
    required this.detailLieu,
    required this.onToucherPhoto,
    required this.onChangerLieu,
    required this.onAjouter,
    required this.onIgnorer,
    this.mention,
    this.ajoute = false,
  });

  /// "3 novembre 2023 · Dîner".
  final String quand;
  final List<Uint8List> photos;

  /// `null` : pas encore de restaurant (« Quel restaurant ? »).
  final String? nomLieu;

  /// "Végétarien · Liège · à 40 m de la photo", "Recherche du
  /// restaurant…".
  final String? detailLieu;

  /// "1 photo sans position, rattachée par l'heure".
  final String? mention;
  final ValueChanged<int> onToucherPhoto;
  final VoidCallback onChangerLieu;

  /// `null` : rien à ajouter tant qu'il manque le restaurant.
  final VoidCallback? onAjouter;
  final VoidCallback onIgnorer;
  final bool ajoute;

  static const double _cote = 60;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: ajoute ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(TablTokens.espaceM),
        decoration: BoxDecoration(
          color: TablTokens.surfaceBasse,
          borderRadius: BorderRadius.circular(TablTokens.arrondiL),
          border: Border.all(color: TablTokens.texte.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quand.toUpperCase(),
                    style: TablTokens.legende.copyWith(
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w600,
                      color: TablTokens.texte.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (ajoute)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: TablTokens.primaire,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ajouté',
                        style: TablTokens.legende.copyWith(
                          fontSize: 12,
                          color: TablTokens.primaire,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: TablTokens.espaceS + 2),
            SizedBox(
              height: _cote,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: photos.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: TablTokens.espaceS - 2),
                itemBuilder: (_, i) => Semantics(
                  button: !ajoute,
                  label: 'Photo ${i + 1}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: ajoute ? null : () => onToucherPhoto(i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                      child: Image.memory(
                        photos[i],
                        width: _cote,
                        height: _cote,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (mention != null) ...[
              const SizedBox(height: 6),
              Text(mention!, style: TablTokens.legende.copyWith(fontSize: 12)),
            ],
            const SizedBox(height: TablTokens.espaceM - 4),
            Semantics(
              button: !ajoute,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: ajoute ? null : onChangerLieu,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nomLieu ?? 'Quel restaurant ?',
                      style: TablTokens.titreAffichage.copyWith(
                        fontSize: 22,
                        height: 1.15,
                        color: nomLieu == null
                            ? TablTokens.texteDoux
                            : TablTokens.texte,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (detailLieu != null && detailLieu!.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              detailLieu!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TablTokens.legende.copyWith(fontSize: 13),
                            ),
                          ),
                          const SizedBox(width: TablTokens.espaceS),
                        ],
                        if (!ajoute)
                          Text(
                            nomLieu == null ? 'Choisir' : 'Changer',
                            style: TablTokens.legende.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: TablTokens.primaire,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!ajoute) ...[
              const SizedBox(height: TablTokens.espaceM),
              Row(
                children: [
                  TablBoutonTexte(libelle: 'Ignorer', onPresse: onIgnorer),
                  const Spacer(),
                  SizedBox(
                    width: 190,
                    child: TablBouton(
                      libelle: 'Ajouter ce repas',
                      onPresse: onAjouter,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Le bilan d'un import : de grands chiffres, sobres, et la période
/// couverte.
class TablBilanImport extends StatelessWidget {
  const TablBilanImport({super.key, required this.chiffres, this.periode});

  /// (« 14 », « souvenirs ajoutés »).
  final List<({String nombre, String libelle})> chiffres;

  /// "Mars 2019 — Août 2026".
  final String? periode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in chiffres)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.nombre,
                      style: TablTokens.titreAffichage.copyWith(fontSize: 44),
                    ),
                    Text(c.libelle, style: TablTokens.legende),
                  ],
                ),
              ),
          ],
        ),
        if (periode != null) ...[
          const SizedBox(height: TablTokens.espaceL),
          const Divider(height: 1, color: TablTokens.surface),
          const SizedBox(height: TablTokens.espaceM),
          Row(
            children: [
              Text('Période couverte', style: TablTokens.legende),
              const Spacer(),
              Text(
                periode!,
                style: TablTokens.corps.copyWith(
                  fontSize: 14,
                  color: TablTokens.texte,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
