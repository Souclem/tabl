import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'page_moment.dart';

/// Les rubriques d'un profil, dans l'ordre des onglets.
enum RubriqueProfil {
  bilan('Bilan'),
  souvenirs('Souvenirs');

  const RubriqueProfil(this.libelle);
  final String libelle;
}

/// Ce que partagent son profil et celui des autres sous l'en-tête, en
/// onglets comme sur Strava : le Bilan (en chiffres, depuis le début ou
/// sur une année) puis les Souvenirs (tous les moments, en grille par
/// mois). Un moment touché s'agrandit par-dessus ([ouvrirPageMoment]).
mixin ContenuProfil<T extends StatefulWidget> on ActionsPublications<T> {
  RubriqueProfil rubrique = RubriqueProfil.bilan;

  /// La période du bilan ; `null` : depuis le début.
  int? anneeBilan;

  /// « Revoir vos moments » : les souvenirs ne montrent plus que les
  /// moments partagés avec cette personne. `null` : tous.
  List<SouvenirFeed>? momentsADeux;

  /// `null` sur son propre profil, son pseudo sur celui d'un autre (« Le
  /// 2026 d'Arthur »).
  String? get prenomProfil;

  /// Son propre profil : pas d'« Enregistrer » sur ses propres moments.
  bool get estMonProfil => prenomProfil == null;

  /// Le menu « ⋯ » d'un moment agrandi ; `null` : aucun.
  void Function(SouvenirFeed)? get optionsMoment => null;

  /// « Revoir vos moments » : les Souvenirs, réduits aux moments à deux.
  void revoirMomentsADeux(List<SouvenirFeed> ensemble) => setState(() {
    rubrique = RubriqueProfil.souvenirs;
    momentsADeux = ensemble;
  });

  /// Les slivers sous l'en-tête, pour une liste déjà chargée et non vide.
  List<Widget> slivresJournalEtBilan(List<SouvenirFeed> tous) {
    return [
      SliverPersistentHeader(
        pinned: true,
        delegate: TablDelegueHauteurFixe(
          hauteur: TablOngletsTexte.hauteur,
          child: TablOngletsTexte(
            libelles: [for (final r in RubriqueProfil.values) r.libelle],
            index: rubrique.index,
            onChoisir: (i) =>
                setState(() => rubrique = RubriqueProfil.values[i]),
          ),
        ),
      ),
      ...switch (rubrique) {
        RubriqueProfil.bilan => _slivresBilan(tous),
        RubriqueProfil.souvenirs => [
          if (momentsADeux != null)
            SliverToBoxAdapter(
              child: _FiltreADeux(
                onRetirer: () => setState(() => momentsADeux = null),
              ),
            ),
          ..._slivresSouvenirs(momentsADeux ?? tous),
        ],
      },
    ];
  }

  List<Widget> _slivresSouvenirs(List<SouvenirFeed> souvenirs) {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: TablTokens.espaceS)),
      for (final mois in journalParMois(souvenirs))
        SliverMainAxisGroup(
          key: ValueKey('${mois.annee}-${mois.mois}-${momentsADeux != null}'),
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: TablDelegueHauteurFixe(
                hauteur: TablEnTeteMois.hauteur,
                child: TablEnTeteMois(
                  titre: mois.titre,
                  annee: '${mois.annee}',
                  compte: mois.compte,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: TablTokens.espaceM),
                child: TablGrilleMoments(
                  indexVedette: mois.indexVedette,
                  tuiles: [
                    for (final s in mois.souvenirs)
                      TuileMoment(
                        cleHero: _cleHero(s),
                        photoUrl: s.photoUrl,
                        libelle: libelleTuileMoment(s),
                        marquant: estMarquant(s),
                        onPresse: () => ouvrirMoment(s),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _slivresBilan(List<SouvenirFeed> tous) {
    final annees = anneesDuJournal(tous);
    final annee = annees.contains(anneeBilan) ? anneeBilan : null;
    final bilan = bilanDuProfil(tous, annee: annee, prenom: prenomProfil);
    final titres = bilan.titres;
    var rang = 0;
    // Chaque section arrive après la précédente ; une autre période les
    // fait toutes revenir.
    Widget section(Widget enfant) => Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: TablApparition(
        key: ValueKey('bilan-$annee-${rang++}'),
        retard: Duration(milliseconds: 70 * rang),
        child: enfant,
      ),
    );

    final binome = bilan.binome;
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          TablTokens.espaceL - 4,
          TablTokens.espaceM,
          TablTokens.espaceL - 4,
          0,
        ),
        sliver: SliverList.list(
          children: [
            if (annees.length > 1) ...[
              TablChoixPeriode(
                periodes: libellesPeriodes(annees),
                index: annee == null ? 0 : annees.indexOf(annee) + 1,
                onChoisir: (i) =>
                    setState(() => anneeBilan = i == 0 ? null : annees[i - 1]),
              ),
              const SizedBox(height: TablTokens.espaceL),
            ],
            section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bilan.titre,
                    style: TablTokens.titreAffichage.copyWith(fontSize: 36),
                  ),
                  const SizedBox(height: TablTokens.espaceS),
                  Text(
                    bilan.resume,
                    style: TablTokens.corps.copyWith(
                      fontSize: 14,
                      color: TablTokens.texte.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            if (binome != null)
              section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TablTitreSection(texte: titres.avecQui),
                    TablCarteBinome(
                      role: bilan.roleBinome,
                      nom: binome.nom,
                      photoUrl: binome.personne.photoUrl,
                      detail: binome.detail,
                      onPresse: _ouvrirPersonne(binome.personne),
                    ),
                    if (bilan.autresProches.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(
                              child: i < bilan.autresProches.length
                                  ? TablCarteProche(
                                      nom: bilan.autresProches[i].nom,
                                      photoUrl: bilan
                                          .autresProches[i]
                                          .personne
                                          .photoUrl,
                                      detail: bilan.autresProches[i].detail,
                                      onPresse: _ouvrirPersonne(
                                        bilan.autresProches[i].personne,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            section(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TablTitreSection(texte: titres.retours),
                  if (bilan.retours.isEmpty)
                    _MessageDiscret(texte: titres.aucunRetour)
                  else
                    for (final r in bilan.retours)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TablCarteRetour(
                          nom: r.restaurantNom,
                          lieu: r.lieu,
                          nombreVisites: r.nombreVisites,
                          total: r.total,
                          photoUrl: r.photoUrl,
                        ),
                      ),
                ],
              ),
            ),
            if (bilan.villes.isNotEmpty)
              section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TablTitreSection(texte: titres.villes),
                    for (var i = 0; i < bilan.villes.length; i++)
                      TablBarreVille(
                        nom: bilan.villes[i].nom,
                        compte: bilan.villes[i].compte,
                        part: bilan.villes[i].part,
                        rang: i,
                      ),
                  ],
                ),
              ),
            if (bilan.moments.isNotEmpty)
              section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TablTitreSection(texte: titres.moments),
                    TablAnneauMoments(
                      total: bilan.nombreMoments,
                      parts: [
                        for (final m in bilan.moments)
                          PartAnneau(
                            libelle: m.libelle,
                            detail: m.detail,
                            part: m.part,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            if (bilan.cuisines.isNotEmpty)
              section(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TablTitreSection(texte: titres.cuisines),
                    Wrap(
                      spacing: TablTokens.espaceS,
                      runSpacing: TablTokens.espaceS,
                      children: [
                        for (var i = 0; i < bilan.cuisines.length; i++)
                          TablPastilleCuisine(
                            texte: bilan.cuisines[i],
                            enAvant: i == 0,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            Text(titres.pied, style: TablTokens.legende),
          ],
        ),
      ),
    ];
  }

  /// Ouvre le profil d'une personne (jamais le sien : on y est déjà, ou
  /// on y revient par la barre du bas).
  VoidCallback? _ouvrirPersonne(PersonnePresente p) =>
      p.estMoi || abonnementService == null
      ? null
      : () => ouvrirProfilDe(p.id, p.pseudo);

  Object _cleHero(SouvenirFeed s) => 'moment-${s.id}';

  /// Agrandit un moment par-dessus le profil.
  Future<void> ouvrirMoment(SouvenirFeed s) => ouvrirPageMoment(
    context,
    souvenir: s,
    cleHero: _cleHero(s),
    souvenirService: souvenirService,
    onReagir: basculerReaction,
    onOuvrirLieu: ouvrirRestaurant,
    onEnregistrer: estMonProfil ? null : basculerEnvie,
    onOptions: optionsMoment,
    onOuvrirPersonne: abonnementService == null
        ? null
        : (p) => ouvrirProfilDe(p.id, p.pseudo),
  );
}

/// « Vos moments à deux » en tête du journal filtré, à toucher pour
/// revoir tous les moments.
class _FiltreADeux extends StatelessWidget {
  const _FiltreADeux({required this.onRetirer});

  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceXs,
        TablTokens.espaceL - 4,
        TablTokens.espaceXs,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          label: const Text('Vos moments à deux'),
          selected: true,
          showCheckmark: false,
          onDeleted: onRetirer,
          deleteButtonTooltipMessage: 'Revoir tous les moments',
          onPressed: onRetirer,
        ),
      ),
    );
  }
}

class _MessageDiscret extends StatelessWidget {
  const _MessageDiscret({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        border: Border.all(color: TablTokens.bordure),
      ),
      child: Text(
        texte,
        style: TablTokens.corps.copyWith(
          fontSize: 14,
          color: TablTokens.texteDoux,
        ),
      ),
    );
  }
}
