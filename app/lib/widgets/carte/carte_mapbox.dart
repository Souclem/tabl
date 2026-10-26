import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/tokens.dart';

/// Permet au parent de déplacer la carte (recentrer sur ma position,
/// zoomer sur un lieu de la liste...) sans en connaître les détails.
class ControleurCarte {
  MapboxMap? _carte;

  /// Centrage demandé avant que la carte soit prête — la position arrive
  /// souvent avant elle, ou avant que son style soit chargé (un
  /// déplacement fait trop tôt est annulé par la mise en place de la vue
  /// initiale) : appliqué dès qu'elle l'est.
  CameraOptions? _enAttente;

  void _carteChargee(MapboxMap carte) {
    _carte = carte;
    final camera = _enAttente;
    _enAttente = null;
    if (camera != null) carte.setCamera(camera);
  }

  /// Déplace la carte (sans changer le zoom) pour amener ce point à
  /// [hauteur] (fraction depuis le haut de la carte, 0,5 = au centre).
  Future<void> amenerA(
    double latitude,
    double longitude, {
    required double hauteur,
  }) async {
    final carte = _carte;
    if (carte == null) return;
    final camera = await carte.getCameraState();
    final zone = await carte.coordinateBoundsForCamera(
      CameraOptions(center: camera.center, zoom: camera.zoom),
    );
    final hauteurZone =
        zone.northeast.coordinates.lat - zone.southwest.coordinates.lat;
    await carte.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(
            longitude,
            latitude - hauteurZone * (0.5 - hauteur),
          ),
        ),
      ),
      MapAnimationOptions(duration: 400),
    );
  }

  Future<void> centrerSur(
    double latitude,
    double longitude, {
    double zoom = 14,
  }) async {
    final carte = _carte;
    if (carte == null) {
      _enAttente = CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
      );
      return;
    }
    await carte.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 900),
    );
  }
}

/// Le style de carte propre à Tabl (« nuit dorée »), publié dans Mapbox
/// Studio. Sa source est versionnée dans `design/style_carte_tabl.json` :
/// une modification faite dans Studio doit y être recopiée.
const styleCarteTabl = 'mapbox://styles/clemlon/cmvfdwxja009q01pl6rox6613';

/// La carte Mapbox de Tabl : globe 3D au dézoom, notre style sans les
/// commerces de Mapbox (seuls nos lieux ressortent), ma position et une
/// boussole.
///
/// Les lieux proches à l'écran se regroupent en une bulle dorée qui dit
/// combien ils sont : « 42 » sur une ville vue de loin, puis « 3 », « 2 »,
/// « 5 » par quartier en zoomant ; un tap sur une bulle zoome juste
/// assez pour l'ouvrir. De près, chaque lieu est un marqueur doré avec,
/// dans une petite bulle, le nombre d'amis qui y sont allés (propriété
/// `amis` du GeoJSON, sans bulle quand elle est absente). Le regroupement
/// est celui de Mapbox : il suit la distance à l'écran, pas les
/// frontières, et vaut partout dans le monde. Un point marqué `repere`
/// (l'endroit d'une photo) est un simple rond blanc, qu'on ne touche pas.
///
/// Composant pur : reçoit les lieux déjà choisis (au format GeoJSON) et
/// renvoie le tap sur un lieu ([onTapLieu], avec sa clé) et la zone
/// visible après chaque déplacement ([onZoneVisible]).
class TablCarteMapbox extends StatefulWidget {
  const TablCarteMapbox({
    super.key,
    required this.geojsonLieux,
    required this.latitudeInitiale,
    required this.longitudeInitiale,
    required this.zoomInitial,
    required this.onTapLieu,
    required this.onZoneVisible,
    this.onTapCarte,
    this.controleur,
    this.margeBas = 0,
    this.avecMaPosition = true,
    this.dansUneFeuille = false,
  });

  final String geojsonLieux;
  final double latitudeInitiale;
  final double longitudeInitiale;
  final double zoomInitial;
  final ValueChanged<String> onTapLieu;

  /// (sud, ouest, nord, est, zoom).
  final void Function(
    double sud,
    double ouest,
    double nord,
    double est,
    double zoom,
  )
  onZoneVisible;

  final ControleurCarte? controleur;

  /// Tap sur la carte, hors des lieux (ferme ce qui est ouvert).
  final VoidCallback? onTapCarte;

  /// Hauteur occupée en bas par ce qui flotte au-dessus de la carte (la
  /// barre de navigation) : le logo et la mention « i » de Mapbox, qui
  /// doivent rester visibles, sont remontés d'autant.
  final double margeBas;

  /// Le point animé de ma position.
  final bool avecMaPosition;

  /// Posée dans une feuille qu'on peut faire glisser : la carte garde
  /// pour elle les gestes qui la touchent (sinon glisser vers le bas
  /// fermerait la feuille au lieu de déplacer la carte).
  final bool dansUneFeuille;

  @override
  State<TablCarteMapbox> createState() => _TablCarteMapboxState();
}

