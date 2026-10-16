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
/// commerces de Mapbox (seuls nos lieux ressortent), et deux couches —
/// les lieux de mon réseau en marqueurs dorés regroupés selon le zoom,
/// l'annuaire en petits points discrets visibles seulement de près.
///
/// Composant pur : reçoit les lieux déjà au format GeoJSON et renvoie le
/// tap sur un lieu ([onTapLieu], avec sa clé) et la zone visible après
/// chaque déplacement ([onZoneVisible]).
class TablCarteMapbox extends StatefulWidget {
  const TablCarteMapbox({
    super.key,
    required this.geojsonReseau,
    required this.geojsonAnnuaire,
    required this.latitudeInitiale,
    required this.longitudeInitiale,
    required this.zoomInitial,
    required this.onTapLieu,
    required this.onZoneVisible,
    this.controleur,
  });

  final String geojsonReseau;
  final String geojsonAnnuaire;
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

  /// En dessous de ce zoom, les points de l'annuaire sont masqués (trop
  /// nombreux) — l'écran n'a pas besoin de les charger.
  static const zoomAnnuaire = 14.0;

  @override
  State<TablCarteMapbox> createState() => _TablCarteMapboxState();
}

class _TablCarteMapboxState extends State<TablCarteMapbox> {
  static const _sourceReseau = 'tabl-reseau';
  static const _sourceAnnuaire = 'tabl-annuaire';
  static const _coucheGroupes = 'tabl-reseau-groupes';
  static const _coucheNombre = 'tabl-reseau-nombre';
  static const _couchePoints = 'tabl-reseau-points';
  static const _coucheAnnuaire = 'tabl-annuaire-points';

  MapboxMap? _carte;
  bool _styleCharge = false;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  Future<void> _creee(MapboxMap carte) async {
    _carte = carte;
    widget.controleur?._carte = carte;
    await carte.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await carte.compass.updateSettings(CompassSettings(enabled: false));
  }

  Future<void> _styleChargeListener(StyleLoadedEventData _) async {
    final carte = _carte;
    if (carte == null) return;
    await carte.setProjection(
      StyleProjection(name: StyleProjectionName.globe),
    );
    await carte.setStyleImportConfigProperty('basemap', 'lightPreset', 'night');
    await carte.setStyleImportConfigProperty(
      'basemap',
      'showPointOfInterestLabels',
      false,
    );

    await carte.addSource(
      GeoJsonSource(id: _sourceAnnuaire, data: widget.geojsonAnnuaire),
    );
    await carte.addSource(
      GeoJsonSource(
        id: _sourceReseau,
        data: widget.geojsonReseau,
        cluster: true,
        clusterRadius: 44,
        clusterMaxZoom: 15,
      ),
    );

    final or = _hex(TablTokens.primaire);
    final fond = _hex(TablTokens.fond);
    await carte.addLayer(
      CircleLayer(
        id: _coucheAnnuaire,
        sourceId: _sourceAnnuaire,
        slot: 'top',
        minZoom: TablCarteMapbox.zoomAnnuaire,
        circleColor: TablTokens.texteDoux.toARGB32(),
        circleOpacity: 0.75,
        circleRadius: 4,
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 1,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _couchePoints,
        sourceId: _sourceReseau,
        slot: 'top',
        filter: [
          '!',
          ['has', 'point_count'],
        ],
        // Visité par le réseau : disque doré plein. Seulement en envie :
        // anneau doré.
        circleColorExpression: [
          'case',
          [
            '>',
            ['get', 'visites'],
            0,
          ],
          or,
          fond,
        ],
        circleRadiusExpression: [
          'interpolate',
          ['linear'],
          ['get', 'visites'],
          0, 7.0,
          1, 7.0,
          5, 10.0,
        ],
        circleStrokeColor: TablTokens.primaire.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );
    await carte.addLayer(
      CircleLayer(
        id: _coucheGroupes,
        sourceId: _sourceReseau,
        slot: 'top',
        filter: ['has', 'point_count'],
        circleColor: TablTokens.primaire.toARGB32(),
        circleOpacity: 0.92,
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          16.0,
          10,
          21.0,
          50,
          27.0,
        ],
        circleStrokeColor: TablTokens.fond.toARGB32(),
        circleStrokeWidth: 2,
      ),
    );
    await carte.addLayer(
      SymbolLayer(
        id: _coucheNombre,
        sourceId: _sourceReseau,
        slot: 'top',
        filter: ['has', 'point_count'],
        textFieldExpression: ['get', 'point_count_abbreviated'],
        textSize: 13,
        textColor: TablTokens.texteSurPrimaire.toARGB32(),
        textAllowOverlap: true,
      ),
    );

    carte.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _couchePoints), (lieu, _) {
        final cle = lieu.properties['cle'];
        if (cle is String) widget.onTapLieu(cle);
      }),
    );
    carte.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _coucheAnnuaire), (lieu, _) {
        final cle = lieu.properties['cle'];
        if (cle is String) widget.onTapLieu(cle);
      }),
    );
    // Un groupe : on zoome dessus pour le déplier.
    carte.addInteraction(
      TapInteraction(FeaturesetDescriptor(layerId: _coucheGroupes), (
        groupe,
        _,
      ) async {
        final coordonnees = (groupe.geometry['coordinates'] as List?)
            ?.cast<num>();
        if (coordonnees == null) return;
        final camera = await carte.getCameraState();
        await carte.easeTo(
          CameraOptions(
            center: Point(
              coordinates: Position(coordonnees[0], coordonnees[1]),
            ),
            zoom: camera.zoom + 2,
          ),
          MapAnimationOptions(duration: 500),
        );
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
    if (ancien.geojsonReseau != widget.geojsonReseau) {
      _mettreAJour(_sourceReseau, widget.geojsonReseau);
    }
    if (ancien.geojsonAnnuaire != widget.geojsonAnnuaire) {
      _mettreAJour(_sourceAnnuaire, widget.geojsonAnnuaire);
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
