import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_explorer_dev.dart';

/// Explorer — la carte de Tabl (megaprompt Bloc 1) : "je vois
/// instantanément les endroits que mon monde connaît", jamais "je
/// regarde une base de données de restaurants".
///
/// Aucun SDK cartographique natif n'est installé dans le projet (pas de
/// clé API configurée) : la zone de carte projette les coordonnées des
/// restaurants sur un plan simplifié, pannable/zoomable via
/// `InteractiveViewer`, plutôt que d'afficher un vrai fond de carte. Le
/// contrat de données (`CarteService`, `ObjetCartographique`) est conçu
/// pour être réutilisé sans changement le jour où un vrai SDK
/// (Mapbox/Google Maps) est branché — seule cette zone de rendu serait
/// remplacée.
class EcranExplorer extends StatefulWidget {
  const EcranExplorer({
    super.key,
    required this.carteService,
    required this.abonnementService,
    required this.raccourcisVillesService,
    required this.entitlementService,
  });

  final CarteService carteService;
  final AbonnementService abonnementService;
  final RaccourcisVillesService raccourcisVillesService;
  final EntitlementService entitlementService;

  @override
  State<EcranExplorer> createState() => _EcranExplorerState();
}

class _EcranExplorerState extends State<EcranExplorer> {
  final _controleurSheet = ControleurSheetCarte();

  ModeCarte _mode = ModeCarte.leCercle;
  PorteeSociale _portee = PorteeSociale.procheDirect;
  PeriodeCarte _periode = PeriodeCarte.unAn;

  bool _chargement = true;
  bool _erreur = false;
  bool _estPremium = false;
  List<String> _mesVilles = const [];
  String? _villeActive;
  List<AgregatVille> _agregatsVilles = const [];
  List<RestaurantMarqueur> _restaurants = const [];
  List<({String id, String pseudo})> _amis = const [];

  String? _amiSelectionneId;
  String? _restaurantSelectionneId;
  Set<String>? _clusterOuvert;
  bool _vueListe = false;

  @override
  void initState() {
    super.initState();
    _controleurSheet.addListener(_surChangementSheet);
    _chargerTout();
  }

  @override
  void dispose() {
    _controleurSheet.removeListener(_surChangementSheet);
    _controleurSheet.dispose();
    super.dispose();
  }

  void _surChangementSheet() {
    // Laisse l'animation d'ouverture/fermeture se dérouler puis
    // confirme l'état stable — pas de vrai contrôleur d'animation ici,
    // la sheet elle-même s'anime via AnimatedSize/AnimatedSlide au
    // niveau du build.
    setState(() {});
  }

  Future<void> _chargerTout() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final resultats = await Future.wait([
        widget.raccourcisVillesService.mesVilles(),
        widget.entitlementService.aReseauEtendu(),
        widget.abonnementService.mesRelations(),
      ]);
      final mesVilles = resultats[0] as List<String>;
      final estPremium = resultats[1] as bool;
      final amis = resultats[2] as List<ProfilPublic>;

      final agregats = await widget.carteService.agregatsVilles(
        mode: _mode,
        portee: _portee,
        periode: _periode,
      );

      final villeActive = mesVilles.firstWhere(
        (v) => agregats.any((a) => a.ville == v),
        orElse: () => agregats.isNotEmpty ? agregats.first.ville : '',
      );

