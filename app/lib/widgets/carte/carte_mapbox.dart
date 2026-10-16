import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// La carte Mapbox de Tabl : globe 3D au dézoom, style nuit sans les
/// commerces de Mapbox (seuls nos lieux ressortent), ma position et une
/// boussole. Chaque lieu : la photo de l'ami mis en avant dans une bulle
/// dorée, avec « +N » s'il y a d'autres amis (propriétés `photo` et
/// `autres` du GeoJSON) ; sinon un simple marqueur doré.
///
/// Composant pur : reçoit les lieux déjà choisis (les plus pertinents,
/// au format GeoJSON) et renvoie le tap sur un lieu ([onTapLieu], avec sa
/// clé) et la zone visible après chaque déplacement ([onZoneVisible]).
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

  @override
  State<TablCarteMapbox> createState() => _TablCarteMapboxState();
}

class _TablCarteMapboxState extends State<TablCarteMapbox> {
  static const _source = 'tabl-lieux';
  static const _couche = 'tabl-lieux-points';
  static const _coucheBulles = 'tabl-lieux-bulles';

  /// Bulles déjà dessinées et ajoutées au style (par identifiant).
  final Set<String> _bullesAjoutees = {};

  /// Bulles en cours de préparation : une même bulle n'est jamais
  /// préparée deux fois en parallèle.
  final Map<String, Future<void>> _bullesEnCours = {};

  /// Le dernier GeoJSON demandé : une préparation terminée après un
  /// nouveau déplacement ne remet pas à jour avec des données périmées.
  String _dernierGeojson = '';

  /// Photos téléchargées en même temps, au plus.
  static const _telechargementsSimultanes = 8;

  // Animation d'apparition / disparition : Mapbox n'anime pas un
  // changement de données, on la joue donc image par image en faisant
  // varier deux propriétés de chaque lieu, lues par les couches.
  static const _dureeAnimation = Duration(milliseconds: 260);
  static const _imagesAnimation = 9;
  static const List<Object> _opaciteExpression = [
    'coalesce',
    ['get', 'opacite'],
    1.0,
  ];
  static const List<Object> _echelleExpression = [
    '*',
    [
      'coalesce',
      ['get', 'echelle'],
      1.0,
    ],
    // Le lieu dont la feuille est ouverte ressort.
    [
      'case',
      [
        'to-boolean',
        ['get', 'choisi'],
      ],
      1.35,
      1.0,
    ],
  ];

  /// Les lieux actuellement à l'écran, par identifiant d'affichage.
  Map<String, Map<String, dynamic>> _affiches = {};

  /// Incrémenté à chaque nouvelle mise à jour : une animation en cours
  /// s'arrête dès qu'une plus récente commence.
  int _generation = 0;

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
        enabled: true,
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
    await carte.setProjection(StyleProjection(name: StyleProjectionName.globe));
    await carte.setStyleImportConfigProperty('basemap', 'lightPreset', 'night');
    await carte.setStyleImportConfigProperty(
      'basemap',
      'showPointOfInterestLabels',
      false,
    );

    await carte.addSource(GeoJsonSource(id: _source));
    await carte.addLayer(
      CircleLayer(
        id: _couche,
        sourceId: _source,
        slot: 'top',
        filter: [
          '!',
          ['has', 'bulle'],
        ],
        circleColor: TablTokens.primaire.toARGB32(),
        // Le mode nuit du style assombrit tout ce qui n'émet pas sa propre
        // lumière : sans ça, les marqueurs dorés deviennent noirs.
        circleEmissiveStrength: 1,
        // Lieu de mon réseau : marqueur plein ; restaurant où personne
        // n'est allé : petit point, pour en voir beaucoup sans surcharge.
        circleRadiusExpression: [
          '*',
          [
            'case',
            ['get', 'reseau'],
            7.0,
            4.0,
          ],
          _echelleExpression,
        ],
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidthExpression: [
          'case',
          ['get', 'reseau'],
          2.0,
          1.0,
        ],
        circleOpacityExpression: _opaciteExpression,
        circleStrokeOpacityExpression: _opaciteExpression,
      ),
    );
    await carte.addLayer(
      SymbolLayer(
        id: _coucheBulles,
        sourceId: _source,
        slot: 'top',
        filter: ['has', 'bulle'],
        iconImageExpression: ['get', 'bulle'],
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
        iconEmissiveStrength: 1,
        iconOpacityExpression: _opaciteExpression,
        iconSizeExpression: _echelleExpression,
      ),
    );
    carte.addInteraction(
      TapInteraction.onMap((_) => widget.onTapCarte?.call()),
    );
    for (final couche in [_couche, _coucheBulles]) {
      carte.addInteraction(
        TapInteraction(FeaturesetDescriptor(layerId: couche), (lieu, _) {
          final cle = lieu.properties['cle'];
          if (cle is String) widget.onTapLieu(cle);
        }),
      );
    }

