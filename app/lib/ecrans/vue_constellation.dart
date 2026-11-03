import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// La Constellation de l'Explorer, en plein écran : mon ciel (voir
/// [cielConstellation]), son titre, le bouton pour en sortir, et la fiche
/// de l'étoile touchée. Rien d'autre : c'est un moment à soi.
class VueConstellation extends StatefulWidget {
  const VueConstellation({
    super.key,
    required this.lieux,
    required this.onQuitter,
    required this.onOuvrirLieu,
    this.chargement = false,
    this.anime = true,
    this.carte,
  });

  /// Mes lieux (ceux où je suis allé).
  final List<LieuCarte> lieux;
  final bool chargement;
  final VoidCallback onQuitter;

  /// La fiche touchée : la page du restaurant.
  final ValueChanged<LieuCarte> onOuvrirLieu;

  /// `false` dans les tests : une seule image, sans carte ni animation.
  final bool anime;

  /// La carte posée dessous : de près, au repos, on y voit le plan de la
  /// ville (rues, eau, parcs), sans aucun nom.
  final ControleurCarte? carte;

  @override
  State<VueConstellation> createState() => _VueConstellationState();
}

class _VueConstellationState extends State<VueConstellation>
    with SingleTickerProviderStateMixin {
  /// Le fond (terres, frontières, routes) : lu une fois pour toute l'app.
  static Future<(FondCarte, FondDuCiel)>? _fondEnCours;

  CielConstellation _ciel = CielConstellation.vide;
  List<EtoileDuCiel> _etoiles = const [];
  List<({int de, int vers, int groupe})> _liens = const [];
  FondDuCiel? _fond;

  /// Les pays et régions des villes, lus sur la carte (il faut qu'elle soit
  /// chargée) ; avant, les villes ne sont pas regroupées.
  FondCarte? _fondCarte;
  List<GroupeDuCiel> _groupes = const [];
  String? _choisie;
  bool _aide = true;

  /// Le ciel arrive en fondu, et repart de même.
  late final _apparition = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    reverseDuration: const Duration(milliseconds: 350),
    value: widget.anime ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    _calculer();
    if (widget.anime) {
      _chargerFond();
      _apparition.forward();
    }
    widget.carte?.montrerNoms(false);
  }

  @override
  void dispose() {
    widget.carte?.montrerNoms(true);
    _apparition.dispose();
    super.dispose();
  }

  Future<void> _quitter() async {
    if (widget.anime) await _apparition.reverse();
    if (mounted) widget.onQuitter();
  }

  @override
  void didUpdateWidget(VueConstellation ancien) {
    super.didUpdateWidget(ancien);
    if (!identical(ancien.lieux, widget.lieux)) _calculer();
  }

  void _calculer() {
    final ciel = cielConstellation(widget.lieux);
    _ciel = ciel;
    _calculerGroupes();
    if (_choisie != null && _etoile(_choisie!) == null) _choisie = null;
  }

  Future<void> _chargerFond() async {
    try {
      final (carte, fond) = await (_fondEnCours ??= chargerFondCarte().then(
        (carte) => (carte, _versCiel(carte)),
      ));
      if (!mounted) return;
      setState(() {
        _fondCarte = carte;
        _fond = fond;
        _calculerGroupes();
      });
    } catch (e) {
      // Sans carte, le ciel reste un ciel.
      debugPrint('Constellation : fond de carte : $e');
      _fondEnCours = null;
    }
  }

  /// Les étoiles et leurs groupes : villes, et, une fois la carte chargée,
  /// régions et pays.
  void _calculerGroupes() {
    final carte = _fondCarte;
    final h = hierarchieDuCiel(
      _ciel,
      carte == null ? null : (x, y) => endroitDuPoint(carte, x, y),
    );
    _groupes = [
      for (final g in h.groupes)
        GroupeDuCiel(
          nom: g.nom,
          etiquette: g.etiquette,
          parent: g.parent,
          cx: g.cx,
          cy: g.cy,
          ecart: g.ecart,
          poids: g.tables,
        ),
    ];
    _etoiles = [
      for (final p in h.etoiles)
        if (_ciel.villes[p.ville].etoiles[p.etoile] case final e)
          EtoileDuCiel(
            cle: e.cle,
            nom: e.nom,
            detail: '${e.repas} repas',
            x: e.x,
            y: e.y,
            poids: e.repas,
            groupe: p.groupe,
          ),
    ];
    _liens = [
      for (final l in h.liens) (de: l.de, vers: l.vers, groupe: l.groupe),
    ];
  }

  static FondDuCiel _versCiel(FondCarte fond) {
    TraceDuCiel trace(TraceCarte t) => TraceDuCiel(
      t.points,
      xmin: t.xmin,
      xmax: t.xmax,
      ymin: t.ymin,
      ymax: t.ymax,
    );
    return FondDuCiel(
      terres: [for (final t in fond.terres) trace(t)],
      frontieres: [for (final t in fond.frontieres) trace(t)],
      routes: [
        for (final n in fond.routes)
          RoutesDuCiel(
            zoom: n.zoom,
            autoroute: n.autoroute,
            traces: [for (final t in n.traces) trace(t)],
          ),
      ],
    );
  }

  /// L'étoile de cette clé, et sa ville.
  (EtoileCiel, VilleCiel)? _etoile(String cle) {
    for (final v in _ciel.villes) {
      for (final e in v.etoiles) {
        if (e.cle == cle) return (e, v);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final marges = MediaQuery.paddingOf(context);
    final choisie = _choisie == null ? null : _etoile(_choisie!);
    final fiche = choisie == null
        ? null
        : ficheEtoile(choisie.$1, choisie.$2.nom);
    return FadeTransition(
      opacity: CurvedAnimation(parent: _apparition, curve: Curves.easeOut),
      child: Stack(
        fit: StackFit.expand,
        children: [
          TablCielConstellation(
            reveler: widget.anime && widget.carte != null,
            onRepos: (c) =>
                widget.carte?.placer(c.latitude, c.longitude, c.zoom),
            etoiles: _etoiles,
            groupes: _groupes,
            liens: _liens,
            fond: _fond,
            cleChoisie: _choisie,
            anime: widget.anime,
            margeHaut: marges.top + 110,
            margeBas: marges.bottom + 60,
            onTapEtoile: (cle) => setState(() => _choisie = cle),
            onTapVide: () {
              if (_choisie != null) setState(() => _choisie = null);
            },
            onGeste: () => setState(() => _aide = false),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TablTitreConstellation(compteurs: _ciel.compteurs),
                    ),
                    const SizedBox(width: TablTokens.espaceS),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TablBoutonConstellation(
                        actif: true,
                        onPresse: _quitter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_ciel.estVide && !widget.chargement)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: TablTokens.espaceXl),
                child: Text(
                  'Vos souvenirs apparaîtront ici, une étoile par restaurant.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'BricolageGrotesque',
                    fontSize: 15,
                    color: Color.fromRGBO(245, 240, 232, 0.64),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 16,
            bottom: marges.bottom + 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fiche != null) ...[
                  TablFicheEtoile(
                    nom: fiche.nom,
                    detail: fiche.detail,
                    depuis: fiche.depuis,
                    retour: fiche.retour,
                    onPresse: () {
                      final lieu = widget.lieux
                          .where((l) => l.cle == _choisie)
                          .firstOrNull;
                      if (lieu != null) widget.onOuvrirLieu(lieu);
                    },
                  ),
                  const SizedBox(height: 10),
                ],
                if (!_ciel.estVide)
                  TablAideConstellation(visible: _aide && fiche == null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
