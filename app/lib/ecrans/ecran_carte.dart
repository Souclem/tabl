import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Onglet Carte. En haut : le titre, la bascule Carte / Liste et la
/// rangée de filtres. En bas : la carte (lieux de mon réseau en doré,
/// annuaire en points discrets de près) ou la liste des lieux de mon
/// réseau. Un tap ouvre un aperçu ; la fiche complète du restaurant
/// viendra ensuite.
class EcranCarte extends StatefulWidget {
  const EcranCarte({
    super.key,
    required this.carteService,
    this.positionService,
    this.tableService,
    this.filtresInitiaux = FiltresCarte.aucun,
    this.estOnglet = true,
    this.afficherCarte = true,
  });

  final CarteService carteService;

  /// `null` : la carte démarre sur la Belgique, sans bouton "ma position"
  /// ni distances dans la liste.
  final PositionService? positionService;

  /// Pour le nom des Tables du filtre "Table". `null` : filtre masqué.
  final TableService? tableService;

  /// Filtres appliqués à l'ouverture ("Voir sur la carte" depuis une
  /// Table ouvre la carte déjà filtrée sur cette Table).
  final FiltresCarte filtresInitiaux;

  /// `false` quand la carte est ouverte par-dessus un autre écran : bouton
  /// retour, et pas de barre de navigation à éviter en bas.
  final bool estOnglet;

  /// `false` dans les tests : la carte Mapbox est une vue native,
  /// indisponible hors d'un vrai appareil — le reste de l'écran reste
  /// testable.
  final bool afficherCarte;

  @override
  State<EcranCarte> createState() => _EcranCarteState();
}

class _EcranCarteState extends State<EcranCarte> {
  /// Place occupée en bas par la barre de navigation flottante.
  double get _margeBarre => widget.estOnglet
      ? TablBarreNavigation.hauteurOccupee(context)
      : MediaQuery.paddingOf(context).bottom;

  /// À partir de ce zoom (une ville), l'annuaire complète la carte : plus
  /// loin, les lieux du réseau suffisent à remplir les places disponibles.
  static const _zoomAnnuaire = 12.0;

  final _controleur = ControleurCarte();

  /// Zone visible ; la Belgique tant que la carte ne l'a pas encore dite.
  ZoneCarte _zone = const ZoneCarte(sud: 49.4, ouest: 2.5, nord: 51.6, est: 6.5);
  double _zoom = 6.5;

  bool _enListe = false;
  late FiltresCarte _filtres = widget.filtresInitiaux;
  List<LieuCarte> _lieuxTabl = const [];
  List<LieuCarte> _annuaire = const [];
  List<ResumeTable> _tables = const [];
  LieuCarte? _selection;
  bool _envieEnCours = false;
  Coordonnees? _position;
  Timer? _attenteZone;

  @override
  void initState() {
    super.initState();
    _chargerLieuxTabl();
    _chargerTables();
    _localiser();
  }

  @override
  void dispose() {
    _attenteZone?.cancel();
    super.dispose();
  }

