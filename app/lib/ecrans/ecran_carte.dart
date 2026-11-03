import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import '../config_mapbox.dart';

import 'feuille_demander_avis.dart';
import 'feuille_filtres_explorer.dart';
import 'vue_constellation.dart';
import 'feuille_restaurant.dart';
import 'recherche_explorer.dart';

/// L'onglet Explorer, d'après la maquette de Martin (novembre 2026) :
/// « où manger, d'après les gens en qui j'ai confiance ? ».
///
/// En haut, la ville qu'on regarde (un tap pour en changer), le nombre
/// d'adresses et « Constellation » (ma carte à moi, ville par ville) ;
/// en bas, une barre flottante : Rechercher, les filtres, Carte |
/// Grille. La grille montre les lieux de la zone regardée en tuiles
/// colorées (nuit : mon cercle ; braise : ils y retournent ; ivoire :
/// j'y suis allé), triées au choix. Sur la carte, un tap sur un lieu
/// ouvre son aperçu en bas, qu'on balaie pour passer au voisin.
///
/// En clair ou en sombre selon le réglage « Apparence » ; la
/// Constellation reste de nuit. S'ouvre sur « Le cercle », ou sur la
/// Constellation si c'est là qu'on était.
class EcranCarte extends StatefulWidget {
  const EcranCarte({
    super.key,
    required this.carteService,
    this.positionService,
    this.tableService,
    this.abonnementService,
    this.souvenirService,
    this.avisService,
    this.rechercheEndroit,
    this.filtresInitiaux = FiltresCarte.aucun,
    this.estOnglet = true,
    this.afficherCarte = true,
    this.onImmersion,
  });

  final CarteService carteService;

  /// `null` : la carte démarre sur la Belgique, sans bouton "ma position"
  /// ni distances.
  final PositionService? positionService;

  /// Pour le filtre "Une Table" et « Proposer ». `null` : ni l'un ni
  /// l'autre.
  final TableService? tableService;

  /// Pour le filtre "Personnes" (celles que je suis). `null` : masqué.
  final AbonnementService? abonnementService;

  /// Pour la fiche d'un restaurant. `null` : pas de fiche.
  final SouvenirService? souvenirService;

  /// Pour « Demander » un avis à un proche qui y est allé. `null` : pas
  /// de bouton.
  final AvisService? avisService;

  /// Filtres appliqués à l'ouverture ("Voir sur la carte" depuis une
  /// Table ouvre la carte déjà filtrée sur cette Table).
  /// Pour chercher une ville, un quartier, une adresse. `null` : le
  /// géocodage de Mapbox, construit à la demande (jamais dans les tests).
  final RechercheEndroitService? rechercheEndroit;

  final FiltresCarte filtresInitiaux;

  /// `false` quand l'Explorer est ouvert par-dessus un autre écran :
  /// bouton retour, et pas de barre de navigation à éviter en bas.
  final bool estOnglet;

  /// `false` dans les tests : la carte Mapbox est une vue native,
  /// indisponible hors d'un vrai appareil — le reste de l'écran reste
  /// testable.
  final bool afficherCarte;

  /// `true` quand la Constellation s'ouvre en plein écran, `false` quand on
  /// en sort : l'écran qui l'accueille cache alors ce qui l'entoure.
  final ValueChanged<bool>? onImmersion;

  @override
  State<EcranCarte> createState() => _EcranCarteState();
}

class _EcranCarteState extends State<EcranCarte> {
  static const _cleMode = 'explorer_mode';

  /// Place occupée en bas par la barre de navigation flottante.
  double get _margeBarre => widget.estOnglet
      ? TablBarreNavigation.hauteurOccupee(context)
      : MediaQuery.paddingOf(context).bottom;

  final _controleur = ControleurCarte();

  /// Hauteur de l'en-tête posé sur la carte, mesurée à chaque image.
  final _cleEnTete = GlobalKey();
  double _hauteurEnTete = 190;

  /// « Le cercle », ou la Constellation (« Ma carte ») ; les envies
  /// passent par le marque-page des tuiles.
  ModeExplorer _mode = ModeExplorer.cercle;
  bool _enGrille = true;
  late FiltresCarte _filtres = widget.filtresInitiaux;
  TriCercle _tri = TriCercle.recents;

  /// Zone visible ; la Belgique tant que la carte ne l'a pas encore dite.
  ZoneCarte _zone = const ZoneCarte(
    sud: 49.4,
    ouest: 2.5,
    nord: 51.6,
    est: 6.5,
  );
  double _zoom = 6.5;

  /// Tous les lieux du mode, filtres appliqués par la base : chargés
  /// d'un coup, pour que les bulles chiffrées comptent juste à tous les
  /// zooms.
  List<LieuCarte> _lieux = const [];
  bool _chargement = false;
  bool _chargeUneFois = false;
  bool _enErreur = false;
  int _demande = 0;

