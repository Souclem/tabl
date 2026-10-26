import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_filtres_explorer.dart';
import 'feuille_restaurant.dart';

/// L'onglet Explorer, d'après le prototype : « où manger, d'après les
/// gens en qui j'ai confiance ? ».
///
/// La carte prend tout l'écran ; en haut, posé dessus avec un fondu :
/// la ville qu'on regarde (un tap pour en changer), Carte | Liste, les
/// trois modes (Ma carte · Envies · Le cercle) et les filtres. Un tap
/// sur un lieu ouvre son aperçu en bas, qu'on balaie pour passer au
/// voisin. La liste montre les mêmes lieux — ceux de la zone regardée —
/// triés au choix, le premier en grand.
///
/// S'ouvre sur « Le cercle », puis sur le dernier mode utilisé
/// (décision du 2026-10-27).
class EcranCarte extends StatefulWidget {
  const EcranCarte({
    super.key,
    required this.carteService,
    this.positionService,
    this.tableService,
    this.abonnementService,
    this.souvenirService,
    this.filtresInitiaux = FiltresCarte.aucun,
    this.estOnglet = true,
    this.afficherCarte = true,
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

  /// Filtres appliqués à l'ouverture ("Voir sur la carte" depuis une
  /// Table ouvre la carte déjà filtrée sur cette Table).
  final FiltresCarte filtresInitiaux;

  /// `false` quand l'Explorer est ouvert par-dessus un autre écran :
  /// bouton retour, et pas de barre de navigation à éviter en bas.
  final bool estOnglet;

  /// `false` dans les tests : la carte Mapbox est une vue native,
  /// indisponible hors d'un vrai appareil — le reste de l'écran reste
  /// testable.
  final bool afficherCarte;

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

  ModeExplorer _mode = ModeExplorer.cercle;
  bool _enListe = false;
  late FiltresCarte _filtres = widget.filtresInitiaux;
  TriCercle _tri = TriCercle.recents;
  final _recherche = TextEditingController();

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
    _recherche.dispose();
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
        final mode = ModeExplorer.values
            .where((m) => m.name == valeur)
            .firstOrNull;
        if (mode != null && mounted) setState(() => _mode = mode);
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
      if (_enListe) ..._lieuxListe.take(24),
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

  /// Sous le titre : ce qu'on trouve dans la zone regardée — ou, pour ma
  /// Constellation vue de loin, ce qu'elle raconte.
  String _sousTitre(int nombre) {
    if (_mode == ModeExplorer.maCarte) {
      final ville = _villeRegardee;
      if (ville == null) return 'Votre histoire, table par table.';
      final ici = lieuxDeLaVille(_lieux, ville.nom);
      return tablesEtRepas(
        ici.length,
        ici.fold(0, (n, l) => n + math.max(l.mesVisites, 1)),
      );
    }
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

  /// La liste : les lieux de la zone regardée — ou, pendant une
  /// recherche, tous ceux du mode dont le nom correspond ; pour « Ma
  /// carte », tous —, dans l'ordre du tri.
  List<LieuCarte> get _lieuxListe {
    final texte = normaliserPourRecherche(_recherche.text.trim());
    // « Ma carte » en liste raconte toute mon histoire, ville par ville.
    final base = texte.isEmpty
        ? (_mode == ModeExplorer.maCarte ? _lieux : _lieuxVisibles)
        : [
            for (final l in _lieux)
              if (normaliserPourRecherche(l.nom).contains(texte)) l,
          ];
    return trierLieux(base, _tri, position: _position);
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
    if (choix is VilleCercle) {
      // Sans carte (liste, tests), la zone se règle d'elle-même.
      if (!widget.afficherCarte) {
        setState(() {
          _zone = choix.zone;
          _zoom = 12;
        });
      }
      await _controleur.cadrer(
        sud: choix.zone.sud,
        ouest: choix.zone.ouest,
        nord: choix.zone.nord,
        est: choix.zone.est,
        haut: _hauteurEnTete,
        bas: _margeBarre,
      );
    }
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
    // Une ville de ma Constellation : on s'en approche.
    if (cle.startsWith('ville:')) {
      final nom = cle.substring('ville:'.length);
      final ville = villesConstellation(
        _lieux,
      ).where((v) => v.nom == nom).firstOrNull;
      if (ville != null) {
        _controleur.cadrer(
          sud: ville.zone.sud,
          ouest: ville.zone.ouest,
          nord: ville.zone.nord,
          est: ville.zone.est,
          haut: _hauteurEnTete,
          bas: _margeBarre,
          zoomMax: 14.5,
        );
      }
      return;
    }
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

  /// Les actions d'un lieu de la liste.
  Future<void> _options(LieuCarte lieu) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF111216),
      showDragHandle: true,
      builder: (contexte) {
        Widget action(String valeur, IconData icone, String libelle) =>
            ListTile(
              leading: Icon(icone, color: TablTokens.texte),
              title: Text(libelle, style: TablTokens.corps),
              onTap: () => Navigator.of(contexte).pop(valeur),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
                  0,
                  TablTokens.espaceL - 4,
                  TablTokens.espaceS,
                ),
                child: Row(
                  children: [
                    TablPhotoLieu(nom: lieu.nom, url: _photo(lieu), taille: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lieu.nom,
                            style: TablTokens.titreAffichage.copyWith(
                              fontSize: 20,
                            ),
                          ),
                          Text(
                            cuisineEtQuartier(lieu),
                            style: TablTokens.legende,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.souvenirService != null)
                action('fiche', Icons.article_outlined, 'Voir la fiche'),
              if (widget.tableService != null && _tables.isNotEmpty)
                action(
                  'proposer',
                  Icons.person_add_alt_1_outlined,
                  'Proposer à une Table',
                ),
              action(
                'envie',
                lieu.estEnvie
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                lieu.estEnvie ? 'Retirer de mes envies' : 'Enregistrer',
              ),
              if (widget.afficherCarte)
                action('carte', Icons.map_outlined, 'Voir sur la carte'),
            ],
          ),
        );
      },
    );
    if (!mounted || choix == null) return;
    switch (choix) {
      case 'fiche':
        _ouvrirFiche(lieu);
      case 'proposer':
        _proposer(lieu);
      case 'envie':
        _basculerEnvie(lieu);
      case 'carte':
        _montrerSurLaCarte(lieu);
    }
  }

