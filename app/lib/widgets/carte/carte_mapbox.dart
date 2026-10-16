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

  Future<void> centrerSur(
    double latitude,
    double longitude, {
    double zoom = 14,
  }) async {
    await _carte?.flyTo(
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
  final Map<String, Future<Uint8List?>> _photos = {};

  MapboxMap? _carte;
  bool _styleCharge = false;

  Future<void> _creee(MapboxMap carte) async {
    _carte = carte;
    widget.controleur?._carte = carte;
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

    await carte.addSource(
      GeoJsonSource(
        id: _source,
        data: await _avecBulles(widget.geojsonLieux),
      ),
    );
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
        circleRadius: 7,
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 2,
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
      ),
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

  Future<void> _mettreAJour(String sourceId, String geojson) async {
    final complet = await _avecBulles(geojson);
    final source = await _carte?.getSource(sourceId);
    if (source is GeoJsonSource) await source.updateGeoJSON(complet);
  }

  /// Dessine (une seule fois chacune) les bulles photo des lieux qui en
  /// ont une, les ajoute au style, et renvoie le GeoJSON avec, pour ces
  /// lieux, le nom de leur bulle (`bulle`). Une photo qui ne charge pas
  /// laisse le lieu en simple marqueur doré.
  Future<String> _avecBulles(String geojson) async {
    final carte = _carte;
    if (carte == null) return geojson;
    final donnees = jsonDecode(geojson) as Map<String, dynamic>;
    for (final lieu in (donnees['features'] as List).cast<Map<String, dynamic>>()) {
      final proprietes = lieu['properties'] as Map<String, dynamic>;
      final photo = proprietes['photo'] as String?;
      if (photo == null) continue;
      final autres = (proprietes['autres'] as num?)?.toInt() ?? 0;
      final id = 'bulle-${photo.hashCode}-$autres';
      if (!_bullesAjoutees.contains(id)) {
        final octets = await _photos.putIfAbsent(photo, () => _telecharger(photo));
        if (octets == null) continue;
        final image = await _dessinerBulle(octets, autres);
        if (image == null) continue;
        await carte.addImage(id, _echelle, image);
        _bullesAjoutees.add(id);
      }
      proprietes['bulle'] = id;
    }
    return jsonEncode(donnees);
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
      viewport: CameraViewportState(
        center: Point(
          coordinates: Position(
            widget.longitudeInitiale,
            widget.latitudeInitiale,
          ),
        ),
        zoom: widget.zoomInitial,
      ),
      onMapCreated: _creee,
      onStyleLoadedListener: _styleChargeListener,
      onMapIdleListener: (_) => _signalerZone(),
    );
  }
}
