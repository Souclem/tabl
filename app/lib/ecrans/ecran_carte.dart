import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Onglet Carte : les lieux de mon réseau (marqueurs dorés, regroupés
/// selon le zoom) et, de près, tous les autres restaurants de l'annuaire
/// (points discrets). Un tap ouvre un aperçu ; la fiche complète du
/// restaurant viendra ensuite.
class EcranCarte extends StatefulWidget {
  const EcranCarte({
    super.key,
    required this.carteService,
    this.positionService,
    this.afficherCarte = true,
  });

  final CarteService carteService;

  /// `null` : la carte démarre sur la Belgique, sans bouton "ma position".
  final PositionService? positionService;

  /// `false` dans les tests : la carte Mapbox est une vue native,
  /// indisponible hors d'un vrai appareil — le reste de l'écran reste
  /// testable.
  final bool afficherCarte;

  @override
  State<EcranCarte> createState() => _EcranCarteState();
}

class _EcranCarteState extends State<EcranCarte> {
  final _controleur = ControleurCarte();

  List<LieuCarte> _lieuxTabl = const [];
  List<LieuCarte> _annuaire = const [];
  LieuCarte? _selection;
  bool _envieEnCours = false;
  Coordonnees? _position;
  Timer? _attenteZone;

  @override
  void initState() {
    super.initState();
    _chargerLieuxTabl();
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
    if (zoom < TablCarteMapbox.zoomAnnuaire) {
      if (_annuaire.isNotEmpty) setState(() => _annuaire = const []);
      return;
    }
    // On attend que la carte s'immobilise avant de charger le quartier.
    _attenteZone = Timer(const Duration(milliseconds: 300), () async {
      try {
        final lieux = await widget.carteService.lieuxAnnuaire(
          ZoneCarte(sud: sud, ouest: ouest, nord: nord, est: est),
        );
        if (!mounted) return;
        setState(() => _annuaire = lieux);
      } catch (e) {
        debugPrint('EcranCarte: annuaire : $e');
      }
    });
  }

  /// L'annuaire sans les lieux déjà affichés en doré.
  Iterable<LieuCarte> get _annuaireSeul {
    final dejaDansTabl = {
      for (final l in _lieuxTabl)
        if (l.fsqPlaceId != null) l.fsqPlaceId,
    };
    return _annuaire.where((l) => !dejaDansTabl.contains(l.fsqPlaceId));
  }

  void _tapLieu(String cle) {
    final lieu = [
      ..._lieuxTabl,
      ..._annuaire,
    ].where((l) => l.cle == cle).firstOrNull;
    if (lieu != null) setState(() => _selection = lieu);
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

  @override
  Widget build(BuildContext context) {
    final selection = _selection;
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: Stack(
        children: [
          Positioned.fill(
            child: widget.afficherCarte
                ? TablCarteMapbox(
                    geojsonReseau: geojsonLieux(_lieuxTabl),
                    geojsonAnnuaire: geojsonLieux(_annuaireSeul),
                    // Belgique, avant de connaître la position.
                    latitudeInitiale: 50.5,
                    longitudeInitiale: 4.6,
                    zoomInitial: 6.5,
                    controleur: _controleur,
                    onTapLieu: _tapLieu,
                    onZoneVisible: _zoneVisible,
                  )
                : const ColoredBox(color: TablTokens.surface),
          ),
          if (_position != null)
            Positioned(
              right: TablTokens.espaceM,
              top: MediaQuery.paddingOf(context).top + TablTokens.espaceM,
              child: _BoutonRond(
                icone: Icons.my_location_rounded,
                libelle: 'Ma position',
                onPresse: () => _controleur.centrerSur(
                  _position!.latitude,
                  _position!.longitude,
                ),
              ),
            ),
          if (selection != null)
            Positioned(
              left: TablTokens.espaceM,
              right: TablTokens.espaceM,
              // Au-dessus de la barre de navigation flottante.
              bottom: TablTokens.espaceXxl + TablTokens.espaceL,
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
