import 'package:flutter/material.dart';
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
/// commerces de Mapbox (seuls nos lieux ressortent), et les lieux à
/// afficher, tous avec le même marqueur doré.
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

  MapboxMap? _carte;
  bool _styleCharge = false;

  Future<void> _creee(MapboxMap carte) async {
    _carte = carte;
    widget.controleur?._carte = carte;
    await carte.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await carte.compass.updateSettings(CompassSettings(enabled: false));
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
      GeoJsonSource(id: _source, data: widget.geojsonLieux),
    );
    await carte.addLayer(
      CircleLayer(
        id: _couche,
        sourceId: _source,
        slot: 'top',
        circleColor: TablTokens.primaire.toARGB32(),
        // Le mode nuit du style assombrit tout ce qui n'émet pas sa propre
        // lumière : sans ça, les marqueurs dorés deviennent noirs.
        circleEmissiveStrength: 1,
        circleRadius: 7,
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );
    carte.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _couche), (lieu, _) {
        final cle = lieu.properties['cle'];
        if (cle is String) widget.onTapLieu(cle);
      }),
    );

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
    final source = await _carte?.getSource(sourceId);
    if (source is GeoJsonSource) await source.updateGeoJSON(geojson);
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