class _TablCarteMapboxState extends State<TablCarteMapbox> {
  static const _source = 'tabl-lieux';
  static const _coucheGroupes = 'tabl-groupes';
  static const _coucheNombres = 'tabl-groupes-nombres';
  static const _coucheLieux = 'tabl-lieux-points';
  static const _coucheBulles = 'tabl-lieux-bulles';
  static const _coucheAmis = 'tabl-lieux-amis';
  static const _coucheRepere = 'tabl-repere';

  /// Distance à l'écran (pt) sous laquelle des lieux se regroupent.
  static const _rayonGroupes = 46.0;

  /// Au-delà de ce zoom (quelques rues), plus aucun regroupement : chaque
  /// restaurant a son marqueur.
  static const _zoomMaxGroupes = 14.0;

  /// Les polices du style de Tabl (les seules que Mapbox lui sert).
  static const _police = ['DIN Pro Medium', 'Arial Unicode MS Regular'];

  /// La petite bulle des amis : en haut à droite du marqueur.
  static const _decalageBulle = [9.0, -9.0];

  static const List<Object> _estUnGroupe = ['has', 'point_count'];
  static const List<Object> _estUnLieu = [
    'all',
    [
      '!',
      ['has', 'point_count'],
    ],
    [
      '!',
      ['has', 'repere'],
    ],
  ];
  static const List<Object> _aDesAmis = [
    'all',
    _estUnLieu,
    ['has', 'amis'],
  ];
  static const List<Object> _estUnRepere = ['has', 'repere'];

  /// Le lieu dont la feuille est ouverte ressort.
  static const List<Object> _echelleExpression = [
    'case',
    [
      'to-boolean',
      ['get', 'choisi'],
    ],
    1.35,
    1.0,
  ];

  MapboxMap? _carte;
  bool _styleCharge = false;
  Timer? _attenteCamera;

  /// Position de départ, créée une seule fois : un nouvel objet à chaque
  /// reconstruction pourrait ramener la carte à son point de départ et
  /// annuler un zoom ou un recentrage.
  late final _vueInitiale = CameraViewportState(
    center: Point(
      coordinates: Position(widget.longitudeInitiale, widget.latitudeInitiale),
    ),
    zoom: widget.zoomInitial,
  );

  @override
  void dispose() {
    _attenteCamera?.cancel();
    super.dispose();
  }

  /// La zone visible est signalée après chaque mouvement de caméra, une
  /// fois la carte immobile depuis un court instant. Pas l'événement
  /// "idle" de Mapbox : le halo animé de ma position fait redessiner la
  /// carte en continu, elle n'est alors jamais considérée comme au repos.
  void _cameraBouge() {
    _attenteCamera?.cancel();
    _attenteCamera = Timer(const Duration(milliseconds: 300), _signalerZone);
  }

  Future<void> _creee(MapboxMap carte) async {
    _carte = carte;

    await carte.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    // Boussole toujours visible, sous le bouton "ma position" : un tap
    // remet le nord en haut.
    await carte.compass.updateSettings(
      CompassSettings(
        enabled: true,
        position: OrnamentPosition.TOP_RIGHT,
        marginTop: 70,
        marginRight: 18,
        fadeWhenFacingNorth: false,
      ),
    );
    await carte.location.updateSettings(
      LocationComponentSettings(
        enabled: widget.avecMaPosition,
        pulsingEnabled: true,
        pulsingColor: TablTokens.primaire.toARGB32(),
        showAccuracyRing: false,
      ),
    );
    await carte.logo.updateSettings(
      LogoSettings(marginBottom: widget.margeBas + 8),
    );
    await carte.attribution.updateSettings(
      AttributionSettings(marginBottom: widget.margeBas + 8),
    );
  }