  Future<void> _chargerLieuxTabl() async {
    try {
      final lieux = await widget.carteService.lieuxTabl();
      if (!mounted) return;
      setState(() => _lieuxTabl = lieux);
    } catch (e) {
      debugPrint('EcranCarte: lieux du réseau : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _chargerTables() async {
    try {
      final tables = await widget.tableService?.mesTables() ?? const [];
      if (mounted) setState(() => _tables = tables);
    } catch (e) {
      debugPrint('EcranCarte: tables : $e');
    }
  }

  Future<void> _localiser() async {
    final position = await widget.positionService?.positionActuelle();
    if (!mounted || position == null) return;
    setState(() => _position = position);
    await _controleur.centrerSur(position.latitude, position.longitude);
  }

  void _zoneVisible(
    double sud,
    double ouest,
    double nord,
    double est,
    double zoom,
  ) {
    _attenteZone?.cancel();
    setState(() {
      _zone = ZoneCarte(sud: sud, ouest: ouest, nord: nord, est: est);
      _zoom = zoom;
    });
    if (zoom < _zoomAnnuaire) {
      if (_annuaire.isNotEmpty) setState(() => _annuaire = const []);
      return;
    }
    // On attend que la carte s'immobilise avant de charger le quartier.
    _attenteZone = Timer(const Duration(milliseconds: 300), () async {
      try {
        final lieux = await widget.carteService.lieuxAnnuaire(
          ZoneCarte(sud: sud, ouest: ouest, nord: nord, est: est),
          limite: 600,
        );
        if (mounted) setState(() => _annuaire = lieux);
      } catch (e) {
        debugPrint('EcranCarte: annuaire : $e');
      }
    });
  }

  List<LieuCarte> get _lieuxTablFiltres =>
      _lieuxTabl.where(_filtres.garde).toList();

  /// L'annuaire sans les lieux déjà entrés dans Tabl, et seulement si
  /// aucun filtre "réseau" ne l'exclut.
  List<LieuCarte> get _annuaireFiltre {
    if (!_filtres.annuaireVisible) return const [];
    final dejaDansTabl = {
      for (final l in _lieuxTabl)
        if (l.fsqPlaceId != null) l.fsqPlaceId,
    };
    return [
      for (final l in _annuaire)
        if (!dejaDansTabl.contains(l.fsqPlaceId) && _filtres.garde(l)) l,
    ];
  }

  double? _distance(LieuCarte lieu) {
    final position = _position;
    if (position == null) return null;
    return distanceEnMetres(
      position.latitude,
      position.longitude,
      lieu.latitude,
      lieu.longitude,
    );
  }

  /// La liste : lieux de mon réseau filtrés, du plus proche au plus loin
  /// si la position est connue, sinon les plus visités d'abord.
  List<LieuCarte> get _lieuxListe {
    final lieux = _lieuxTablFiltres;
    if (_position != null) {
      lieux.sort((a, b) => _distance(a)!.compareTo(_distance(b)!));
    } else {
      lieux.sort((a, b) => b.visites.length.compareTo(a.visites.length));
    }
    return lieux;
  }

  void _tapLieu(String cle) {
    final lieu = [
      ..._lieuxTabl,
      ..._annuaire,
    ].where((l) => l.cle == cle).firstOrNull;
    if (lieu != null) setState(() => _selection = lieu);
  }

  void _ouvrirDepuisListe(LieuCarte lieu) {
    setState(() {
      _enListe = false;
      _selection = lieu;
    });
    _controleur.centrerSur(lieu.latitude, lieu.longitude, zoom: 15);
  }

  Future<void> _basculerEnvie() async {
    final lieu = _selection;
    if (lieu == null) return;
    setState(() => _envieEnCours = true);
    try {
      final restaurantId = await widget.carteService.idRestaurant(lieu);
      final envie = !lieu.estEnvie;
      await widget.carteService.basculerEnvie(restaurantId, envie: envie);
      final misAJour = LieuCarte(
        restaurantId: restaurantId,
        fsqPlaceId: lieu.fsqPlaceId,
        nom: lieu.nom,
        ville: lieu.ville,
        adresse: lieu.adresse,
        latitude: lieu.latitude,
        longitude: lieu.longitude,
        categories: lieu.categories,
        visites: lieu.visites,
        estEnvie: envie,
      );
      if (!mounted) return;
      setState(() {
        _selection = misAJour;
        _lieuxTabl = [
          for (final l in _lieuxTabl)
            if (l.cle != lieu.cle && l.cle != misAJour.cle) l,
          if (misAJour.duReseau) misAJour,
        ];
      });
    } catch (e) {
      debugPrint('EcranCarte: envie : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envieEnCours = false);
    }
  }

  // ---------------------------------------------------------------
  //  Choix des filtres à options (une feuille courte, jamais une page)
  // ---------------------------------------------------------------

  /// Renvoie l'identifiant choisi, `''` pour l'option "tout" (valeur
  /// `null`), ou `null` si la feuille est fermée sans choix.
  Future<String?> _choisir({
    required String titre,
    required List<({String? valeur, String libelle})> options,
    required String? actuel,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: TablTokens.surface,
      isScrollControlled: true,
      builder: (contexteFeuille) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(contexteFeuille).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL,
                  0,
                  TablTokens.espaceL,
                  TablTokens.espaceS,
                ),
                child: Text(titre, style: TablTokens.sousTitre),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option.libelle, style: TablTokens.corps),
                  trailing: option.valeur == actuel
                      ? const Icon(
                          Icons.check_rounded,
                          color: TablTokens.primaire,
                        )
                      : null,
                  onTap: () =>
                      Navigator.of(contexteFeuille).pop(option.valeur ?? ''),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _choisirPersonne() async {
    final choix = await _choisir(
      titre: 'Une personne',
      actuel: _filtres.personneId,
      options: [
        (valeur: null, libelle: 'Tout mon réseau'),
        for (final p in personnesDesLieux(_lieuxTabl))
          (valeur: p.id, libelle: p.pseudo),
      ],
    );
    if (choix == null) return;
    setState(() {
      _filtres = _filtres.copierAvec(
        personneId: () => choix.isEmpty ? null : choix,
      );
    });
  }

  Future<void> _choisirTable() async {
    final choix = await _choisir(
      titre: 'Une Table',
      actuel: _filtres.tableId,
      options: [
        (valeur: null, libelle: 'Toutes'),
        for (final t in _tables) (valeur: t.id, libelle: t.nom),
      ],
    );
    if (choix == null) return;
    setState(() {
      _filtres = _filtres.copierAvec(
        tableId: () => choix.isEmpty ? null : choix,
      );
    });
  }

  Future<void> _choisirMoment() async {
    final choix = await _choisir(
      titre: 'Midi ou soir',
      actuel: _filtres.moment,
      options: const [
        (valeur: null, libelle: 'Midi et soir'),
        (valeur: 'midi', libelle: 'Midi'),
        (valeur: 'soir', libelle: 'Soir'),
      ],
    );
    if (choix == null) return;
    setState(() {
      _filtres = _filtres.copierAvec(
        moment: () => choix.isEmpty ? null : choix,
      );
    });
  }

  Future<void> _choisirCuisine() async {
    final choisies = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (_) => _FeuilleCuisine(selection: _filtres.familles),
    );
    if (choisies == null) return;
    setState(() => _filtres = _filtres.copierAvec(familles: choisies));
  }

  String? _pseudo(String? id) => id == null
      ? null
      : personnesDesLieux(
          _lieuxTabl,
        ).where((p) => p.id == id).firstOrNull?.pseudo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(bottom: false, child: _enTete()),
          Expanded(child: _enListe ? _liste() : _carte()),
        ],
      ),
    );
  }

  Widget _enTete() {
    final f = _filtres;
    final pseudo = _pseudo(f.personneId);
    final table = _tables.where((t) => t.id == f.tableId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL,
            TablTokens.espaceS,
            TablTokens.espaceM,
            TablTokens.espaceS,
          ),
          child: Row(
            children: [
              if (!widget.estOnglet) ...[
                TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
                const SizedBox(width: TablTokens.espaceM),
              ],
              Expanded(
                child: Text(
                  'Carte',
                  style: TablTokens.titreAffichage.copyWith(fontSize: 26),
                ),
              ),
              TablSegmentModeCarte(
                options: const ['Carte', 'Liste'],
                selectionne: _enListe ? 1 : 0,
                onSelection: (i) => setState(() => _enListe = i == 1),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
          child: Row(
            children: [
              for (final puce in [
                if (f.nombreActifs > 0)
                  TablPuceFiltre(
                    libelle: 'Effacer (${f.nombreActifs})',
                    actif: false,
                    onPresse: () =>
                        setState(() => _filtres = FiltresCarte.aucun),
                  ),
                TablPuceFiltre(
                  libelle: pseudo ?? 'Une personne',
                  actif: pseudo != null,
                  avecChoix: true,
                  onPresse: _choisirPersonne,
                ),
                if (_tables.isNotEmpty)
                  TablPuceFiltre(
                    libelle: table?.nom ?? 'Une Table',
                    actif: table != null,
                    avecChoix: true,
                    onPresse: _choisirTable,
                  ),
                TablPuceFiltre(
                  libelle: f.familles.isEmpty
                      ? 'Cuisine'
                      : f.familles.length == 1
                      ? f.familles.first
                      : 'Cuisine (${f.familles.length})',
                  actif: f.familles.isNotEmpty,
                  avecChoix: true,
                  onPresse: _choisirCuisine,
                ),
                TablPuceFiltre(
                  libelle: 'Mes envies',
                  actif: f.mesEnvies,
                  onPresse: () => setState(
                    () => _filtres = f.copierAvec(mesEnvies: !f.mesEnvies),
                  ),
                ),
                TablPuceFiltre(
                  libelle: 'Jamais essayé',
                  actif: f.jamaisEssaye,
                  onPresse: () => setState(
                    () =>
                        _filtres = f.copierAvec(jamaisEssaye: !f.jamaisEssaye),
                  ),
                ),
                TablPuceFiltre(
                  libelle: 'Coups de cœur 😍',
                  actif: f.coupsDeCoeur,
                  onPresse: () => setState(
                    () =>
                        _filtres = f.copierAvec(coupsDeCoeur: !f.coupsDeCoeur),
                  ),
                ),
                TablPuceFiltre(
                  libelle: 'Là où on revient',
                  actif: f.laOuOnRevient,
                  onPresse: () => setState(
                    () => _filtres = f.copierAvec(
                      laOuOnRevient: !f.laOuOnRevient,
                    ),
                  ),
                ),
                TablPuceFiltre(
                  libelle: switch (f.moment) {
                    'midi' => 'Midi',
                    'soir' => 'Soir',
                    _ => 'Midi / soir',
                  },
                  actif: f.moment != null,
                  avecChoix: true,
                  onPresse: _choisirMoment,
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: puce,
                ),
            ],
          ),
        ),
        const SizedBox(height: TablTokens.espaceS),
      ],
    );
  }

  Widget _carte() {
    final selection = _selection;
    return Stack(
      children: [
        Positioned.fill(
          child: widget.afficherCarte
              ? TablCarteMapbox(
                  // Toujours la même règle : ce que disent les filtres, et
                  // parmi ça les plus pertinents pour la zone visible.
                  geojsonLieux: geojsonLieux(
                    lieuxAAfficher([
                      ..._lieuxTablFiltres,
                      ..._annuaireFiltre,
                    ], _zone, zoom: _zoom),
                  ),
                  // Belgique, avant de connaître la position.
                  latitudeInitiale: 50.5,
                  longitudeInitiale: 4.6,
                  zoomInitial: 6.5,
                  margeBas: _margeBarre,
                  controleur: _controleur,
                  onTapLieu: _tapLieu,
                  onZoneVisible: _zoneVisible,
                )
              : const ColoredBox(color: TablTokens.surface),
        ),
        // Toujours là : recentre sur moi, ou redemande ma position si
        // elle n'est pas encore connue (autorisation refusée puis
        // accordée, signal GPS revenu...).
        if (widget.positionService != null)
          Positioned(
            right: TablTokens.espaceM,
            top: TablTokens.espaceM,
            child: _BoutonRond(
              icone: Icons.my_location_rounded,
              libelle: 'Me recentrer',
              onPresse: () {
                final position = _position;
                if (position == null) {
                  _localiser();
                } else {
                  _controleur.centrerSur(position.latitude, position.longitude);
                }
              },
            ),
          ),
        if (selection != null)
          Positioned(
            left: TablTokens.espaceM,
            right: TablTokens.espaceM,
            bottom: _margeBarre + TablTokens.espaceM,
            child: TablApercuLieu(
              nom: selection.nom,
              description: selection.description,
              resume: selection.resumeVisites,
              duReseau: selection.visites.isNotEmpty,
              estEnvie: selection.estEnvie,
              enCours: _envieEnCours,
              onEnvie: _basculerEnvie,
              onFermer: () => setState(() => _selection = null),
            ),
          ),
      ],
    );
  }

  Widget _liste() {
    final lieux = _lieuxListe;
    if (lieux.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(TablTokens.espaceXl),
        child: Text(
          _filtres.nombreActifs > 0
              ? 'Aucun lieu de votre réseau ne correspond à ces filtres.'
              : 'Aucun lieu dans votre réseau pour l\'instant. Publiez un '
                    'moment ou ajoutez des envies depuis la carte.',
          textAlign: TextAlign.center,
          style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
        ),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.only(bottom: _margeBarre),
      itemCount: lieux.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        indent: TablTokens.espaceL,
        endIndent: TablTokens.espaceL,
        color: TablTokens.bordure,
      ),
      itemBuilder: (_, index) {
        final lieu = lieux[index];
        final distance = _distance(lieu);
        return TablLigneLieu(
          nom: lieu.nom,
          description: lieu.description,
          resume: lieu.resumeVisites,
          duReseau: lieu.visites.isNotEmpty,
          estEnvie: lieu.estEnvie,
          distance: distance == null ? null : distanceLisible(distance),
          onPresse: () => _ouvrirDepuisListe(lieu),
        );
      },
    );
  }
}

