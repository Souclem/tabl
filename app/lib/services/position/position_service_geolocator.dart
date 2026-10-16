import 'package:geolocator/geolocator.dart';

import 'position_service.dart';

class PositionServiceGeolocator implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      // Une position approximative suffit pour trier des restaurants ;
      // la dernière connue d'abord, pour répondre tout de suite.
      final position =
          await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 8),
            ),
          );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null;
    }
  }
}