  Future<void> _styleChargeListener(StyleLoadedEventData _) async {
    final carte = _carte;
    if (carte == null) return;
    await carte.addSource(
      GeoJsonSource(
        id: _source,
        cluster: true,
        clusterRadius: _rayonGroupes,
        clusterMaxZoom: _zoomMaxGroupes,
      ),
    );

    // Les groupes : une bulle dorée, plus grande quand ils sont nombreux,
    // et leur nombre au centre.
    await carte.addLayer(
      CircleLayer(
        id: _coucheGroupes,
        sourceId: _source,
        filter: _estUnGroupe,
        circleColor: TablTokens.primaire.toARGB32(),
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          15.0,
          10,
          19.0,
          50,
          24.0,
          200,
          30.0,
        ],
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 2.5,
      ),
    );
    await carte.addLayer(
      SymbolLayer(
        id: _coucheNombres,
        sourceId: _source,
        filter: _estUnGroupe,
        textFieldExpression: ['get', 'point_count_abbreviated'],
        textFont: _police,
        textSizeExpression: [
          'step',
          ['get', 'point_count'],
          13.0,
          50,
          15.0,
          200,
          17.0,
        ],
        textColor: TablTokens.texteSurPrimaire.toARGB32(),
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );

    // L'endroit d'une photo : un rond blanc cerclé d'or, sous les lieux.
    await carte.addLayer(
      CircleLayer(
        id: _coucheRepere,
        sourceId: _source,
        filter: _estUnRepere,
        circleColor: TablTokens.texte.toARGB32(),
        circleRadius: 7.0,
        circleStrokeColor: TablTokens.primaire.toARGB32(),
        circleStrokeWidth: 3.0,
      ),
    );

    // Un lieu seul : marqueur doré, et la petite bulle de ses amis.
    await carte.addLayer(
      CircleLayer(
        id: _coucheLieux,
        sourceId: _source,
        filter: _estUnLieu,
        circleColor: TablTokens.primaire.toARGB32(),
        circleRadiusExpression: ['*', 8.0, _echelleExpression],
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 2.0,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheBulles,
        sourceId: _source,
        filter: _aDesAmis,
        circleColor: TablTokens.fond.toARGB32(),
        circleRadius: 8.0,
        circleStrokeColor: TablTokens.primaire.toARGB32(),
        circleStrokeWidth: 1.5,
        circleTranslate: _decalageBulle,
      ),
    );
    await carte.addLayer(
      SymbolLayer(
        id: _coucheAmis,
        sourceId: _source,
        filter: _aDesAmis,
        textFieldExpression: [
          'case',
          [
            '>',
            ['get', 'amis'],
            99,
          ],
          '99+',
          [
            'to-string',
            ['get', 'amis'],
          ],
        ],
        textFont: _police,
        textSize: 10.0,
        textColor: TablTokens.texte.toARGB32(),
        textTranslate: _decalageBulle,
        textAllowOverlap: true,
        textIgnorePlacement: true,
      ),
    );

    carte.addInteraction(
      TapInteraction.onMap((_) => widget.onTapCarte?.call()),
    );
    for (final couche in [_coucheLieux, _coucheBulles, _coucheAmis]) {
      carte.addInteraction(
        TapInteraction(FeaturesetDescriptor(layerId: couche), (lieu, _) {
          final cle = lieu.properties['cle'];
          if (cle is String) widget.onTapLieu(cle);
        }),
      );
    }
    for (final couche in [_coucheGroupes, _coucheNombres]) {
      carte.addInteraction(
        TapInteraction(
          FeaturesetDescriptor(layerId: couche),
          (groupe, _) => _ouvrirGroupe(groupe),
        ),
      );
    }

    _styleCharge = true;
    widget.controleur?._carteChargee(carte);
    _mettreAJour(widget.geojsonLieux);
    _signalerZone();
  }

  /// Zoome sur le groupe touché, juste assez pour qu'il s'ouvre (le zoom
  /// que Mapbox indique ; deux crans de plus s'il ne le dit pas).
  Future<void> _ouvrirGroupe(FeaturesetFeature groupe) async {
    final carte = _carte;
    final coordonnees = groupe.geometry['coordinates'];
    if (carte == null || coordonnees is! List || coordonnees.length < 2) {
      return;
    }
    final camera = await carte.getCameraState();
    var zoom = camera.zoom + 2;
    try {
      final ouverture = await carte.getGeoJsonClusterExpansionZoom(_source, {
        'type': 'Feature',
        'geometry': groupe.geometry,
        'properties': groupe.properties,
      });
      zoom = double.tryParse(ouverture.value ?? '') ?? zoom;
    } catch (e) {
      debugPrint('TablCarteMapbox: ouverture du groupe : $e');
    }
    await carte.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(coordonnees[0] as num, coordonnees[1] as num),
        ),
        zoom: zoom,
      ),
      MapAnimationOptions(duration: 450),
    );
  }

  Future<void> _signalerZone() async {
    final carte = _carte;
    if (carte == null) return;
    final camera = await carte.getCameraState();
    final zone = await carte.coordinateBoundsForCamera(
      CameraOptions(
        center: camera.center,
        zoom: camera.zoom,
        bearing: camera.bearing,
        pitch: camera.pitch,
      ),
    );
    widget.onZoneVisible(
      zone.southwest.coordinates.lat.toDouble(),
      zone.southwest.coordinates.lng.toDouble(),
      zone.northeast.coordinates.lat.toDouble(),
      zone.northeast.coordinates.lng.toDouble(),
      camera.zoom,
    );
  }

  @override
  void didUpdateWidget(TablCarteMapbox ancien) {
    super.didUpdateWidget(ancien);
    if (!_styleCharge) return;
    if (ancien.geojsonLieux != widget.geojsonLieux) {
      _mettreAJour(widget.geojsonLieux);
    }
  }

  /// Mapbox refait les groupes lui-même à chaque nouvelle donnée.
  Future<void> _mettreAJour(String geojson) async {
    final source = await _carte?.getSource(_source);
    if (source is GeoJsonSource) await source.updateGeoJSON(geojson);
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('tabl-carte'),
      styleUri: styleCarteTabl,
      viewport: _vueInitiale,
      onMapCreated: _creee,
      onStyleLoadedListener: _styleChargeListener,
      onCameraChangeListener: (_) => _cameraBouge(),
      gestureRecognizers: widget.dansUneFeuille
          ? {Factory<EagerGestureRecognizer>(EagerGestureRecognizer.new)}
          : null,
    );
  }
}
