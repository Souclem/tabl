import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_choix_restaurant.dart';

/// Ce que « Où et quand » rend : le lieu, s'il a été confirmé ou choisi, et
/// le moment du repas (`midi` / `soir`), `null` quand il n'est pas
/// modifiable.
typedef ResultatOuEtQuand = ({
  LieuRestaurant? lieu,
  bool lieuConfirme,
  String? moment,
});

/// « Où et quand » : le lieu du repas — « Étiez-vous chez X ? » quand un
/// restaurant est proposé d'après les photos, les restaurants près des
/// photos, un autre restaurant, un lieu personnel — et, pour un moment en
/// création, s'il s'agissait du midi ou du soir.
///
/// Toucher un restaurant, répondre « Oui » ou « Valider » ferme la feuille
/// avec le résultat. `null` : fermée sans rien changer.
///
/// [moment] : `midi` ou `soir` ; `null` pour un moment déjà publié, dont la
/// date est figée (seul le lieu change). [completerLieuManuel] : ce que
/// l'écran ajoute à un restaurant saisi à la main (voir [PropositionLieu]).
Future<ResultatOuEtQuand?> ouvrirFeuilleOuEtQuand(
  BuildContext context, {
  required LieuRestaurant? lieu,
  required bool lieuConfirme,
  required String? moment,
  required List<Coordonnees> endroits,
  required List<List<LieuRestaurant>> prochesParEndroit,
  required RepereDistance repere,
  required RechercheLieuService? rechercheLieuService,
  required PositionService? positionService,
  LieuRestaurant Function(LieuRestaurant lieu)? completerLieuManuel,
}) {
  final c = TablCouleurs.of(context);
  return showModalBottomSheet<ResultatOuEtQuand>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    showDragHandle: true,
    builder: (_) => _FeuilleOuEtQuand(
      lieu: lieu,
      lieuConfirme: lieuConfirme,
      moment: moment,
      endroits: endroits,
      prochesParEndroit: prochesParEndroit,
      repere: repere,
      rechercheLieuService: rechercheLieuService,
      positionService: positionService,
      completerLieuManuel: completerLieuManuel,
    ),
  );
}

class _FeuilleOuEtQuand extends StatefulWidget {
  const _FeuilleOuEtQuand({
    required this.lieu,
    required this.lieuConfirme,
    required this.moment,
    required this.endroits,
    required this.prochesParEndroit,
    required this.repere,
    required this.rechercheLieuService,
    required this.positionService,
    required this.completerLieuManuel,
  });

  final LieuRestaurant? lieu;
  final bool lieuConfirme;
  final String? moment;
  final List<Coordonnees> endroits;
  final List<List<LieuRestaurant>> prochesParEndroit;
  final RepereDistance repere;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;
  final LieuRestaurant Function(LieuRestaurant lieu)? completerLieuManuel;

  @override
  State<_FeuilleOuEtQuand> createState() => _FeuilleOuEtQuandState();
}

class _FeuilleOuEtQuandState extends State<_FeuilleOuEtQuand> {
  late String? _moment = widget.moment;

  /// « Non » à « Étiez-vous chez X ? » : la proposition s'efface.
  bool _propositionEcartee = false;

  static const _moments = ['midi', 'soir'];

  void _fermer(LieuRestaurant? lieu, {required bool confirme}) {
    Navigator.of(
      context,
    ).pop((lieu: lieu, lieuConfirme: confirme, moment: _moment));
  }

  String _detail(LieuRestaurant lieu) => detailLieuSouvenir(
    lieu,
    repere: widget.endroits.isEmpty ? null : widget.repere,
  );

  Future<void> _chercherAutreLieu({bool personnel = false}) async {
    final choisi = await choisirRestaurant(
      context,
      rechercheLieuService: widget.rechercheLieuService,
      positionService: widget.positionService,
      endroits: widget.endroits,
      prochesParEndroit: widget.prochesParEndroit,
      repere: widget.repere,
      choisi: widget.lieu,
      lieuPersonnelDAbord: personnel,
    );
    if (choisi == null || !mounted) return;
    final complete = widget.completerLieuManuel;
    _fermer(
      choisi.estManuel && complete != null ? complete(choisi) : choisi,
      confirme: true,
    );
  }

  Widget _rubrique(TablCouleurs c, String texte) => Padding(
    padding: const EdgeInsets.only(
      top: TablTokens.espaceM,
      bottom: TablTokens.espaceXs,
    ),
    child: Text(
      texte.toUpperCase(),
      style: c.legende.copyWith(
        fontSize: 11,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final lieu = widget.lieu;
    final proposition = lieu != null && !widget.lieuConfirme;
    final confirmation = proposition && !_propositionEcartee;

    // Les restaurants près des photos, sans celui déjà proposé ou choisi.
    final proches = [
      for (final liste in widget.prochesParEndroit)
        for (final l in liste)
          if (l.cle != lieu?.cle) l,
    ].take(6).toList();
    final titreProches = widget.repere == RepereDistance.vous
        ? 'Près de vous'
        : 'Près de vos photos';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL - 4,
                ),
                child: Text(
                  'Où et quand',
                  style: c.titreAffichage.copyWith(fontSize: 26),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TablTokens.espaceL - 4,
                  ),
                  children: [
                    _rubrique(c, 'Où'),
                    if (confirmation)
                      TablConfirmationLieu(
                        question: 'Étiez-vous chez ${lieu.nom} ?',
                        detail: _detail(lieu),
                        libelleOui: 'Oui',
                        libelleNon: 'Non',
                        onOui: () => _fermer(lieu, confirme: true),
                        onNon: () => setState(() => _propositionEcartee = true),
                      )
                    else if (lieu != null && !proposition)
                      TablLigneSuggestionLieu(
                        nom: lieu.nom,
                        description: _detail(lieu),
                        onSelection: () => _fermer(lieu, confirme: true),
                      ),
                    if (proches.isNotEmpty) ...[
                      _rubrique(c, titreProches),
                      for (final l in proches)
                        TablLigneSuggestionLieu(
                          nom: l.nom,
                          description: _detail(l),
                          onSelection: () => _fermer(l, confirme: true),
                        ),
                    ],
                    const SizedBox(height: TablTokens.espaceS),
                    TablBoutonTexte(
                      libelle: 'Chercher un autre restaurant',
                      onPresse: _chercherAutreLieu,
                    ),
                    TablBoutonTexte(
                      libelle: 'Créer un lieu personnel',
                      onPresse: () => _chercherAutreLieu(personnel: true),
                    ),
                    if (_moment case final moment?) ...[
                      _rubrique(c, 'Quand'),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TablSegmentModeCarte(
                          options: const ['Midi', 'Soir'],
                          selectionne: _moments.indexOf(moment),
                          onSelection: (i) =>
                              setState(() => _moment = _moments[i]),
                        ),
                      ),
                    ],
                    const SizedBox(height: TablTokens.espaceM),
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
                child: TablBouton(
                  libelle: 'Valider',
                  onPresse: () => _fermer(lieu, confirme: widget.lieuConfirme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
