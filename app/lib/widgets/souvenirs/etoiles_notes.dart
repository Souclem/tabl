import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une catégorie notée : `note` de 0 (pas de note) à 5.
typedef LigneEtoiles = ({String cle, String libelle, int note});

/// « Ce qui ressort » : une ligne d'étoiles par catégorie, toutes
/// facultatives. On touche une étoile ou on glisse sur la rangée ; la croix
/// efface la note.
class TablNotesEtoiles extends StatelessWidget {
  const TablNotesEtoiles({
    super.key,
    required this.lignes,
    required this.onNote,
    required this.onEffacer,
  });

  final List<LigneEtoiles> lignes;
  final void Function(String cle, int note) onNote;
  final ValueChanged<String> onEffacer;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final ligne in lignes)
          _LigneEtoiles(
            ligne: ligne,
            onNote: (note) => onNote(ligne.cle, note),
            onEffacer: () => onEffacer(ligne.cle),
          ),
      ],
    );
  }
}

class _LigneEtoiles extends StatelessWidget {
  const _LigneEtoiles({
    required this.ligne,
    required this.onNote,
    required this.onEffacer,
  });

  final LigneEtoiles ligne;
  final ValueChanged<int> onNote;
  final VoidCallback onEffacer;

  static const _taille = 36.0;
  static const _nombre = 5;

  void _noter(double dx) {
    final note = (dx / _taille).ceil().clamp(1, _nombre);
    if (note != ligne.note) onNote(note);
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceXs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ligne.libelle,
              style: c.corps.copyWith(
                fontWeight: ligne.note > 0 ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Semantics(
            slider: true,
            label: ligne.libelle,
            value: ligne.note > 0 ? '${ligne.note} sur 5' : 'pas de note',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _noter(d.localPosition.dx),
              onHorizontalDragStart: (d) => _noter(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => _noter(d.localPosition.dx),
              child: SizedBox(
                width: _taille * _nombre,
                height: _taille,
                child: Row(
                  children: [
                    for (var k = 1; k <= _nombre; k++)
                      SizedBox(
                        width: _taille,
                        child: Icon(
                          k <= ligne.note
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          key: ValueKey('etoile-${ligne.cle}-$k'),
                          size: 28,
                          color: k <= ligne.note ? c.primaire : c.texteDoux,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: ligne.note > 0
                ? IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: 'Effacer la note : ${ligne.libelle}',
                    onPressed: onEffacer,
                    icon: Icon(Icons.close_rounded, color: c.texteDoux),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
