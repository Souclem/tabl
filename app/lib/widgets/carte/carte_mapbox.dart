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

  /// Cadre la carte sur une zone (une ville), avec un peu d'air autour
  /// et de la place pour ce qui flotte en haut ([haut]) et en bas
  /// ([bas]). Jamais plus près que [zoomMax] : une ville d'une seule
  /// adresse ne se voit pas à l'échelle d'une rue.
  Future<void> cadrer({
    required double sud,
    required double ouest,
    required double nord,
    required double est,
    double haut = 0,
    double bas = 0,
    double zoomMax = 14,
  }) async {
    final carte = _carte;
    final bornes = CoordinateBounds(
      southwest: Point(coordinates: Position(ouest, sud)),
      northeast: Point(coordinates: Position(est, nord)),
      infiniteBounds: false,
    );
    if (carte == null) {
      _enAttente = CameraOptions(
        center: Point(
          coordinates: Position((ouest + est) / 2, (sud + nord) / 2),
        ),
        zoom: 12,
      );
      return;
    }
    final camera = await carte.cameraForCoordinateBounds(
      bornes,
      MbxEdgeInsets(top: haut + 40, left: 40, bottom: bas + 40, right: 40),
      0,
      0,
      zoomMax,
      null,
    );
    await carte.flyTo(camera, MapAnimationOptions(duration: 900));
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
/// Les lieux proches à l'écran se regroupent en une bulle sombre qui dit
/// combien ils sont : « 42 » sur une ville vue de loin, puis « 3 », « 2 »,
/// « 5 » par quartier en zoomant ; un tap sur une bulle zoome juste
/// assez pour l'ouvrir. De près, chaque lieu est un point clair ; une
/// petite étincelle dorée le signale quand mon cercle y revient
/// (propriété `revient` du GeoJSON), et le lieu choisi grossit, cerclé
/// d'or (`choisi`). Le regroupement est celui de Mapbox : il suit la
/// distance à l'écran, pas les frontières, et vaut partout dans le
/// monde. Un point marqué `repere` (l'endroit d'une photo) est un rond
/// blanc cerclé d'or, qu'on ne touche pas.
///
/// [geojsonConstellation] dessine ma Constellation (« Ma carte ») : de
/// loin, mes villes en points lumineux reliés par un fil doré dans
/// l'ordre où je les ai découvertes, avec leur nom ; de près, chaque
/// restaurant en étoile, d'autant plus grande que j'y suis allé souvent.
/// Un tap sur une ville renvoie sa clé (`ville:Liège`).
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
    this.geojsonConstellation = geojsonVide,
  });

  /// Aucun point.
  static const geojsonVide = '{"type":"FeatureCollection","features":[]}';

  final String geojsonConstellation;

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
  static const _coucheToucher = 'tabl-lieux-toucher';
  static const _coucheHalo = 'tabl-lieux-halo';
  static const _coucheEtincelles = 'tabl-lieux-etincelles';
  static const _coucheRepere = 'tabl-repere';
  static const _sourceConstellation = 'tabl-constellation';
  static const _coucheSillage = 'tabl-sillage';
  static const _coucheVillesHalo = 'tabl-villes-halo';
  static const _coucheVilles = 'tabl-villes';
  static const _coucheVillesNoms = 'tabl-villes-noms';
  static const _coucheVillesToucher = 'tabl-villes-toucher';
  static const _coucheEtoilesHalo = 'tabl-etoiles-halo';
  static const _coucheEtoiles = 'tabl-etoiles';
  static const _coucheEtoilesToucher = 'tabl-etoiles-toucher';

  /// De loin les villes, de près les étoiles : elles se relaient autour
  /// de ce zoom.
  static const _zoomEtoiles = 9.0;

  /// Distance à l'écran (pt) sous laquelle des lieux se regroupent.
  static const _rayonGroupes = 46.0;

  /// Au-delà de ce zoom (quelques rues), plus aucun regroupement : chaque
  /// restaurant a son point.
  static const _zoomMaxGroupes = 14.0;

  /// Les polices du style de Tabl (les seules que Mapbox lui sert).
  static const _police = ['DIN Pro Medium', 'Arial Unicode MS Regular'];

  /// L'étincelle du cercle qui revient : en haut à droite du point.
  static const _decalageEtincelle = [6.5, -6.5];

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
  static const List<Object> _estChoisi = [
    'all',
    _estUnLieu,
    ['has', 'choisi'],
  ];
  static const List<Object> _revient = [
    'all',
    _estUnLieu,
    ['has', 'revient'],
  ];
  static const List<Object> _estUnRepere = ['has', 'repere'];

  static const List<Object> _choisiExpression = [
    'to-boolean',
    ['get', 'choisi'],
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
    // Toujours le nord en haut, à plat : on se repère d'un coup d'œil,
    // et la boussole devient inutile.
    await carte.gestures.updateSettings(
      GesturesSettings(rotateEnabled: false, pitchEnabled: false),
    );
    await carte.compass.updateSettings(CompassSettings(enabled: false));
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
    // Le « i » de Mapbox à côté de son logo, en bas à gauche : le coin
    // droit reste aux boutons de l'écran.
    await carte.attribution.updateSettings(
      AttributionSettings(
        position: OrnamentPosition.BOTTOM_LEFT,
        marginLeft: 96,
        marginBottom: widget.margeBas + 8,
      ),
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

    // Les groupes : une bulle sombre, plus grande quand ils sont
    // nombreux, et leur nombre au centre.
    await carte.addLayer(
      CircleLayer(
        id: _coucheGroupes,
        sourceId: _source,
        filter: _estUnGroupe,
        circleColor: const Color(0xF21A1C21).toARGB32(),
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          14.0,
          10,
          17.0,
          50,
          21.0,
          200,
          26.0,
        ],
        circleStrokeColor: const Color(0x52F5F0E8).toARGB32(),
        circleStrokeWidth: 1.2,
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
          12.5,
          50,
          14.0,
          200,
          16.0,
        ],
        textColor: TablTokens.texte.toARGB32(),
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

    // Le lieu choisi : un halo doré derrière son point.
    await carte.addLayer(
      CircleLayer(
        id: _coucheHalo,
        sourceId: _source,
        filter: _estChoisi,
        circleColor: TablTokens.primaire.withValues(alpha: 0.28).toARGB32(),
        circleRadius: 17.0,
        circleBlur: 0.6,
      ),
    );

    // Un lieu seul : un point clair, plus gros et cerclé d'or s'il est
    // choisi.
    await carte.addLayer(
      CircleLayer(
        id: _coucheLieux,
        sourceId: _source,
        filter: _estUnLieu,
        circleColor: TablTokens.texte.toARGB32(),
        circleRadiusExpression: ['case', _choisiExpression, 7.5, 5.0],
        circleStrokeColorExpression: [
          'case',
          _choisiExpression,
          TablTokens.primaire.toARGB32(),
          const Color(0xE6101114).toARGB32(),
        ],
        circleStrokeWidthExpression: ['case', _choisiExpression, 3.0, 1.6],
      ),
    );

    // Mon cercle y revient : une étincelle dorée au coin du point.
    await carte.addLayer(
      CircleLayer(
        id: _coucheEtincelles,
        sourceId: _source,
        filter: _revient,
        circleColor: TablTokens.primaire.toARGB32(),
        circleRadius: 2.4,
        circleTranslate: _decalageEtincelle,
        circleStrokeColor: const Color(0x99D9AC67).toARGB32(),
        circleStrokeWidth: 1.6,
        circleBlur: 0.15,
      ),
    );

    // Un point est petit : on le touche dans un rond plus large,
    // invisible.
    await carte.addLayer(
      CircleLayer(
        id: _coucheToucher,
        sourceId: _source,
        filter: _estUnLieu,
        circleColor: const Color(0x03FFFFFF).toARGB32(),
        circleRadius: 18.0,
      ),
    );

    await _ajouterConstellation(carte);

    carte.addInteraction(
      TapInteraction.onMap((_) => widget.onTapCarte?.call()),
    );
    for (final couche in [_coucheVillesToucher, _coucheEtoilesToucher]) {
      carte.addInteraction(
        TapInteraction(FeaturesetDescriptor(layerId: couche), (lieu, _) {
          final cle = lieu.properties['cle'];
          if (cle is String) widget.onTapLieu(cle);
        }),
      );
    }
    carte.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _coucheToucher), (lieu, _) {
        final cle = lieu.properties['cle'];
        if (cle is String) widget.onTapLieu(cle);
      }),
    );
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
    _mettreAJourConstellation(widget.geojsonConstellation);
    _signalerZone();
  }

  Future<void> _ajouterConstellation(MapboxMap carte) async {
    await carte.addSource(GeoJsonSource(id: _sourceConstellation));
    const estSillage = [
      '==',
      ['get', 'type'],
      'sillage',
    ];
    const estVille = [
      '==',
      ['get', 'type'],
      'ville',
    ];
    const estEtoile = [
      '==',
      ['get', 'type'],
      'etoile',
    ];
    const choisie = [
      'to-boolean',
      ['get', 'choisi'],
    ];

    // Le fil de mon histoire, de ville en ville.
    await carte.addLayer(
      LineLayer(
        id: _coucheSillage,
        sourceId: _sourceConstellation,
        filter: estSillage,
        maxZoom: _zoomEtoiles + 0.5,
        lineColor: TablTokens.primaire.toARGB32(),
        lineWidth: 1.3,
        lineOpacity: 0.55,
        lineBlur: 0.6,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheVillesHalo,
        sourceId: _sourceConstellation,
        filter: estVille,
        maxZoom: _zoomEtoiles + 0.5,
        circleColor: TablTokens.primaire.withValues(alpha: 0.3).toARGB32(),
        circleRadiusExpression: [
          'interpolate',
          ['linear'],
          ['get', 'repas'],
          1,
          9.0,
          40,
          22.0,
        ],
        circleBlur: 1.0,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheVilles,
        sourceId: _sourceConstellation,
        filter: estVille,
        maxZoom: _zoomEtoiles + 0.5,
        circleColor: const Color(0xFFFFF6E6).toARGB32(),
        circleRadiusExpression: [
          'interpolate',
          ['linear'],
          ['get', 'repas'],
          1,
          2.6,
          40,
          4.6,
        ],
      ),
    );
    await carte.addLayer(
      SymbolLayer(
        id: _coucheVillesNoms,
        sourceId: _sourceConstellation,
        filter: estVille,
        maxZoom: _zoomEtoiles + 0.5,
        textFieldExpression: ['get', 'etiquette'],
        textFont: _police,
        textSize: 10.5,
        textLetterSpacing: 0.12,
        textOffset: [0.0, 1.5],
        textAnchor: TextAnchor.TOP,
        textColor: TablTokens.texte.withValues(alpha: 0.86).toARGB32(),
        textHaloColor: const Color(0xCC06080C).toARGB32(),
        textHaloWidth: 1.2,
        textAllowOverlap: true,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheVillesToucher,
        sourceId: _sourceConstellation,
        filter: estVille,
        maxZoom: _zoomEtoiles + 0.5,
        circleColor: const Color(0x03FFFFFF).toARGB32(),
        circleRadius: 26.0,
      ),
    );

    // Mes restaurants, en étoiles.
    await carte.addLayer(
      CircleLayer(
        id: _coucheEtoilesHalo,
        sourceId: _sourceConstellation,
        filter: estEtoile,
        minZoom: _zoomEtoiles - 0.5,
        circleColorExpression: [
          'case',
          choisie,
          TablTokens.primaire.withValues(alpha: 0.55).toARGB32(),
          TablTokens.primaire.withValues(alpha: 0.26).toARGB32(),
        ],
        circleRadiusExpression: [
          'interpolate',
          ['linear'],
          ['get', 'fois'],
          1,
          8.0,
          10,
          24.0,
        ],
        circleBlur: 1.0,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheEtoiles,
        sourceId: _sourceConstellation,
        filter: estEtoile,
        minZoom: _zoomEtoiles - 0.5,
        circleColor: const Color(0xFFFFF6E6).toARGB32(),
        circleRadiusExpression: [
          'interpolate',
          ['linear'],
          ['get', 'fois'],
          1,
          2.4,
          10,
          5.2,
        ],
        circleStrokeColorExpression: [
          'case',
          choisie,
          TablTokens.primaire.toARGB32(),
          const Color(0x00000000).toARGB32(),
        ],
        circleStrokeWidth: 2.0,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheEtoilesToucher,
        sourceId: _sourceConstellation,
        filter: estEtoile,
        minZoom: _zoomEtoiles - 0.5,
        circleColor: const Color(0x03FFFFFF).toARGB32(),
        circleRadius: 18.0,
      ),
    );
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
    if (ancien.geojsonConstellation != widget.geojsonConstellation) {
      _mettreAJourConstellation(widget.geojsonConstellation);
    }
  }

  /// Mapbox refait les groupes lui-même à chaque nouvelle donnée.
  Future<void> _mettreAJour(String geojson) async {
    final source = await _carte?.getSource(_source);
    if (source is GeoJsonSource) await source.updateGeoJSON(geojson);
  }

  Future<void> _mettreAJourConstellation(String geojson) async {
    final source = await _carte?.getSource(_sourceConstellation);
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