  List<ResumeTable> _tables = const [];
  List<ProfilPublic> _personnes = const [];
  Coordonnees? _position;

  /// Le lieu dont l'aperçu est ouvert, et ses voisins (du plus proche au
  /// plus loin) pour passer de l'un à l'autre d'un balayage.
  LieuCarte? _selection;
  List<LieuCarte> _voisins = const [];

  /// Les adresses affichables des photos déjà demandées, par chemin.
  final Map<String, String> _photos = {};
  final Set<String> _photosDemandees = {};

  @override
  void initState() {
    super.initState();
    _restaurerMode();
    _chargerTables();
    _chargerPersonnes();
    _localiser();
    WidgetsBinding.instance.addPostFrameCallback((_) => _mesurerEnTete());
  }

  @override
  void dispose() {
    _fermetureEnAttente?.cancel();
    super.dispose();
  }

  void _mesurerEnTete() {
    final boite = _cleEnTete.currentContext?.findRenderObject() as RenderBox?;
    if (boite == null || !boite.hasSize) return;
    final h = boite.size.height;
    if ((h - _hauteurEnTete).abs() > 1 && mounted) {
      setState(() => _hauteurEnTete = h);
    }
  }

  // ---------------------------------------------------------------
  //  Données
  // ---------------------------------------------------------------