  /// Sur la carte, de près, l'aperçu du lieu ouvert.
  Future<void> _montrerSurLaCarte(LieuCarte lieu) async {
    setState(() => _enListe = false);
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
    );
    if (choisis != null && mounted) _appliquerFiltres(choisis);
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
    final nombre = _enListe && _recherche.text.trim().isNotEmpty
        ? _lieuxListe.length
        : _lieuxVisibles.length;
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: Stack(
        children: [
          Positioned.fill(child: _carte()),
          if (_enListe) Positioned.fill(child: _liste()),
          Positioned(left: 0, right: 0, top: 0, child: _enTete(nombre)),
          if (!_enListe) ..._surLaCarte(),
        ],
      ),
    );
  }

  Widget _enTete(int nombre) {
    final actifs = _filtresActifs;
    return DecoratedBox(
      key: _cleEnTete,
      decoration: BoxDecoration(
        gradient: _enListe
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.72, 1],
                colors: [
                  TablTokens.fond.withValues(alpha: 0.97),
                  TablTokens.fond.withValues(alpha: 0.82),
                  TablTokens.fond.withValues(alpha: 0),
                ],
              ),
        color: _enListe ? TablTokens.fond : null,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: _enListe ? TablTokens.espaceS : TablTokens.espaceL,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
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
                      padding: const EdgeInsets.only(top: 4),
                      child: TablSegmentModeCarte(
                        options: const ['Carte', 'Liste'],
                        selectionne: _enListe ? 1 : 0,
                        onSelection: (i) {
                          setState(() {
                            _enListe = i == 1;
                            _selection = null;
                          });
                          if (_enListe) _demanderPhotos();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TablTokens.espaceM - 2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL - 4,
                ),
                child: Row(
                  children: [
                    TablSegmentModeCarte(
                      options: [for (final m in ModeExplorer.values) m.libelle],
                      selectionne: _mode.index,
                      onSelection: (i) => _choisirMode(ModeExplorer.values[i]),
                    ),
                    const Spacer(),
                    TablBoutonFiltres(
                      actifs: _filtres.nombreActifs,
                      onPresse: _ouvrirFiltres,
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
                      horizontal: TablTokens.espaceL - 4,
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
              if (_enListe) ...[
                const SizedBox(height: TablTokens.espaceM),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TablTokens.espaceL - 4,
                  ),
                  child: TablChampTexte(
                    libelle: '',
                    controleur: _recherche,
                    indication: 'Chercher dans ces adresses',
                    iconePrefixe: Icons.search_rounded,
                    onChanged: (_) {
                      setState(() {});
                      _demanderPhotos();
                    },
                  ),
                ),
                // Ma carte se lit par ville : pas de tri.
                if (_mode != ModeExplorer.maCarte) ...[
                  const SizedBox(height: TablTokens.espaceS),
                  TablOngletsDefilants(
                    libelles: [for (final t in TriCercle.values) t.libelle],
                    index: _tri.index,
                    onChoisir: (i) {
                      setState(() => _tri = TriCercle.values[i]);
                      _demanderPhotos();
                    },
                  ),
                ],
              ],
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
      geojsonConstellation: constellation
          ? geojsonConstellation(_lieux, cleChoisie: _selection?.cle)
          : TablCarteMapbox.geojsonVide,
      // Belgique, avant de connaître la position.
      latitudeInitiale: 50.5,
      longitudeInitiale: 4.6,
      zoomInitial: 6.5,
      margeBas: _margeBarre,
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
          bottom: _margeBarre + TablTokens.espaceM,
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
      if (selection == null &&
          _mode == ModeExplorer.maCarte &&
          _lieux.isNotEmpty)
        Positioned(
          left: TablTokens.espaceL - 4,
          // Au-dessus du logo de Mapbox.
          bottom: _margeBarre + 44,
          child: Builder(
            builder: (_) {
              final c = compteursConstellation(_lieux);
              return TablCompteursConstellation(
                chiffres: [
                  (nombre: '${c.repas}', libelle: 'repas'),
                  (
                    nombre: '${c.villes}',
                    libelle: c.villes == 1 ? 'ville' : 'villes',
                  ),
                ],
              );
            },
          ),
        ),
      if (selection == null && _chargeUneFois && _lieux.isEmpty && !_enErreur)
        Positioned(
          left: TablTokens.espaceL,
          right: TablTokens.espaceL,
          bottom: _margeBarre + 76,
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
          bottom: _margeBarre + 76,
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
      if (distance != null) distanceLisible(distance),
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

  /// « Ma carte » en liste : mes adresses par ville, la plus fréquentée
  /// d'abord.
  Widget _listeParVille(List<LieuCarte> lieux, double haut) {
    final villes = villesConstellation(lieux)
      ..sort((a, b) => b.repas.compareTo(a.repas));
    final sansVille = [
      for (final l in lieux)
        if (l.ville.trim().isEmpty) l,
    ];
    Widget ligne(LieuCarte l) => TablLigneCercle(
      key: ValueKey('ligne-${l.cle}'),
      nom: l.nom,
      photoUrl: _photo(l),
      raison: repasEtDerniere(l),
      detail: cuisineEtQuartier(l),
      onPresse: () => _ouvrirFiche(l),
      onOptions: () => _options(l),
    );
    return ColoredBox(
      color: TablTokens.fond,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          TablTokens.espaceL - 4,
          haut + TablTokens.espaceS,
          TablTokens.espaceL - 4,
          _margeBarre + TablTokens.espaceL,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          for (final v in villes) ...[
            Padding(
              padding: const EdgeInsets.only(top: TablTokens.espaceM),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    v.nom,
                    style: TablTokens.titreAffichage.copyWith(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tablesEtRepas(v.tables, v.repas),
                    style: TablTokens.legende.copyWith(fontSize: 12.5),
                  ),
                ],
              ),
            ),
            for (final l in lieuxDeLaVille(lieux, v.nom)) ligne(l),
          ],
          for (final l in sansVille) ligne(l),
        ],
      ),
    );
  }

  Widget _liste() {
    final lieux = _lieuxListe;
    final maintenant = DateTime.now();
    final texte = _recherche.text.trim();
    final haut = _hauteurEnTete;
    if (lieux.isEmpty) {
      return ColoredBox(
        color: TablTokens.fond,
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
                    : texte.isNotEmpty
                    ? 'Aucune adresse ne correspond à « $texte ».'
                    : _lieux.isEmpty
                    ? _rienDuTout
                    : _compte(0),
                textAlign: TextAlign.center,
                style: TablTokens.titreAffichage.copyWith(
                  fontSize: 20,
                  height: 1.3,
                ),
              ),
              if (_chargeUneFois && texte.isEmpty && _lieux.isNotEmpty) ...[
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
    if (_mode == ModeExplorer.maCarte) return _listeParVille(lieux, haut);
    final vedette = lieux.first;
    final suite = lieux.skip(1).toList();
    String? raison(LieuCarte l) =>
        ligneSelonTri(
          l,
          _tri,
          maintenant: maintenant,
          distanceM: _distance(l),
        ) ??
        signalLieu(l, maintenant);
    String qui(LieuCarte l) => l.amis > 0
        ? quiLaConnait(l)
        : l.estEnvie
        ? 'Dans vos envies'
        : 'Vous y êtes allé';
    return ColoredBox(
      color: TablTokens.fond,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          TablTokens.espaceL - 4,
          haut + TablTokens.espaceS,
          TablTokens.espaceL - 4,
          _margeBarre + TablTokens.espaceL,
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TablCarteVedette(
            key: ValueKey('vedette-${vedette.cle}'),
            nom: vedette.nom,
            photoUrl: _photo(vedette),
            quiLaConnait: qui(vedette),
            raison: raison(vedette),
            enregistre: vedette.estEnvie,
            onPresse: () => _ouvrirFiche(vedette),
            onEnregistrer: () => _basculerEnvie(vedette),
            onOptions: () => _options(vedette),
          ),
          if (suite.isNotEmpty) ...[
            const SizedBox(height: TablTokens.espaceL),
            Text(
              'La suite',
              style: TablTokens.titreAffichage.copyWith(fontSize: 22),
            ),
            const SizedBox(height: TablTokens.espaceXs),
            for (final l in suite)
              TablLigneCercle(
                key: ValueKey('ligne-${l.cle}'),
                nom: l.nom,
                photoUrl: _photo(l),
                raison: [qui(l), ?raison(l)].join(' · '),
                detail: cuisineEtQuartier(l),
                onPresse: () => _ouvrirFiche(l),
                onOptions: () => _options(l),
              ),
          ],
        ],
      ),
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
