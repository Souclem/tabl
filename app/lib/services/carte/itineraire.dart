import 'package:url_launcher/url_launcher.dart';

/// Le lien qui ouvre l'application de plans vers un restaurant : avec ses
/// coordonnées quand on les a, sinon avec son nom et son adresse. `null`
/// quand on ne sait rien pour y aller (le bouton Itinéraire est alors
/// masqué). [pourApple] : Plans (iPhone) ; sinon Google Maps.
Uri? lienItineraire({
  double? latitude,
  double? longitude,
  String? nom,
  String? adresse,
  bool pourApple = false,
}) {
  final destination =
      _coordonnees(latitude, longitude) ?? _nomEtAdresse(nom, adresse);
  if (destination == null) return null;
  return pourApple
      ? Uri.https('maps.apple.com', '/', {'daddr': destination, 'dirflg': 'd'})
      : Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': destination,
        });
}

String? _coordonnees(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return null;
  if (!latitude.isFinite || !longitude.isFinite) return null;
  if (latitude.abs() > 90 || longitude.abs() > 180) return null;
  return '$latitude,$longitude';
}

String? _nomEtAdresse(String? nom, String? adresse) {
  final morceaux = [
    for (final m in [nom, adresse])
      if (m != null && m.trim().isNotEmpty) m.trim(),
  ];
  return morceaux.isEmpty ? null : morceaux.join(', ');
}

/// Ouvre [lien] dans l'application de plans ; `false` si le téléphone ne
/// peut pas.
Future<bool> ouvrirItineraire(Uri lien) =>
    launchUrl(lien, mode: LaunchMode.externalApplication);