  Future<void> _restaurerMode() async {
    // Ouvert depuis une Table : toujours sur « Le cercle ».
    if (widget.estOnglet) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final valeur = prefs.getString(_cleMode);
        // Les envies ne sont plus un mode : « Le cercle ».
        if (valeur == ModeExplorer.maCarte.name && mounted) {
          setState(() => _mode = ModeExplorer.maCarte);
          widget.onImmersion?.call(true);
        }
      } catch (_) {
        // Pas de préférence lisible : « Le cercle ».
      }
    }
    _charger();
  }

  Future<void> _choisirMode(ModeExplorer mode) async {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _selection = null;
      _lieux = const [];
    });
    widget.onImmersion?.call(mode == ModeExplorer.maCarte);
    _charger();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cleMode, mode.name);
    } catch (_) {}
  }

  /// Recharge les lieux du mode avec les filtres actuels, pour le monde
  /// entier : déplacer la carte ne demande rien de plus à la base.
  Future<void> _charger() async {
    final numero = ++_demande;
    setState(() => _chargement = true);
    try {
      final lieux = await widget.carteService.lieuxReseau(
        ZoneCarte.monde,
        _filtres,
        mode: _mode,
      );
      if (!mounted || numero != _demande) return;
      setState(() {
        _lieux = lieux;
        _chargeUneFois = true;
        _enErreur = false;
        // Le lieu ouvert, à jour (ou fermé s'il n'est plus là).
        final s = _selection;
        if (s != null) {
          _selection = lieux.where((l) => l.cle == s.cle).firstOrNull;
        }
      });
      _demanderPhotos();
    } catch (e) {
      debugPrint('EcranCarte: chargement : $e');
      if (mounted && numero == _demande) {
        setState(() => _enErreur = true);
        afficherMessage(context, messageErreurGenerique);
      }
    } finally {
      if (mounted && numero == _demande) {
        setState(() => _chargement = false);
      }
    }
  }

  void _appliquerFiltres(FiltresCarte filtres) {
    setState(() {
      _filtres = filtres;
      _selection = null;
    });
    _charger();
  }

  Future<void> _chargerTables() async {
    try {
      final tables = await widget.tableService?.mesTables() ?? const [];
      if (mounted) setState(() => _tables = tables);
    } catch (e) {
      debugPrint('EcranCarte: tables : $e');
    }
  }

  Future<void> _chargerPersonnes() async {
    try {
      final listes = await widget.abonnementService?.abonnesEtAbonnements();
      if (mounted && listes != null) {
        setState(() => _personnes = listes.abonnements);
      }
    } catch (e) {
      debugPrint('EcranCarte: personnes : $e');
    }
  }

  Future<void> _localiser({bool recentrer = true}) async {
    final position = await widget.positionService?.positionActuelle();
    if (!mounted || position == null) return;
    setState(() => _position = position);
    if (recentrer) {
      await _controleur.centrerSur(
        position.latitude,
        position.longitude,
        zoom: 13,
      );
    }
  }

  /// Signe les photos de ce qui s'affiche (la liste, l'aperçu) — jamais
  /// des milliers d'un coup.
  Future<void> _demanderPhotos() async {
    final aAfficher = [
      ?_selection,
      for (final l in _voisins.take(3)) l,
      if (_enGrille) ..._lieuxListe.take(24),
    ];
    final chemins = {
      for (final l in aAfficher)
        if (l.cheminPhoto != null && !_photosDemandees.contains(l.cheminPhoto))
          l.cheminPhoto!,
    };
    if (chemins.isEmpty) return;
    _photosDemandees.addAll(chemins);
    try {
      final liens = await widget.carteService.photos(chemins);
      if (mounted) setState(() => _photos.addAll(liens));
    } catch (e) {
      debugPrint('EcranCarte: photos : $e');
      _photosDemandees.removeAll(chemins);
    }
  }

  String? _photo(LieuCarte l) =>
      l.cheminPhoto == null ? null : _photos[l.cheminPhoto];

  // ---------------------------------------------------------------
  //  Ce qu'on regarde
  // ---------------------------------------------------------------

  void _zoneVisible(
    double sud,
    double ouest,
    double nord,
    double est,
    double zoom,
  ) {
    setState(() {
      _zone = ZoneCarte(sud: sud, ouest: ouest, nord: nord, est: est);
      _zoom = zoom;
    });
  }

  double? _distance(LieuCarte lieu) {
    final p = _position;
    if (p == null) return null;
    return distanceEnMetres(
      p.latitude,
      p.longitude,
      lieu.latitude,
      lieu.longitude,
    );
  }

  List<LieuCarte> get _lieuxVisibles => [
    for (final l in _lieux)
      if (_zone.contient(l.latitude, l.longitude)) l,
  ];

  List<VilleCercle> get _villes => villesDuCercle(_lieux);

  /// La ville regardée : la plus proche du centre de la carte, si on est
  /// assez près pour que ça ait un sens.
  VilleCercle? get _villeRegardee {
    if (_zoom < 8) return null;
    return villeRegardee(
      _villes,
      (_zone.sud + _zone.nord) / 2,
      (_zone.ouest + _zone.est) / 2,
    );
  }

  String get _titre =>
      _villeRegardee?.nom ??
      switch (_mode) {
        ModeExplorer.cercle => 'Votre cercle',
        ModeExplorer.envies => 'Envies',
        ModeExplorer.maCarte => 'Constellation',
      };

  /// Sous le titre : ce qu'on trouve dans la zone regardée.
  String _sousTitre(int nombre) {
    if (_mode == ModeExplorer.envies && _villeRegardee == null) {
      return 'Les adresses que vous gardez pour plus tard.';
    }
    return _compte(nombre);
  }

  String _compte(int n) => switch (_mode) {
    ModeExplorer.cercle => adressesDuCercle(n),
    ModeExplorer.envies => switch (n) {
      0 => 'Aucune envie ici',
      1 => '1 adresse gardée pour plus tard',
      _ => '$n adresses gardées pour plus tard',
    },
    ModeExplorer.maCarte => switch (n) {
      0 => 'Vous n\'êtes encore allé nulle part ici',
      1 => '1 adresse où vous êtes allé',
      _ => '$n adresses où vous êtes allé',
    },
  };

  /// La grille : les lieux de la zone regardée, dans l'ordre du tri ;
  /// pour « Ma carte », tous (elle raconte toute mon histoire, ville par
  /// ville).
  List<LieuCarte> get _lieuxListe => trierLieux(
    _mode == ModeExplorer.maCarte ? _lieux : _lieuxVisibles,
    _tri,
    position: _position,
  );

  /// « Rechercher » : un endroit où aller (par défaut), ou un restaurant
  /// par son nom, dont la fiche s'ouvre.
  Future<void> _ouvrirRecherche() async {
    final p = _position;
    final choix = await ouvrirRechercheExplorer(
      context,
      ici: _lieuxVisibles,
      ailleurs: [
        for (final l in _lieux)
          if (!_zone.contient(l.latitude, l.longitude)) l,
      ],
      villes: _villes,
      rechercheEndroit:
          widget.rechercheEndroit ?? RechercheEndroitMapbox(ConfigMapbox.token),
      compte: _compte,
      position: p == null
          ? null
          : (latitude: p.latitude, longitude: p.longitude),
    );
    if (!mounted || choix == null) return;
    setState(() => _selection = null);
    switch (choix) {
      case EndroitChoisi(:final zone):
        await _allerVers(zone);
      case AutourDeMoiChoisi():
        if (p != null) {
          await _controleur.centrerSur(p.latitude, p.longitude, zoom: 13.5);
        }
      case AdresseChoisie(:final lieu):
        _ouvrirFiche(lieu);
    }
  }

  /// Cadre [zone] : la carte s'y rend, la grille montre ce qui s'y trouve.
  Future<void> _allerVers(ZoneCarte zone) async {
    // Sans carte (tests), la zone se règle d'elle-même.
    if (!widget.afficherCarte) {
      setState(() {
        _zone = zone;
        _zoom = 12;
      });
    }
    await _controleur.cadrer(
      sud: zone.sud,
      ouest: zone.ouest,
      nord: zone.nord,
      est: zone.est,
      haut: _hauteurEnTete,
      bas: _margeBarre,
    );
  }

  Future<void> _ouvrirOuChercher() async {
    final choix = await ouvrirOuChercher(
      context,
      villes: _villes,
      villeActuelle: _villeRegardee?.nom,
      positionConnue: _position != null,
      compte: _compte,
    );
    if (!mounted || choix == null) return;
    setState(() => _selection = null);
    if (choix == autourDeMoi) {
      final p = _position;
      if (p != null) {
        await _controleur.centrerSur(p.latitude, p.longitude, zoom: 13.5);
      }
      return;
    }
    if (choix is VilleCercle) await _allerVers(choix.zone);
  }

  // ---------------------------------------------------------------
  //  Un lieu
  // ---------------------------------------------------------------

  /// Un tap sur la carte ferme l'aperçu, mais un court instant plus
  /// tard : si ce tap était en fait sur un lieu, son ouverture l'annule.
  Timer? _fermetureEnAttente;

  void _tapCarte() {
    _fermetureEnAttente?.cancel();
    _fermetureEnAttente = Timer(const Duration(milliseconds: 80), () {
      if (mounted && _selection != null) setState(() => _selection = null);
    });
  }

  void _tapLieu(String cle) {
    _fermetureEnAttente?.cancel();
    final lieu = _lieux.where((l) => l.cle == cle).firstOrNull;
    if (lieu == null) return;
    _choisir(lieu, voisinsDepuis: lieu);
  }

  /// Ouvre l'aperçu de [lieu] ; ses voisins sont rangés depuis
  /// [voisinsDepuis] (le premier lieu touché), pour que balayer en avant
  /// puis en arrière ramène au même endroit.
  void _choisir(LieuCarte lieu, {LieuCarte? voisinsDepuis}) {
    final depuis = voisinsDepuis;
    setState(() {
      _selection = lieu;
      if (depuis != null) {
        double d(LieuCarte l) => distanceEnMetres(
          depuis.latitude,
          depuis.longitude,
          l.latitude,
          l.longitude,
        );
        _voisins = [..._lieuxVisibles]..sort((a, b) => d(a).compareTo(d(b)));
        if (!_voisins.any((l) => l.cle == lieu.cle)) _voisins.insert(0, lieu);
      }
    });
    _demanderPhotos();
    // L'aperçu couvre le bas de la carte : si le lieu se retrouve
    // dessous, on le remonte juste au-dessus.
    final hauteur = (_zone.nord - lieu.latitude) / (_zone.nord - _zone.sud);
    if (hauteur > 0.5 || hauteur < 0.25) {
      _controleur.amenerA(lieu.latitude, lieu.longitude, hauteur: 0.4);
    }
  }

  void _voisin(int sens) {
    final s = _selection;
    if (s == null || _voisins.length < 2) return;
    final i = _voisins.indexWhere((l) => l.cle == s.cle);
    final j = (i + sens).clamp(0, _voisins.length - 1);
    if (j == i) return;
    _choisir(_voisins[j]);
  }

  Future<void> _ouvrirFiche(LieuCarte lieu) async {
    final souvenirs = widget.souvenirService;
    if (souvenirs == null) return;
    await ouvrirFeuilleRestaurant(
      context,
      nom: lieu.nom,
      sousTitre: lieu.description,
      resume: lieu.duReseau ? lieu.resumeVisites : null,
      restaurantId: lieu.restaurantId,
      estEnvie: lieu.estEnvie,
      photoUrl: _photo(lieu),
      souvenirService: souvenirs,
      abonnementService: widget.abonnementService,
      tableService: widget.tableService,
      avisService: widget.avisService,
      entrerDansTabl: () => widget.carteService.idRestaurant(lieu),
      onVoirSurLaCarte: widget.afficherCarte
          ? () => _montrerSurLaCarte(lieu)
          : null,
    );
    if (mounted) _charger();
  }

  /// Optimiste : l'étiquette change tout de suite, et revient si la base
  /// refuse.
  Future<void> _basculerEnvie(LieuCarte lieu) async {
    final envie = !lieu.estEnvie;
    void remplacer(bool valeur) => setState(() {
      _lieux = [
        for (final l in _lieux)
          if (l.cle == lieu.cle) l.copierAvec(estEnvie: valeur) else l,
      ];
      final s = _selection;
      if (s != null && s.cle == lieu.cle) {
        _selection = s.copierAvec(estEnvie: valeur);
      }
    });
    remplacer(envie);
    try {
      final id = await widget.carteService.idRestaurant(lieu);
      await widget.carteService.basculerEnvie(id, envie: envie);
      if (mounted) {
        afficherMessage(
          context,
          envie ? 'Ajouté à vos envies.' : 'Retiré de vos envies.',
        );
      }
    } catch (e) {
      debugPrint('EcranCarte: envie : $e');
      if (!mounted) return;
      remplacer(!envie);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  /// « Proposer » : à l'une de mes Tables, qui répondra GO ou non.
  Future<void> _proposer(LieuCarte lieu) async {
    final service = widget.tableService;
    if (service == null || _tables.isEmpty) return;
    final table = await showModalBottomSheet<ResumeTable>(
      context: context,
      backgroundColor: const Color(0xFF111216),
      showDragHandle: true,
      builder: (contexte) => SafeArea(
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
              'Proposer ${lieu.nom}',
              style: TablTokens.titreAffichage.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'À quelle Table ? Elle répondra GO ou non, puis on trouvera la date.',
              style: TablTokens.legende,
            ),
            const SizedBox(height: TablTokens.espaceM),
            for (final t in _tables)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  t.emoji ?? '🍽',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(t.nom, style: TablTokens.corps),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: TablTokens.texteDoux,
                ),
                onTap: () => Navigator.of(contexte).pop(t),
              ),
          ],
        ),
      ),
    );
    if (table == null || !mounted) return;
    try {
      final resultat = await service.proposer(
        tableId: table.id,
        nomRestaurant: lieu.nom,
        ville: lieu.ville,
      );
      if (!mounted) return;
      afficherMessage(
        context,
        resultat.dejaExistante
            ? 'Déjà proposé à ${table.nom}.'
            : 'Proposé à ${table.nom}.',
      );
    } catch (e) {
      debugPrint('EcranCarte: proposer : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  bool _peutDemander(LieuCarte lieu) =>
      widget.avisService != null &&
      widget.souvenirService != null &&
      lieu.restaurantId != null &&
      lieu.amis > 0;

  /// « Demander un avis » : à qui de mes proches qui y sont allés ? Leur
  /// liste vient de leurs moments ici.
  Future<void> _demander(LieuCarte lieu) async {
    final avis = widget.avisService;
    final souvenirs = widget.souvenirService;
    final id = lieu.restaurantId;
    if (avis == null || souvenirs == null || id == null) return;
    final List<SouvenirFeed> moments;
    try {
      moments = await souvenirs.souvenirsDuRestaurant(id);
    } catch (e) {
      debugPrint('EcranCarte: demander : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    final proches = resumerFiche(moments).connaissent;
    if (proches.isEmpty) {
      afficherMessage(context, 'Aucun proche à qui demander ici.');
      return;
    }
    await demanderUnAvis(
      context,
      avisService: avis,
      restaurantId: id,
      nom: lieu.nom,
      detail: cuisineEtQuartier(lieu),
      proches: proches,
    );
  }

  /// Sur la carte, de près, l'aperçu du lieu ouvert.
  Future<void> _montrerSurLaCarte(LieuCarte lieu) async {
    setState(() => _enGrille = false);
    await _controleur.centrerSur(lieu.latitude, lieu.longitude, zoom: 15.5);
    if (mounted) _choisir(lieu, voisinsDepuis: lieu);
  }

  // ---------------------------------------------------------------
  //  Filtres
  // ---------------------------------------------------------------

  Future<void> _ouvrirFiltres() async {
    final choisis = await ouvrirFiltresExplorer(
      context,
      filtres: _filtres,
      personnes: _personnes,
      tables: _tables,
      compter: _compterAvec,
    );
    if (choisis != null && mounted) _appliquerFiltres(choisis);
  }

  /// Combien d'adresses l'en-tête compterait avec [filtres], dans la
  /// zone regardée : « Voir 12 adresses » tient parole.
  Future<int> _compterAvec(FiltresCarte filtres) async {
    final lieux = await widget.carteService.lieuxReseau(
      ZoneCarte.monde,
      filtres,
      mode: _mode,
    );
    return lieux.where((l) => _zone.contient(l.latitude, l.longitude)).length;
  }

  /// Les filtres actifs, chacun avec de quoi le retirer.
  List<({String libelle, FiltresCarte sans})> get _filtresActifs {
    final f = _filtres;
    final pseudo = _personnes
        .where((p) => p.id == f.personneId)
        .firstOrNull
        ?.pseudo;
    final table = _tables.where((t) => t.id == f.tableId).firstOrNull?.nom;
    return [
      if (f.moment != null)
        (
          libelle: libelleMomentRepas(f.moment!) ?? f.moment!,
          sans: f.copierAvec(moment: () => null),
        ),
      if (f.periode != PeriodeCarte.tout)
        (
          libelle: f.periode.libelle,
          sans: f.copierAvec(periode: PeriodeCarte.tout),
        ),
      if (f.personneId != null)
        (
          libelle: pseudo ?? 'Une personne',
          sans: f.copierAvec(personneId: () => null),
        ),
      if (f.tableId != null)
        (
          libelle: table ?? 'Une Table',
          sans: f.copierAvec(tableId: () => null),
        ),
      for (final famille in f.familles)
        (
          libelle: famille,
          sans: f.copierAvec(familles: {...f.familles}..remove(famille)),
        ),
      if (f.jamaisEssaye)
        (libelle: 'Jamais essayé', sans: f.copierAvec(jamaisEssaye: false)),
      if (f.coupsDeCoeur)
        (libelle: 'Coups de cœur', sans: f.copierAvec(coupsDeCoeur: false)),
      if (f.laOuOnRevient)
        (libelle: 'Là où on revient', sans: f.copierAvec(laOuOnRevient: false)),
      if (f.mesEnvies)
        (libelle: 'Mes envies', sans: f.copierAvec(mesEnvies: false)),
    ];
  }

  // ---------------------------------------------------------------
  //  Affichage
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _mesurerEnTete());
    final nombre = _lieuxVisibles.length;
    // La Constellation, en plein écran : rien d'autre que le ciel. La
    // carte reste dessous, pour ne pas la recréer en revenant.
    final constellation = _mode == ModeExplorer.maCarte;
    final ecran = Scaffold(
      backgroundColor: _palette.fond,
      body: Stack(
        children: [
          Positioned.fill(child: _carte()),
          if (constellation)
            Positioned.fill(
              child: VueConstellation(
                lieux: _lieux,
                chargement: _chargement || !_chargeUneFois,
                anime: widget.afficherCarte,
                onQuitter: () => _choisirMode(ModeExplorer.cercle),
                onOuvrirLieu: _ouvrirFiche,
              ),
            ),
          if (_enGrille && !constellation) Positioned.fill(child: _grille()),
          if (!constellation)
            Positioned(left: 0, right: 0, top: 0, child: _enTete(nombre)),
          if (!_enGrille && !constellation) ..._surLaCarte(),
          // Cachée tant que l'aperçu d'un lieu est ouvert.
          if (_selection == null && !constellation)
            Positioned(
              left: 12,
              right: 12,
              bottom: _margeBarre + 12,
              child: TablBarreExplorer(
                onRechercher: _ouvrirRecherche,
                onFiltres: _ouvrirFiltres,
                filtresActifs: _filtres.nombreActifs,
                enGrille: _enGrille,
                onChoisirVue: (grille) {
                  setState(() {
                    _enGrille = grille;
                    _selection = null;
                  });
                  if (grille) _demanderPhotos();
                },
              ),
            ),
        ],
      ),
    );
    // L'heure et la batterie, lisibles sur le fond de l'écran.
    final barreEtat = AnnotatedRegion<SystemUiOverlayStyle>(
      value: _palette == PaletteExplorer.clair
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: ecran,
    );
    // La Constellation reste dans la nuit, quelle que soit l'apparence :
    // c'est un ciel d'étoiles.
    return TablNuitForcee(
      active: _mode == ModeExplorer.maCarte,
      child: barreEtat,
    );
  }

  PaletteExplorer get _palette => _mode == ModeExplorer.maCarte
      ? PaletteExplorer.sombre
      : PaletteExplorer.of(context);

  /// La hauteur de la barre flottante et de sa marge : ce qui doit rester
  /// visible se pose au-dessus.
  double get _margeBarreFlottante => _margeBarre + 12 + 60 + 12;

  Widget _enTete(int nombre) {
    final actifs = _filtresActifs;
    final palette = _palette;
    return DecoratedBox(
      key: _cleEnTete,
      decoration: BoxDecoration(
        gradient: _enGrille
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.6, 1],
                colors: [
                  palette.fond.withValues(alpha: 0.97),
                  palette.fond.withValues(alpha: 0.9),
                  palette.fond.withValues(alpha: 0),
                ],
              ),
        color: _enGrille ? palette.fond : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: _enGrille ? TablTokens.espaceXs : TablTokens.espaceL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceM,
                  TablTokens.espaceS,
                  TablTokens.espaceM,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.estOnglet) ...[
                      TablBoutonRetour(
                        onPresse: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                    ],
                    Expanded(
                      child: TablTitreExplorer(
                        titre: _titre,
                        sousTitre: _enErreur && !_chargeUneFois
                            ? 'Les adresses n\'ont pas pu être chargées'
                            : _chargeUneFois
                            ? _sousTitre(nombre)
                            : 'Chargement…',
                        onPresse: _ouvrirOuChercher,
                      ),
                    ),
                    const SizedBox(width: TablTokens.espaceS),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: TablBoutonConstellation(
                        actif: _mode == ModeExplorer.maCarte,
                        onPresse: () => _choisirMode(
                          _mode == ModeExplorer.maCarte
                              ? ModeExplorer.cercle
                              : ModeExplorer.maCarte,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (actifs.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: TablTokens.espaceM,
                    ),
                    itemCount: actifs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => TablPuceRetirable(
                      libelle: actifs[i].libelle,
                      onRetirer: () => _appliquerFiltres(actifs[i].sans),
                    ),
                  ),
                ),
              ],
              // Ma carte se lit par ville : pas de tri.
              if (_enGrille && _mode != ModeExplorer.maCarte)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TablTokens.espaceM + 2,
                    TablTokens.espaceS,
                    TablTokens.espaceM,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TablMenuTri(
                      options: [
                        for (final t in TriCercle.values)
                          (libelle: t.libelle, description: t.description),
                      ],
                      choisi: _tri.index,
                      onChoisir: (i) {
                        setState(() => _tri = TriCercle.values[i]);
                        _demanderPhotos();
                      },
                    ),
                  ),
                ),
              SizedBox(
                height: 2,
                child: _chargement
                    ? const LinearProgressIndicator(
                        color: TablTokens.primaire,
                        backgroundColor: Colors.transparent,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carte() {
    if (!widget.afficherCarte) {
      return const ColoredBox(color: TablTokens.surface);
    }
    final constellation = _mode == ModeExplorer.maCarte;
    return TablCarteMapbox(
      // Tous les lieux : la carte les regroupe elle-même selon le zoom.
      // « Ma carte » a sa propre façon de les montrer.
      geojsonLieux: constellation
          ? TablCarteMapbox.geojsonVide
          : geojsonLieux(_lieux, cleChoisie: _selection?.cle),
      // Belgique, avant de connaître la position.
      latitudeInitiale: 50.5,
      longitudeInitiale: 4.6,
      zoomInitial: 6.5,
      margeBas: _margeBarre,
      // La Constellation garde sa nuit (voir [_palette]).
      clair: _palette == PaletteExplorer.clair,
      controleur: _controleur,
      onTapLieu: _tapLieu,
      onZoneVisible: _zoneVisible,
      onTapCarte: _tapCarte,
    );
  }

  List<Widget> _surLaCarte() {
    final selection = _selection;
    return [
      if (selection == null && widget.positionService != null)
        Positioned(
          right: TablTokens.espaceM,
          bottom: _margeBarreFlottante,
          child: TablBoutonVerre(
            icone: Icons.near_me_rounded,
            libelle: 'Me recentrer',
            onPresse: () {
              final p = _position;
              if (p == null) {
                _localiser();
              } else {
                _controleur.centrerSur(p.latitude, p.longitude, zoom: 13.5);
              }
            },
          ),
        ),
      if (selection == null && _chargeUneFois && _lieux.isEmpty && !_enErreur)
        Positioned(
          left: TablTokens.espaceL,
          right: TablTokens.espaceL,
          bottom: _margeBarreFlottante + 8,
          child: _MessageCarte(texte: _rienDuTout),
        ),
      if (selection == null &&
          _chargeUneFois &&
          _mode != ModeExplorer.maCarte &&
          _lieuxVisibles.isEmpty &&
          _lieux.isNotEmpty)
        Positioned(
          left: TablTokens.espaceL,
          right: TablTokens.espaceL,
          bottom: _margeBarreFlottante + 8,
          child: _MessageCarte(
            texte: _compte(0),
            action: 'Voir mes villes',
            onAction: _ouvrirOuChercher,
          ),
        ),
      if (selection != null)
        Positioned(
          left: TablTokens.espaceS + 4,
          right: TablTokens.espaceS + 4,
          bottom: _margeBarre + TablTokens.espaceS,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (enfant, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(animation),
                child: enfant,
              ),
            ),
            child: _apercu(selection),
          ),
        ),
    ];
  }

  Widget _apercu(LieuCarte lieu) {
    final distance = _distance(lieu);
    final maintenant = DateTime.now();
    final detail = [
      cuisineEtQuartier(lieu),
      ?distanceSurTuile(distance),
    ].where((m) => m.isNotEmpty).join(' · ');
    final moi = lieu.mesVisites;
    final derniere = lieu.maDerniereVisite;
    return TablApercuLieu(
      key: ValueKey('apercu-${lieu.cle}'),
      nom: lieu.nom,
      detail: detail,
      photoUrl: _photo(lieu),
      visages: [
        for (final v in lieu.visages)
          BullePersonne(pseudo: v.pseudo, photoUrl: v.photoUrl),
      ],
      quiLaConnait: _mode == ModeExplorer.maCarte
          ? (moi <= 1
                ? 'Vous y êtes allé une fois'
                : 'Vous y êtes allé $moi fois')
          : lieu.amis > 0
          ? quiLaConnait(lieu)
          : lieu.estEnvie
          ? 'Dans vos envies'
          : 'Vous y êtes allé',
      signal: _mode == ModeExplorer.maCarte
          ? (derniere == null
                ? null
                : 'La dernière fois ${ilYA(derniere, maintenant)}')
          : signalLieu(lieu, maintenant),
      ressentis: _mode == ModeExplorer.maCarte ? const [] : lieu.ressentis,
      dejaAlle: moi == 0 || _mode == ModeExplorer.maCarte
          ? null
          : [
              moi == 1
                  ? 'Vous y êtes allé une fois'
                  : 'Vous y êtes allé $moi fois',
              if (derniere != null) 'la dernière ${ilYA(derniere, maintenant)}',
            ].join(', '),
      enregistre: lieu.estEnvie,
      onFermer: () => setState(() => _selection = null),
      onVoirFiche: () => _ouvrirFiche(lieu),
      onEnregistrer: () => _basculerEnvie(lieu),
      onProposer: widget.tableService != null && _tables.isNotEmpty
          ? () => _proposer(lieu)
          : null,
      onDemander: _mode != ModeExplorer.maCarte && _peutDemander(lieu)
          ? () => _demander(lieu)
          : null,
      onSuivant: () => _voisin(1),
      onPrecedent: () => _voisin(-1),
    );
  }

  /// Rien du tout dans ce mode (pas seulement ici).
  String get _rienDuTout => switch (_mode) {
    ModeExplorer.cercle =>
      _filtres.nombreActifs > 0
          ? 'Aucune adresse de vos proches ne correspond à ces filtres.'
          : 'Vos proches n\'ont encore partagé aucune adresse.',
    ModeExplorer.envies =>
      'Aucune envie pour l\'instant. Gardez une adresse pour la retrouver ici.',
    ModeExplorer.maCarte =>
      'Vos souvenirs apparaîtront ici, à leur place sur la carte.',
  };

  Widget _grille() {
    final lieux = _lieuxListe;
    final palette = _palette;
    final haut = _hauteurEnTete;
    if (lieux.isEmpty) {
      return ColoredBox(
        color: palette.fond,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            TablTokens.espaceXl,
            haut + TablTokens.espaceXl,
            TablTokens.espaceXl,
            0,
          ),
          child: Column(
            children: [
              Text(
                !_chargeUneFois
                    ? 'Chargement…'
                    : _lieux.isEmpty
                    ? _rienDuTout
                    : _compte(0),
                textAlign: TextAlign.center,
                style: TablTokens.titreAffichage.copyWith(
                  fontSize: 20,
                  height: 1.3,
                  color: palette.texte,
                ),
              ),
              if (_chargeUneFois && _lieux.isNotEmpty) ...[
                const SizedBox(height: TablTokens.espaceM),
                TablBoutonTexte(
                  libelle: 'Voir mes villes',
                  onPresse: _ouvrirOuChercher,
                ),
              ],
            ],
          ),
        ),
      );
    }
    // Deux par rangée, de la même hauteur.
    final rangees = [
      for (var i = 0; i < lieux.length; i += 2)
        lieux.sublist(i, i + 2 > lieux.length ? lieux.length : i + 2),
    ];
    return ColoredBox(
      color: palette.fond,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          12,
          haut + TablTokens.espaceXs,
          12,
          _margeBarreFlottante + TablTokens.espaceM,
        ),
        itemCount: rangees.length,
        itemBuilder: (_, i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _tuile(rangees[i][0])),
                const SizedBox(width: 10),
                Expanded(
                  child: rangees[i].length > 1
                      ? _tuile(rangees[i][1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tuile(LieuCarte lieu) {
    final autres = autresQueLesVisages(lieu);
    final distance = _distance(lieu);
    final note = noteSurCinq(lieu.ressentis);
    return TablTuileLieu(
      key: ValueKey('tuile-${lieu.cle}'),
      nom: lieu.nom,
      genre: switch (teinteLieu(lieu)) {
        TeinteLieu.cercle => GenreTuile.cercle,
        TeinteLieu.retour => GenreTuile.retour,
        TeinteLieu.vous => GenreTuile.vous,
      },
      visages: [
        for (final v in lieu.visages) (pseudo: v.pseudo, photoUrl: v.photoUrl),
      ],
      autres: autres?.texte,
      autresNombreux: autres?.nombreux ?? false,
      etVous: lieu.visiteParMoi && lieu.amis > 0,
      enGras: distanceSurTuile(distance),
      detail: cuisineOuLieu(lieu),
      note: note == null ? null : noteLisible(note),
      envie: lieu.estEnvie,
      onPresse: () => _ouvrirFiche(lieu),
      onVisages: () => _ouvrirFiche(lieu),
      onEnvie: () => _basculerEnvie(lieu),
    );
  }
}

/// Un message posé sur la carte, avec de quoi aller ailleurs.
class _MessageCarte extends StatelessWidget {
  const _MessageCarte({required this.texte, this.action, this.onAction});

  final String texte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      decoration: BoxDecoration(
        color: const Color(0xF20F1014),
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texte,
            textAlign: TextAlign.center,
            style: TablTokens.titreAffichage.copyWith(fontSize: 18),
          ),
          if (action != null)
            TablBoutonTexte(libelle: action!, onPresse: onAction)
          else
            const SizedBox(height: 10),
        ],
      ),
    );
  }
}