    _styleCharge = true;
    widget.controleur?._carteChargee(carte);
    _mettreAJour(_source, widget.geojsonLieux);
    _signalerZone();
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
      _mettreAJour(_source, widget.geojsonLieux);
    }
  }

  /// Affiche tout de suite les lieux — en simples marqueurs dorés tant
  /// que leur bulle photo n'est pas prête —, prépare en parallèle les
  /// bulles manquantes, puis remet à jour dès qu'elles le sont.
  Future<void> _mettreAJour(String sourceId, String geojson) async {
    _dernierGeojson = geojson;
    final donnees = jsonDecode(geojson) as Map<String, dynamic>;
    await _pousser(sourceId, donnees);

    final manquantes = <String, ({String photo, int autres})>{};
    for (final lieu in _lieux(donnees)) {
      final bulle = _bulleDe(lieu);
      if (bulle != null && !_bullesAjoutees.contains(bulle.id)) {
        manquantes[bulle.id] = (photo: bulle.photo, autres: bulle.autres);
      }
    }
    if (manquantes.isEmpty) return;

    final aPreparer = manquantes.entries.toList();
    for (var debut = 0; debut < aPreparer.length; debut += _telechargementsSimultanes) {
      await Future.wait([
        for (final bulle in aPreparer.skip(debut).take(_telechargementsSimultanes))
          _bullesEnCours.putIfAbsent(
            bulle.key,
            () => _preparerBulle(bulle.key, bulle.value.photo, bulle.value.autres),
          ),
      ]);
      // Montrer les bulles au fur et à mesure, sauf si la carte a bougé
      // entre-temps (une autre mise à jour a pris le relais).
      if (_dernierGeojson != geojson) return;
      await _pousser(sourceId, donnees);
    }
  }

  static List<Map<String, dynamic>> _lieux(Map<String, dynamic> donnees) =>
      (donnees['features'] as List).cast<Map<String, dynamic>>();

  static ({String id, String photo, int autres})? _bulleDe(
    Map<String, dynamic> lieu,
  ) {
    final proprietes = lieu['properties'] as Map<String, dynamic>;
    final photo = proprietes['photo'] as String?;
    if (photo == null) return null;
    final autres = (proprietes['autres'] as num?)?.toInt() ?? 0;
    return (id: 'bulle-${photo.hashCode}-$autres', photo: photo, autres: autres);
  }

  /// Envoie les lieux à la carte, avec leur bulle pour ceux dont elle est
  /// prête (propriété `bulle`) ; les autres restent des marqueurs dorés.
  /// Les lieux qui arrivent apparaissent en fondu en grandissant, ceux qui
  /// partent s'effacent ; un point qui devient bulle fait un fondu enchaîné
  /// (ce n'est plus le même marqueur à l'écran).
  Future<void> _pousser(String sourceId, Map<String, dynamic> donnees) async {
    final cibles = <String, Map<String, dynamic>>{};
    for (final lieu in _lieux(donnees)) {
      final bulle = _bulleDe(lieu);
      final proprietes = Map<String, dynamic>.of(
        lieu['properties'] as Map<String, dynamic>,
      );
      final pret = bulle != null && _bullesAjoutees.contains(bulle.id);
      if (pret) {
        proprietes['bulle'] = bulle.id;
      } else {
        proprietes.remove('bulle');
      }
      final cle = '${proprietes['cle']}|${pret ? bulle.id : ''}';
      cibles[cle] = {...lieu, 'properties': proprietes};
    }

    final generation = ++_generation;
    final entrants = {for (final c in cibles.keys) if (!_affiches.containsKey(c)) c};
    final sortants = {for (final c in _affiches.keys) if (!cibles.containsKey(c)) c};
    final depart = _affiches;
    _affiches = cibles;

    final source = await _carte?.getSource(sourceId);
    if (source is! GeoJsonSource) return;
    if (entrants.isEmpty && sortants.isEmpty) {
      await source.updateGeoJSON(_collection(cibles.values));
      return;
    }

    final pause = _dureeAnimation ~/ _imagesAnimation;
    for (var image = 1; image <= _imagesAnimation; image++) {
      if (generation != _generation) return;
      // Démarrage rapide, arrivée douce.
      final t = Curves.easeOutCubic.transform(image / _imagesAnimation);
      await source.updateGeoJSON(
        _collection([
          for (final MapEntry(key: cle, value: lieu) in cibles.entries)
            entrants.contains(cle) ? _avec(lieu, t, 0.6 + 0.4 * t) : lieu,
          for (final cle in sortants)
            _avec(depart[cle]!, 1 - t, 1 - 0.4 * t),
        ]),
      );
      if (image < _imagesAnimation) await Future<void>.delayed(pause);
    }
  }

  static Map<String, dynamic> _avec(
    Map<String, dynamic> lieu,
    double opacite,
    double echelle,
  ) => {
    ...lieu,
    'properties': {
      ...lieu['properties'] as Map<String, dynamic>,
      'opacite': opacite,
      'echelle': echelle,
    },
  };

  static String _collection(Iterable<Map<String, dynamic>> lieux) =>
      jsonEncode({'type': 'FeatureCollection', 'features': lieux.toList()});

  /// Télécharge la photo, dessine la bulle et l'ajoute au style. Une
  /// photo qui ne charge pas laisse simplement le marqueur doré.
  Future<void> _preparerBulle(String id, String photo, int autres) async {
    final carte = _carte;
    if (carte == null) return;
    final octets = await _telecharger(photo);
    if (octets == null) return;
    final image = await _dessinerBulle(octets, autres);
    if (image == null) return;
    await carte.addImage(id, _echelle, image);
    _bullesAjoutees.add(id);
  }

  static Future<Uint8List?> _telecharger(String url) async {
    try {
      final donnees = await NetworkAssetBundle(Uri.parse(url)).load(url);
      return donnees.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Densité de dessin des bulles (nettes sur les écrans Retina).
  static const _echelle = 3.0;

  /// La bulle : photo ronde cerclée d'or (44 pt), et en bas à droite un
  /// badge « +N » si d'autres amis y sont allés.
  static Future<StyleImage?> _dessinerBulle(Uint8List photo, int autres) async {
    try {
      const cote = 56.0;
      const rayon = 22.0;
      const centre = Offset(24, 24);
      final codec = await ui.instantiateImageCodec(
        photo,
        targetWidth: (rayon * 2 * _echelle).round(),
        targetHeight: (rayon * 2 * _echelle).round(),
      );
      final image = (await codec.getNextFrame()).image;

      final enregistreur = ui.PictureRecorder();
      final toile = Canvas(enregistreur)..scale(_echelle);
      toile.drawCircle(centre, rayon + 2.5, Paint()..color = TablTokens.primaire);
      toile.save();
      toile.clipPath(
        Path()..addOval(Rect.fromCircle(center: centre, radius: rayon)),
      );
      paintImage(
        canvas: toile,
        rect: Rect.fromCircle(center: centre, radius: rayon),
        image: image,
        fit: BoxFit.cover,
      );
      toile.restore();

      if (autres > 0) {
        const centreBadge = Offset(43, 43);
        toile.drawCircle(centreBadge, 11, Paint()..color = TablTokens.fond);
        toile.drawCircle(
          centreBadge,
          11,
          Paint()
            ..color = TablTokens.primaire
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final texte = TextPainter(
          text: TextSpan(
            text: autres > 99 ? '+99' : '+$autres',
            style: const TextStyle(
              color: TablTokens.texte,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        texte.paint(
          toile,
          centreBadge - Offset(texte.width / 2, texte.height / 2),
        );
      }

      final px = (cote * _echelle).round();
      final rendu = await enregistreur.endRecording().toImage(px, px);
      final png = await rendu.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) return null;
      return StyleImage.bytes(png.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('tabl-carte'),
      styleUri: MapboxStyles.STANDARD,
      viewport: _vueInitiale,
      onMapCreated: _creee,
      onStyleLoadedListener: _styleChargeListener,
      onCameraChangeListener: (_) => _cameraBouge(),
    );
  }
}
