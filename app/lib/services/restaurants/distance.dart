import 'dart:math';

/// Distance à vol d'oiseau entre deux points, en mètres (formule de
/// haversine — largement assez précise à l'échelle d'une ville).
double distanceEnMetres(
  double latitude1,
  double longitude1,
  double latitude2,
  double longitude2,
) {
  const rayonTerre = 6371000.0;
  double radians(double degres) => degres * pi / 180;
  final dLat = radians(latitude2 - latitude1);
  final dLng = radians(longitude2 - longitude1);
  final a =
      pow(sin(dLat / 2), 2) +
      cos(radians(latitude1)) * cos(radians(latitude2)) * pow(sin(dLng / 2), 2);
  return rayonTerre * 2 * asin(sqrt(a));
}

/// "350 m", "1,6 km", "12 km".
String distanceLisible(double metres) {
  if (metres < 1000) return '${(metres / 10).round() * 10} m';
  if (metres < 10000) {
    return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
  }
  return '${(metres / 1000).round()} km';
}
