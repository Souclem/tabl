import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../../theme/apparence.dart';
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
/// Une couleur dans une expression Mapbox : le style attend une chaîne
/// (« rgba(…) »), pas l'entier ARGB des propriétés simples.
String _rgba(Color c) {
  int canal(double v) => (v * 255).round();
  return 'rgba(${canal(c.r)}, ${canal(c.g)}, ${canal(c.b)}, ${c.a.toStringAsFixed(3)})';
}

const styleCarteTabl = 'mapbox://styles/clemlon/cmvfdwxja009q01pl6rox6613';

/// La carte Mapbox de Tabl : globe 3D au dézoom, notre style sans les
/// commerces de Mapbox (seuls nos lieux ressortent), ma position et une
/// boussole.
///
/// En sombre, notre style de Mapbox Studio ; en clair ([clair]), le style
/// « Standard » de Mapbox, de jour, sans ses commerces (maquette de
/// Martin : terre beige, routes blanches, eau bleue).
///
/// Les lieux proches à l'écran se regroupent en une bulle qui dit
/// combien ils sont : « 42 » sur une ville vue de loin, puis « 3 », « 2 »,
/// « 5 » par quartier en zoomant ; un tap sur une bulle zoome juste
/// assez pour l'ouvrir. De près, chaque lieu est un point de la couleur
/// de sa tuile (propriété `teinte` : nuit, braise ou ivoire), avec sa
/// note dans une pastille de la même couleur (`etiquette`) ; le lieu
/// choisi grossit, cerclé d'or (`choisi`). Le regroupement est celui de Mapbox : il suit la
/// distance à l'écran, pas les frontières, et vaut partout dans le
/// monde. Un point marqué `repere` (l'endroit d'une photo) est un rond
/// blanc cerclé d'or, qu'on ne touche pas.
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
    this.clair = false,
  });

  /// Aucun point.
  static const geojsonVide = '{"type":"FeatureCollection","features":[]}';

  /// Le style clair (voir plus haut) ; sinon, celui de nuit.
  final bool clair;

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
  static const _coucheNotes = 'tabl-lieux-notes';
  static const _coucheRepere = 'tabl-repere';

  /// Distance à l'écran (pt) sous laquelle des lieux se regroupent.
  static const _rayonGroupes = 46.0;

  /// Au-delà de ce zoom (quelques rues), plus aucun regroupement : chaque
  /// restaurant a son point.
  static const _zoomMaxGroupes = 14.0;

  /// Les polices du style de Tabl (les seules que Mapbox lui sert).
  static const _police = ['DIN Pro Medium', 'Arial Unicode MS Regular'];

  /// En deçà, pas de notes : des points seulement.
  static const _zoomNotes = 13.5;

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
  static const List<Object> _aUneNote = [
    'all',
    _estUnLieu,
    ['has', 'etiquette'],
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

  PaletteExplorer get _palette =>
      widget.clair ? PaletteExplorer.clair : PaletteExplorer.sombre;

  /// La couleur d'un lieu, d'après sa `teinte`.
  List<Object> get _couleurTeinte => [
    'match',
    ['get', 'teinte'],
    'retour',
    _rgba(_palette.tuileRetour),
    'vous',
    _rgba(_palette.tuileVous),
    _rgba(_palette.tuileCercle),
  ];

  /// Le style « Standard », de jour et sans ses commerces.
  Future<void> _reglerStyleClair(MapboxMap carte) async {
    const reglages = {
      'lightPreset': 'day',
      'theme': 'faded',
      'showPointOfInterestLabels': false,
      'showTransitLabels': false,
      'show3dObjects': false,
    };
    for (final MapEntry(:key, :value) in reglages.entries) {
      try {
        await carte.setStyleImportConfigProperty('basemap', key, value);
      } catch (e) {
        debugPrint('TablCarteMapbox: réglage $key : $e');
      }
    }
  }

  /// Les pastilles des notes, une par teinte : un rectangle arrondi
  /// dessiné ici, étiré par Mapbox autour du texte.
  Future<void> _ajouterPastilles(MapboxMap carte) async {
    const echelle = 3.0;
    const largeur = 40.0;
    const hauteur = 26.0;
    final teintes = {
      'cercle': _palette.tuileCercle,
      'retour': _palette.tuileRetour,
      'vous': _palette.tuileVous,
    };
    for (final MapEntry(key: teinte, value: couleur) in teintes.entries) {
      final enregistreur = ui.PictureRecorder();
      final toile = Canvas(enregistreur)..scale(echelle);
      final forme = RRect.fromRectAndRadius(
        const Rect.fromLTWH(1, 1, largeur - 2, hauteur - 2),
        const Radius.circular(12),
      );
      toile.drawRRect(forme, Paint()..color = couleur);
      if (teinte == 'vous') {
        toile.drawRRect(
          forme,
          Paint()
            ..color = TablTokens.encre
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      final image = await enregistreur.endRecording().toImage(
        (largeur * echelle).round(),
        (hauteur * echelle).round(),
      );
      try {
        await carte.addImage(
          'tabl-pastille-$teinte',
          echelle,
          await StyleImage.fromImage(image),
          // En pixels de l'image (dessinée à l'échelle 3).
          stretchX: [
            ImageStretches(
              first: 14 * echelle,
              second: (largeur - 14) * echelle,
            ),
          ],
          stretchY: [
            ImageStretches(
              first: 11 * echelle,
              second: (hauteur - 11) * echelle,
            ),
          ],
          content: ImageContent(
            left: 10 * echelle,
            top: 4 * echelle,
            right: (largeur - 10) * echelle,
            bottom: (hauteur - 4) * echelle,
          ),
        );
      } catch (e) {
        debugPrint('TablCarteMapbox: pastille $teinte : $e');
      }
    }
  }

  Future<void> _styleChargeListener(StyleLoadedEventData _) async {
    final carte = _carte;
    if (carte == null) return;
    if (widget.clair) await _reglerStyleClair(carte);
    await _ajouterPastilles(carte);
    await carte.addSource(
      GeoJsonSource(
        id: _source,
        cluster: true,
        clusterRadius: _rayonGroupes,
        clusterMaxZoom: _zoomMaxGroupes,
      ),
    );

    // Les groupes : une bulle (sombre la nuit, blanche le jour), plus
    // grande quand ils sont nombreux, et leur nombre au centre.
    await carte.addLayer(
      CircleLayer(
        id: _coucheGroupes,
        sourceId: _source,
        filter: _estUnGroupe,
        circleColor: widget.clair
            ? const Color(0xFFFFFFFF).toARGB32()
            : const Color(0xF21A1C21).toARGB32(),
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
        circleStrokeColor: widget.clair
            ? TablTokens.encre.withValues(alpha: 0.1).toARGB32()
            : const Color(0x52F5F0E8).toARGB32(),
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
        textColor: widget.clair
            ? TablTokens.encre.toARGB32()
            : TablTokens.texte.toARGB32(),
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

    // Un lieu seul : un point de la couleur de sa tuile, plus gros et
    // cerclé d'or s'il est choisi.
    await carte.addLayer(
      CircleLayer(
        id: _coucheLieux,
        sourceId: _source,
        filter: _estUnLieu,
        circleColorExpression: _couleurTeinte,
        circleRadiusExpression: ['case', _choisiExpression, 7.5, 5.0],
        circleStrokeColorExpression: [
          'case',
          _choisiExpression,
          _rgba(TablTokens.primaire),
          widget.clair
              ? _rgba(const Color(0xFFFFFFFF))
              : _rgba(const Color(0xE6101114)),
        ],
        circleStrokeWidthExpression: ['case', _choisiExpression, 3.0, 1.6],
      ),
    );

    // De près, sa note dans une pastille de la même couleur, posée
    // au-dessus du point.
    await carte.addLayer(
      SymbolLayer(
        id: _coucheNotes,
        sourceId: _source,
        filter: _aUneNote,
        minZoom: _zoomNotes,
        textFieldExpression: ['get', 'etiquette'],
        textFont: _police,
        textSize: 13.0,
        textColorExpression: [
          'match',
          ['get', 'teinte'],
          'vous',
          _rgba(TablTokens.encre),
          _rgba(TablTokens.texte),
        ],
        textAnchor: TextAnchor.BOTTOM,
        textOffset: [0, -0.9],
        iconImageExpression: [
          'concat',
          'tabl-pastille-',
          ['get', 'teinte'],
        ],
        iconTextFit: IconTextFit.BOTH,
        iconTextFitPadding: [4, 9, 4, 9],
        iconAnchor: IconAnchor.BOTTOM,
        iconOffset: [0, -6],
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

    carte.addInteraction(
      TapInteraction.onMap((_) => widget.onTapCarte?.call()),
    );
    for (final couche in [_coucheNotes, _coucheToucher]) {
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

  String get _styleUri => widget.clair ? MapboxStyles.STANDARD : styleCarteTabl;

  @override
  void didUpdateWidget(TablCarteMapbox ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.clair != widget.clair) {
      _styleCharge = false;
      _carte?.loadStyleURI(_styleUri);
      return;
    }
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
      styleUri: _styleUri,
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
