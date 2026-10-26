import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Tous les filtres de l'Explorer dans une seule feuille, par sections :
/// le moment du repas, la période, les personnes, la cuisine, une Table
/// et le reste. Rien ne s'applique avant « Voir les adresses ». Renvoie
/// les filtres choisis, `null` si la feuille est fermée sans valider.
Future<FiltresCarte?> ouvrirFiltresExplorer(
  BuildContext context, {
  required FiltresCarte filtres,
  required List<ProfilPublic> personnes,
  required List<ResumeTable> tables,
}) {
  return showModalBottomSheet<FiltresCarte>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111216),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) =>
        _FeuilleFiltres(filtres: filtres, personnes: personnes, tables: tables),
  );
}

class _FeuilleFiltres extends StatefulWidget {
  const _FeuilleFiltres({
    required this.filtres,
    required this.personnes,
    required this.tables,
  });

  final FiltresCarte filtres;
  final List<ProfilPublic> personnes;
  final List<ResumeTable> tables;

  @override
  State<_FeuilleFiltres> createState() => _FeuilleFiltresState();
}

class _FeuilleFiltresState extends State<_FeuilleFiltres> {
  late FiltresCarte _f = widget.filtres;

  void _changer(FiltresCarte f) => setState(() => _f = f);

  Widget _section(String titre, List<Widget> puces) => Padding(
    padding: const EdgeInsets.only(bottom: TablTokens.espaceL - 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titre.toUpperCase(),
          style: TablTokens.legende.copyWith(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: TablTokens.texte.withValues(alpha: 0.42),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: puces),
      ],
    ),
  );

  Widget _puce(
    String libelle,
    bool choisie,
    VoidCallback onPresse, {
    Widget? avant,
  }) {
    return Semantics(
      button: true,
      selected: choisie,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: EdgeInsets.only(left: avant == null ? 14 : 5, right: 14),
          decoration: BoxDecoration(
            color: choisie
                ? TablTokens.primaire.withValues(alpha: 0.14)
                : TablTokens.texte.withValues(alpha: 0.035),
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: Border.all(
              color: choisie
                  ? TablTokens.primaire.withValues(alpha: 0.6)
                  : TablTokens.texte.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avant != null) ...[avant, const SizedBox(width: 7)],
              Text(
                libelle,
                style: TablTokens.legende.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: choisie
                      ? TablTokens.texte
                      : TablTokens.texte.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _f;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                0,
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
              ),
              child: Text(
                'Filtres',
                style: TablTokens.titreAffichage.copyWith(fontSize: 26),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL - 4,
                ),
                children: [
                  _section('Moment du repas', [
                    _puce(
                      'Tous',
                      f.moment == null,
                      () => _changer(f.copierAvec(moment: () => null)),
                    ),
                    for (final m in const ['midi', 'soir'])
                      _puce(
                        libelleMomentRepas(m)!,
                        f.moment == m,
                        () => _changer(f.copierAvec(moment: () => m)),
                      ),
                  ]),
                  _section('Période', [
                    for (final p in PeriodeCarte.values)
                      _puce(
                        p.libelle,
                        f.periode == p,
                        () => _changer(f.copierAvec(periode: p)),
                      ),
                  ]),
                  if (widget.personnes.isNotEmpty)
                    _section('Personnes', [
                      _puce(
                        'Tous',
                        f.personneId == null,
                        () => _changer(f.copierAvec(personneId: () => null)),
                      ),
                      for (final p in widget.personnes)
                        _puce(
                          p.pseudo,
                          f.personneId == p.id,
                          () => _changer(f.copierAvec(personneId: () => p.id)),
                          avant: TablAvatar(
                            pseudo: p.pseudo,
                            photoUrl: p.photoUrl,
                            rayon: 13,
                          ),
                        ),
                    ]),
                  _section('Cuisine', [
                    for (final famille in famillesCuisine.keys)
                      _puce(
                        famille,
                        f.familles.contains(famille),
                        () => _changer(
                          f.copierAvec(
                            familles: f.familles.contains(famille)
                                ? ({...f.familles}..remove(famille))
                                : {...f.familles, famille},
                          ),
                        ),
                      ),
                  ]),
                  if (widget.tables.isNotEmpty)
                    _section('Une Table', [
                      _puce(
                        'Toutes',
                        f.tableId == null,
                        () => _changer(f.copierAvec(tableId: () => null)),
                      ),
                      for (final t in widget.tables)
                        _puce(
                          t.nom,
                          f.tableId == t.id,
                          () => _changer(f.copierAvec(tableId: () => t.id)),
                        ),
                    ]),
                  _section('Autres', [
                    _puce(
                      'Jamais essayé',
                      f.jamaisEssaye,
                      () =>
                          _changer(f.copierAvec(jamaisEssaye: !f.jamaisEssaye)),
                    ),
                    _puce(
                      'Coups de cœur 😍',
                      f.coupsDeCoeur,
                      () =>
                          _changer(f.copierAvec(coupsDeCoeur: !f.coupsDeCoeur)),
                    ),
                    _puce(
                      'Là où on revient',
                      f.laOuOnRevient,
                      () => _changer(
                        f.copierAvec(laOuOnRevient: !f.laOuOnRevient),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                TablTokens.espaceS,
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
              ),
              child: Row(
                children: [
                  TablBoutonTexte(
                    libelle: 'Tout effacer',
                    onPresse: f.nombreActifs == 0
                        ? null
                        : () => _changer(FiltresCarte.aucun),
                  ),
                  const SizedBox(width: TablTokens.espaceM),
                  Expanded(
                    child: TablBouton(
                      libelle: 'Voir les adresses',
                      onPresse: () => Navigator.of(context).pop(_f),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « Où cherchez-vous ? » : autour de moi, ou l'une des villes où mon
/// cercle a des adresses, avec leur nombre. Renvoie la ville choisie,
/// [autourDeMoi] pour « Autour de moi », `null` si la feuille est fermée.
Future<Object?> ouvrirOuChercher(
  BuildContext context, {
  required List<VilleCercle> villes,
  required String? villeActuelle,
  required bool positionConnue,
  required String Function(int nombre) compte,
}) {
  return showModalBottomSheet<Object>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111216),
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (contexte) {
      Widget ligne({
        required IconData icone,
        required String titre,
        required String sousTitre,
        required bool actuelle,
        required Object valeur,
      }) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: actuelle
                ? TablTokens.primaire.withValues(alpha: 0.1)
                : TablTokens.texte.withValues(alpha: 0.035),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              side: BorderSide(
                color: actuelle
                    ? TablTokens.primaire.withValues(alpha: 0.5)
                    : TablTokens.texte.withValues(alpha: 0.07),
              ),
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              ),
              leading: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TablTokens.texte.withValues(alpha: 0.06),
                ),
                child: Icon(icone, size: 17, color: TablTokens.texte),
              ),
              title: Text(
                titre,
                style: TablTokens.corps.copyWith(
                  fontWeight: FontWeight.w600,
                  color: actuelle ? TablTokens.primaire : TablTokens.texte,
                ),
              ),
              subtitle: Text(
                sousTitre,
                style: TablTokens.legende.copyWith(fontSize: 12.5),
              ),
              trailing: actuelle
                  ? const Icon(Icons.check_rounded, color: TablTokens.primaire)
                  : null,
              onTap: () => Navigator.of(contexte).pop(valeur),
            ),
          ),
        );
      }

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(contexte).height * 0.75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL - 4,
              0,
              TablTokens.espaceL - 4,
              TablTokens.espaceM,
            ),
            children: [
              Text(
                'OÙ CHERCHEZ-VOUS ?',
                style: TablTokens.legende.copyWith(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: TablTokens.primaire,
                ),
              ),
              const SizedBox(height: TablTokens.espaceM),
              if (positionConnue)
                ligne(
                  icone: Icons.near_me_outlined,
                  titre: 'Autour de moi',
                  sousTitre: 'Les adresses près de vous',
                  actuelle: false,
                  valeur: autourDeMoi,
                ),
              for (final v in villes)
                ligne(
                  icone: Icons.place_outlined,
                  titre: v.nom,
                  sousTitre: compte(v.compte),
                  actuelle: v.nom == villeActuelle,
                  valeur: v,
                ),
              if (villes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TablTokens.espaceM,
                  ),
                  child: Text(
                    'Pas encore de ville ici.',
                    style: TablTokens.legende,
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Ce que renvoie « Où cherchez-vous ? » pour « Autour de moi ».
const autourDeMoi = 'autour';