/// Choix des familles de cuisine : plusieurs à la fois.
class _FeuilleCuisine extends StatefulWidget {
  const _FeuilleCuisine({required this.selection});

  final Set<String> selection;

  @override
  State<_FeuilleCuisine> createState() => _FeuilleCuisineState();
}

class _FeuilleCuisineState extends State<_FeuilleCuisine> {
  late final Set<String> _selection = {...widget.selection};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(TablTokens.espaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Cuisine', style: TablTokens.sousTitre),
            const SizedBox(height: TablTokens.espaceM),
            Wrap(
              spacing: TablTokens.espaceS,
              runSpacing: TablTokens.espaceS,
              children: [
                for (final famille in famillesCuisine.keys)
                  TablPuceSelection(
                    libelle: famille,
                    selectionnee: _selection.contains(famille),
                    onBascule: () => setState(() {
                      if (!_selection.remove(famille)) _selection.add(famille);
                    }),
                  ),
              ],
            ),
            const SizedBox(height: TablTokens.espaceL),
            TablBouton(
              libelle: 'Appliquer',
              onPresse: () => Navigator.of(context).pop(_selection),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonRond extends StatelessWidget {
  const _BoutonRond({
    required this.icone,
    required this.libelle,
    required this.onPresse,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TablTokens.surface,
      shape: const CircleBorder(side: BorderSide(color: TablTokens.bordure)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPresse,
        tooltip: libelle,
        icon: Icon(icone, size: 20),
        color: TablTokens.primaire,
      ),
    );
  }
}