      if (!mounted) return;
      setState(() {
        _mesVilles = mesVilles;
        _estPremium = estPremium;
        _amis = amis.map((a) => (id: a.id, pseudo: a.pseudo)).toList();
        _agregatsVilles = agregats;
        _villeActive = villeActive.isEmpty ? null : villeActive;
        _chargement = false;
      });
      if (_villeActive != null) await _chargerRestaurantsVille();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  Future<void> _chargerRestaurantsVille() async {
    final ville = _villeActive;
    if (ville == null) return;
    try {
      final restaurants = await widget.carteService.restaurantsPourVille(
        ville: ville,
        mode: _mode,
        portee: _portee,
        periode: _periode,
        amiSelectionneId: _amiSelectionneId,
      );
      if (!mounted) return;
      setState(() {
        _restaurants = restaurants;
        _clusterOuvert = null;
        _restaurantSelectionneId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _restaurants = const []);
    }
  }

  void _changerMode(ModeCarte mode) {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    _chargerTout();
  }

  void _changerVille(String ville) {
    if (ville == _villeActive) return;
    setState(() => _villeActive = ville);
    _chargerRestaurantsVille();
  }

  void _changerPeriode(PeriodeCarte periode) {
    _controleurSheet.fermer();
    setState(() => _periode = periode);
    _chargerRestaurantsVille();
  }

  void _changerPortee(PorteeSociale portee) {
    setState(() => _portee = portee);
    _chargerRestaurantsVille();
  }

  void _changerAmi(String? amiId) {
    _controleurSheet.fermer();
    setState(() => _amiSelectionneId = amiId);
    _chargerRestaurantsVille();
  }

  Future<void> _ajouterVille(String ville) async {
    await widget.raccourcisVillesService.ajouterVille(ville);
    if (!mounted) return;
    setState(() => _mesVilles = [..._mesVilles, ville]);
    _controleurSheet.fermer();
    _changerVille(ville);
  }

  Future<void> _retirerVille(String ville) async {
    await widget.raccourcisVillesService.retirerVille(ville);
    if (!mounted) return;
    setState(() => _mesVilles = _mesVilles.where((v) => v != ville).toList());
  }

  Future<void> _basculerGarder(String restaurantId, bool garder) async {
    await widget.carteService.basculerGarder(restaurantId, garder: garder);
    await _chargerRestaurantsVille();
  }

  RestaurantMarqueur? get _restaurantSelectionne {
    final id = _restaurantSelectionneId;
    if (id == null) return null;
    for (final r in _restaurants) {
      if (r.id == id) return r;
    }
    return null;
  }

  List<ObjetCartographique> get _objetsAffiches {
    final individuels = <RestaurantMarqueur>[];
    final aRegrouper = <RestaurantMarqueur>[];
    for (final r in _restaurants) {
      if (_clusterOuvert != null && _clusterOuvert!.contains(r.id)) {
        individuels.add(r);
      } else {
        aRegrouper.add(r);
      }
    }
    // Rayon de grille fixe pour cette itération (pas de vrai niveau de
    // zoom cartographique) — cluster ou enfants, jamais les deux
    // (règle 24), garanti par construction dans `regrouperEnClusters`.
    return [
      ...regrouperEnClusters(aRegrouper, rayonDegres: 0.01),
      ...individuels,
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        backgroundColor: TablTokens.fond,
        body: Center(
          child: CircularProgressIndicator(color: TablTokens.primaire),
        ),
      );
    }
    if (_erreur) {
      return Scaffold(
        backgroundColor: TablTokens.fond,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Impossible de charger la carte.', style: TablTokens.corps),
              const SizedBox(height: TablTokens.espaceM),
              OutlinedButton(onPressed: _chargerTout, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          children: [
            _entete(),
            Expanded(child: _corps()),
          ],
        ),
      ),
    );
  }

