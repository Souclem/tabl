import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'feuille_creation.dart';

/// Une catégorie notée : `note` de 0 (pas de note) à 5.
typedef LigneEtoiles = ({String cle, String libelle, int note});

/// « Ce qui ressort » : une ligne d'étoiles par catégorie, toutes
/// facultatives, le nom en italique. On touche une étoile ou on glisse sur
/// la rangée ; la croix efface la note. Puis les [lignesEcrites] (un plat
/// qu'on a écrit et qu'on note), que la croix retire, et le champ pour en
/// écrire un autre. Posé dans une feuille sombre de la finalisation.
class TablNotesEtoiles extends StatelessWidget {
  const TablNotesEtoiles({
    super.key,
    required this.lignes,
    required this.onNote,
    required this.onEffacer,
    this.note,
    this.rubriqueEcrites,
    this.lignesEcrites = const [],
    this.onRetirer,
    this.controleurAjout,
    this.indicationAjout = '',
    this.onAjouter,
    this.erreurAjout,
    this.limiteAjout,
  });

  /// Sous les lignes : « Touchez ou glissez sur les étoiles… ».
  final String? note;

  final List<LigneEtoiles> lignes;
  final void Function(String cle, int note) onNote;
  final ValueChanged<String> onEffacer;

  /// Au-dessus des lignes écrites (« Plats »).
  final String? rubriqueEcrites;
  final List<LigneEtoiles> lignesEcrites;
  final ValueChanged<String>? onRetirer;

  /// Le champ pour écrire une ligne ; `null` : pas de champ.
  final TextEditingController? controleurAjout;
  final String indicationAjout;
  final ValueChanged<String>? onAjouter;
  final String? erreurAjout;

  /// Quand on ne peut plus rien écrire : ce texte remplace le champ.
  final String? limiteAjout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final ligne in lignes)
          _LigneEtoiles(
            ligne: ligne,
            onNote: (note) => onNote(ligne.cle, note),
            onEffacer: () => onEffacer(ligne.cle),
          ),
        if (rubriqueEcrites case final rubrique?)
          TablRubriqueCreation(rubrique),
        for (final ligne in lignesEcrites)
          _LigneEtoiles(
            ligne: ligne,
            retirable: true,
            onNote: (note) => onNote(ligne.cle, note),
            onEffacer: () => onRetirer?.call(ligne.cle),
          ),
        if (limiteAjout case final limite?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(limite, style: _petit(0.6)),
          )
        else if (controleurAjout case final controleur?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ChampAjout(
              controleur: controleur,
              indication: indicationAjout,
              onAjouter: (texte) => onAjouter?.call(texte),
            ),
          ),
        if (erreurAjout case final erreur?)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 14),
            child: Text(
              erreur,
              style: _petit(1).copyWith(color: TablCouleurs.sombre.erreur),
            ),
          ),
        if (note case final note?)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(note, style: _petit(0.55)),
          ),
      ],
    );
  }

  static TextStyle _petit(double opacite) => TablTokens.policeCreation.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: TablCouleurs.sombre.texte.withValues(alpha: opacite),
  );
}

/// « Noter un plat, un vin… » : une pilule de saisie, et « Ajouter » dès
/// qu'il y a du texte.
class _ChampAjout extends StatelessWidget {
  const _ChampAjout({
    required this.controleur,
    required this.indication,
    required this.onAjouter,
  });

  final TextEditingController controleur;
  final String indication;
  final ValueChanged<String> onAjouter;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final style = TablTokens.policeCreation.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 14, right: 4),
      decoration: BoxDecoration(
        color: c.texte.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.texte.withValues(alpha: 0.18), width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            size: 18,
            color: c.texte.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controleur,
              style: style,
              cursorColor: c.primaire,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: onAjouter,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: indication,
                hintStyle: style.copyWith(
                  color: c.texte.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controleur,
            builder: (context, valeur, _) => valeur.text.trim().isEmpty
                ? const SizedBox.shrink()
                : Semantics(
                    button: true,
                    label: 'Ajouter',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => onAjouter(controleur.text),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.texte,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Ajouter',
                          style: TablTokens.policeCreation.copyWith(
                            fontSize: 14,
                            color: const Color(0xFF07111F),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LigneEtoiles extends StatelessWidget {
  const _LigneEtoiles({
    required this.ligne,
    required this.onNote,
    required this.onEffacer,
    this.retirable = false,
  });

  final LigneEtoiles ligne;
  final ValueChanged<int> onNote;
  final VoidCallback onEffacer;

  /// Une ligne écrite : la croix, toujours là, la retire.
  final bool retirable;

  static const _taille = 36.0;
  static const _nombre = 5;

  void _noter(double dx) {
    final note = (dx / _taille).ceil().clamp(1, _nombre);
    if (note != ligne.note) onNote(note);
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.texte.withValues(alpha: 0.07)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              ligne.libelle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: c.titreAffichage.copyWith(
                fontSize: 17,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                color: c.texte.withValues(alpha: 0.9),
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
                height: 40,
                child: Row(
                  children: [
                    for (var k = 1; k <= _nombre; k++)
                      SizedBox(
                        width: _taille,
                        child: AnimatedScale(
                          scale: k == ligne.note ? 1.12 : 1,
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            Icons.star_rounded,
                            key: ValueKey('etoile-${ligne.cle}-$k'),
                            size: 26,
                            color: k <= ligne.note
                                ? c.primaire
                                : c.texte.withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: ligne.note > 0 || retirable
                ? IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: retirable
                        ? 'Retirer : ${ligne.libelle}'
                        : 'Effacer la note : ${ligne.libelle}',
                    onPressed: onEffacer,
                    icon: Icon(
                      Icons.close_rounded,
                      color: c.texte.withValues(alpha: 0.55),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