  Widget _entete() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceM,
        TablTokens.espaceS,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (_villeActive != null)
                Text(_villeActive!.toUpperCase(), style: TablTokens.titre),
              if (kDebugMode) ...[
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.bug_report_outlined, color: TablTokens.texteDoux),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const EcranExplorerDev()),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: TablTokens.espaceS),
          TablSegmentModeCarte(
            options: const ['Ma carte', 'Envies', 'Réseau'],
            selectionne: ModeCarte.values.indexOf(_mode),
            onSelection: (i) => _changerMode(ModeCarte.values[i]),
          ),
          const SizedBox(height: TablTokens.espaceS),
          TablRaccourcisVilles(
            villes: _mesVilles,
            villeActive: _villeActive,
            onSelection: _changerVille,
            onAjouter: () => _controleurSheet.ouvrir(SheetCarte.villes),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            children: [
              Text(_libellePortee, style: TablTokens.legende),
              const Spacer(),
              TextButton(
                onPressed: () => _controleurSheet.ouvrir(SheetCarte.periode),
                child: Text('$_libellePeriode ▾', style: TablTokens.legende),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Aligné index à index avec [_valeursReseau] : "Les deux" n'existe
  /// même pas comme option pour un compte gratuit (règle 14), plutôt que
  /// d'apparaître désactivé.
  List<({String libelle, bool verrouille})> get _optionsReseau => [
    (libelle: 'Mes proches', verrouille: false),
    (libelle: 'Réseau étendu', verrouille: !_estPremium),
    if (_estPremium) (libelle: 'Les deux', verrouille: false),
  ];

  List<PorteeSociale> get _valeursReseau => [
    PorteeSociale.procheDirect,
    PorteeSociale.reseauEtendu,
    if (_estPremium) PorteeSociale.lesDeux,
  ];

  double _diametrePourTaille(TailleMarqueur taille) => switch (taille) {
    TailleMarqueur.small => 14,
    TailleMarqueur.medium => 20,
    TailleMarqueur.large => 28,
  };

  String get _libellePortee => switch (_portee) {
    PorteeSociale.procheDirect => 'Mes proches',
    PorteeSociale.reseauEtendu => 'Réseau étendu',
    PorteeSociale.lesDeux => 'Les deux',
  };

  String get _libellePeriode => switch (_periode) {
    PeriodeCarte.troisMois => '3 derniers mois',
    PeriodeCarte.unAn => '1 an',
    PeriodeCarte.tout => 'Tout',
  };

  Widget _corps() {
    return Stack(
      children: [
        Positioned.fill(child: _vueListe ? _listeCercle() : _zoneCarte()),
        Positioned(
          top: TablTokens.espaceS,
          right: TablTokens.espaceM,
          child: _boutonFiltres(),
        ),
        Positioned(
          bottom: TablTokens.espaceM,
          right: TablTokens.espaceM,
          child: Column(
            children: [
              _boutonUtility(
                icone: _vueListe ? Icons.map_outlined : Icons.list,
                libelle: _vueListe ? 'Afficher la carte' : 'Afficher les adresses en liste',
                onTap: () => setState(() => _vueListe = !_vueListe),
              ),
              const SizedBox(height: TablTokens.espaceS),
              if (!_vueListe)
                _boutonUtility(
                  icone: Icons.my_location,
                  libelle: 'Recentrer',
                  onTap: () => afficherMessage(context, 'Localisation à venir.'),
                ),
            ],
          ),
        ),
        if (_restaurantSelectionne != null && !_vueListe)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _preview(_restaurantSelectionne!),
          ),
        // `etat != fermee`, pas `sheetActive != null` : sinon la sheet
        // reste montée pour toujours après un premier `fermer()`, puisque
        // `_sheetActive` n'est remis à `null` que par `confirmerFermee()`
        // (appelée ci-dessous, via `onEnd`) — bug réel trouvé en testant
        // l'app pour de vrai (tap sur le fond, ou changement de
        // période/ami, ne refermait jamais rien après la 1ʳᵉ ouverture).
        if (_controleurSheet.etat != EtatAnimationSheet.fermee)
          _overlaySheet(),
      ],
    );
  }

  Widget _zoneCarte() {
    if (_restaurants.isEmpty) {
      return Center(child: _zoneVide());
    }

    final reduireMouvement = MediaQuery.of(context).disableAnimations;
    final bounds = _limites(_restaurants);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6,
      child: LayoutBuilder(
        builder: (context, contraintes) {
          return Stack(
            children: [
              for (final objet in _objetsAffiches)
                _positionneObjet(objet, bounds, contraintes.biggest, reduireMouvement),
            ],
          );
        },
      ),
    );
  }

  ({double latMin, double latMax, double lngMin, double lngMax}) _limites(
    List<RestaurantMarqueur> restaurants,
  ) {
    var latMin = restaurants.first.latitude;
    var latMax = restaurants.first.latitude;
    var lngMin = restaurants.first.longitude;
    var lngMax = restaurants.first.longitude;
    for (final r in restaurants) {
      if (r.latitude < latMin) latMin = r.latitude;
      if (r.latitude > latMax) latMax = r.latitude;
      if (r.longitude < lngMin) lngMin = r.longitude;
      if (r.longitude > lngMax) lngMax = r.longitude;
    }
    // Marge pour ne pas coller les marqueurs au bord, et éviter une
    // division par zéro si tous les points sont au même endroit.
    const marge = 0.01;
    return (
      latMin: latMin - marge,
      latMax: latMax + marge,
      lngMin: lngMin - marge,
      lngMax: lngMax + marge,
    );
  }

  Widget _positionneObjet(
    ObjetCartographique objet,
    ({double latMin, double latMax, double lngMin, double lngMax}) bounds,
    Size taille,
    bool reduireMouvement,
  ) {
    final (lat, lng) = switch (objet) {
      RestaurantMarqueur r => (r.latitude, r.longitude),
      ClusterRestaurants c => (c.latitude, c.longitude),
      AgregatVille a => (a.latitude, a.longitude),
      PositionUtilisateur p => (p.latitude, p.longitude),
    };
    final x = ((lng - bounds.lngMin) / (bounds.lngMax - bounds.lngMin)) * taille.width;
    final y = (1 - (lat - bounds.latMin) / (bounds.latMax - bounds.latMin)) * taille.height;

    return Positioned(
      left: x - 22,
      top: y - 22,
      child: switch (objet) {
        RestaurantMarqueur r => TablMarqueurRestaurant(
            diametre: _diametrePourTaille(r.taille),
            selectionne: r.id == _restaurantSelectionneId,
            connuUniquementReseauEtendu: r.procheDirectCompte == 0 && r.reseauEtenduCompte != null,
            aDeLaRecurrence: r.aDeLaRecurrence,
            libelleAccessibilite:
                '${r.nom}, ${r.ville}, connu par ${r.procheDirectCompte} proches.',
            onTap: () => setState(() => _restaurantSelectionneId = r.id),
          ),
        ClusterRestaurants c => TablMarqueurCluster(
            nombreRestaurants: c.nombreRestaurants,
            onTap: () => setState(() => _clusterOuvert = c.idsRestaurants.toSet()),
          ),
        AgregatVille a => TablMarqueurAgregatVille(
            ville: a.ville,
            nombreRestaurants: a.nombreRestaurants,
            onTap: () => _changerVille(a.ville),
          ),
        PositionUtilisateur p => TablMarqueurPositionUtilisateur(
            precisionFaible: p.precisionMetres > 50,
            capDegres: p.capDegres,
          ),
      },
    );
  }

  Widget _listeCercle() {
    if (_restaurants.isEmpty) {
      return Center(child: _zoneVide());
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: TablTokens.espaceM,
        vertical: TablTokens.espaceS,
      ),
      itemCount: _restaurants.length + 1,
      separatorBuilder: (_, _) => const Divider(color: TablTokens.bordure, height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: TablTokens.espaceS),
            child: Text('Dans votre réseau', style: TablTokens.sousTitre),
          );
        }
        final r = _restaurants[index - 1];
        return TablLigneListeCercle(
          nom: r.nom,
          sousTitreLieu: r.quartier ?? r.ville,
          procheDirectResume: r.procheDirectResume,
          recurrenceResume: r.aDeLaRecurrence ? '★ Ils y retournent' : '',
          onTap: () => setState(() {
            _vueListe = false;
            _restaurantSelectionneId = r.id;
          }),
        );
      },
    );
  }

  /// Zone vide (règle 48) : jamais artificiellement grossie, et une
  /// suggestion honnête d'autres villes déjà connues plutôt qu'un
  /// message figé si le cercle a des adresses ailleurs.
  Widget _zoneVide() {
    final autresVilles = _agregatsVilles.where((a) => a.ville != _villeActive).toList();
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Peu d\'adresses de vos proches ici.',
            style: TablTokens.corps,
            textAlign: TextAlign.center,
          ),
          if (autresVilles.isNotEmpty) ...[
            const SizedBox(height: TablTokens.espaceM),
            Wrap(
              spacing: TablTokens.espaceS,
              runSpacing: TablTokens.espaceS,
              alignment: WrapAlignment.center,
              children: [
                for (final agregat in autresVilles)
                  TablMarqueurAgregatVille(
                    ville: agregat.ville,
                    nombreRestaurants: agregat.nombreRestaurants,
                    onTap: () => _changerVille(agregat.ville),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _preview(RestaurantMarqueur r) {
    return TablPreviewRestaurantCarte(
      nom: r.nom,
      sousTitreLieu: r.quartier == null ? r.ville : '${r.quartier} · ${r.ville}',
      procheDirectResume: r.procheDirectResume,
      recurrenceResume: r.aDeLaRecurrence ? '★ ${r.procheDirectResume.isEmpty ? "Votre réseau revient ici" : "2 y sont retournés"}' : '',
      emotionsRepresentatives: r.emotionsRepresentatives,
      reseauEtenduResume: r.reseauEtenduCompte == null || r.reseauEtenduCompte == 0
          ? ''
          : '+${r.reseauEtenduCompte} personnes dans votre réseau étendu',
      dejaVisiteParMoi: r.dejaVisiteParMoi,
      dejaGardeParMoi: r.dejaGardeParMoi,
      onBasculerGarder: (garder) => _basculerGarder(r.id, garder),
      onVoir: () {},
      onFermer: () => setState(() => _restaurantSelectionneId = null),
    );
  }

  Widget _boutonFiltres() {
    final actifs = _amiSelectionneId != null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _boutonUtility(
          icone: Icons.tune,
          libelle: 'Filtres',
          onTap: () => _controleurSheet.ouvrir(SheetCarte.filtres),
        ),
        if (actifs)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: TablTokens.primaire,
              ),
            ),
          ),
      ],
    );
  }

  Widget _boutonUtility({
    required IconData icone,
    required String libelle,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: libelle,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: TablTokens.surface.withValues(alpha: 0.94),
            border: Border.all(color: TablTokens.bordure),
          ),
          alignment: Alignment.center,
          child: Icon(icone, size: 18, color: TablTokens.texte),
        ),
      ),
    );
  }

  Widget _overlaySheet() {
    final sheet = _controleurSheet.sheetActive!;
    // Visible pendant `ouverture` (anime vers l'état ouvert) et `ouverte`
    // (stable) ; anime vers fermé sinon. `onEnd` de l'AnimatedSlide (une
    // seule des deux animations suffit, même durée) confirme la
    // transition au contrôleur — c'est ce qui, une fois confirmé,
    // remonte `_sheetActive` à `null` et démonte réellement cette sheet.
    final visible = _controleurSheet.etat == EtatAnimationSheet.ouverture ||
        _controleurSheet.etat == EtatAnimationSheet.ouverte;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _controleurSheet.fermer,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: visible ? 1 : 0,
              child: Container(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              offset: visible ? Offset.zero : const Offset(0, 1),
              onEnd: () {
                if (_controleurSheet.etat == EtatAnimationSheet.ouverture) {
                  _controleurSheet.confirmerOuverte();
                } else if (_controleurSheet.etat ==
                    EtatAnimationSheet.fermeture) {
                  _controleurSheet.confirmerFermee();
                }
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: TablTokens.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(TablTokens.arrondiL),
                  ),
                ),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                // Material au plus près du contenu (pas autour du
                // Container décoré) : sinon le fond opaque du Container
                // peint par-dessus les ink splashes des ListTile.
                child: Material(
                  color: Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(TablTokens.arrondiL),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _contenuSheet(sheet),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contenuSheet(SheetCarte sheet) {
    return switch (sheet) {
      SheetCarte.periode => TablSheetPeriode(
          options: const ['3 derniers mois', '1 an', 'Tout'],
          selectionneIndex: PeriodeCarte.values.indexOf(_periode),
          onSelection: (i) => _changerPeriode(PeriodeCarte.values[i]),
        ),
      SheetCarte.filtres => TablSheetFiltres(
          optionsReseau: _optionsReseau,
          reseauSelectionneIndex: _valeursReseau.contains(_portee)
              ? _valeursReseau.indexOf(_portee)
              : null,
          amis: _amis,
          amiSelectionneId: _amiSelectionneId,
          onReseauSelection: (i) => _changerPortee(_valeursReseau[i]),
          onAmiChange: _changerAmi,
          onOuvrirPremium: () => _controleurSheet.ouvrir(SheetCarte.premium),
        ),
      SheetCarte.villes => TablSheetVilles(
          mesVilles: _mesVilles,
          onAjouter: _ajouterVille,
          onRetirer: _retirerVille,
        ),
      SheetCarte.premium => Padding(
          padding: const EdgeInsets.all(TablTokens.espaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Réseau étendu', style: TablTokens.sousTitre),
              SizedBox(height: TablTokens.espaceS),
              Text(
                'Découvrez ce que le réseau de confiance de vos abonnements '
                'connaît, toujours de façon anonyme — réservé aux comptes '
                'Premium.',
                style: TablTokens.corps,
              ),
            ],
          ),
        ),
      SheetCarte.amis || SheetCarte.restaurant => const SizedBox.shrink(),
    };
  }
}
