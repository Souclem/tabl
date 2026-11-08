import 'dart:convert';
import 'dart:io';

import 'lieu_carte.dart';

/// Un endroit où explorer : une ville, un quartier, une adresse.
class EndroitTrouve {
  const EndroitTrouve({required this.nom, required this.zone, this.detail});

  /// "Ixelles".
  final String nom;

  /// "Bruxelles, Belgique".
  final String? detail;

  /// Ce qu'on cadre en y allant.
  final ZoneCarte zone;
}

/// Trouver un endroit par son nom.
abstract interface class RechercheEndroitService {
  /// Les endroits qui correspondent à [texte], les plus proches de
  /// ([latitude], [longitude]) d'abord quand on les connaît.
  Future<List<EndroitTrouve>> chercher(
    String texte, {
    double? latitude,
    double? longitude,
  });
}

/// [RechercheEndroitService] par le géocodage de Mapbox, le service de
/// la carte : villes, quartiers et adresses, en français.
class RechercheEndroitMapbox implements RechercheEndroitService {
  RechercheEndroitMapbox(this._jeton);

  final String _jeton;

  /// Autour d'un point sans contour connu (une adresse) : environ 1 km.
  static const _demiCote = 0.008;

  @override
  Future<List<EndroitTrouve>> chercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async {
    final q = texte.trim();
    if (q.isEmpty || _jeton.isEmpty) return const [];
    final adresse = Uri.https('api.mapbox.com', '/search/geocode/v6/forward', {
      'q': q,
      'language': 'fr',
      'limit': '6',
      'types': 'place,locality,neighborhood,district,address',
      'proximity': ?(latitude != null && longitude != null
          ? '$longitude,$latitude'
          : null),
      'access_token': _jeton,
    });
    final client = HttpClient();
    try {
      final requete = await client.getUrl(adresse);
      final reponse = await requete.close();
      if (reponse.statusCode != 200) {
        throw HttpException('Géocodage : ${reponse.statusCode}', uri: adresse);
      }
      final corps = await reponse.transform(utf8.decoder).join();
      return endroitsDepuisMapbox(jsonDecode(corps) as Map<String, dynamic>);
    } finally {
      client.close();
    }
  }
}

/// Les endroits d'une réponse du géocodage Mapbox (v6) : leur nom, où ils
/// se trouvent, et leur contour s'il est donné.
List<EndroitTrouve> endroitsDepuisMapbox(Map<String, dynamic> reponse) {
  return [
    for (final f
        in (reponse['features'] as List? ?? const [])
            .cast<Map<String, dynamic>>())
      ?_endroit(f['properties'] as Map<String, dynamic>?),
  ];
}

EndroitTrouve? _endroit(Map<String, dynamic>? p) {
  if (p == null) return null;
  final nom = p['name'] as String?;
  final coordonnees = p['coordinates'] as Map<String, dynamic>?;
  final lat = (coordonnees?['latitude'] as num?)?.toDouble();
  final lng = (coordonnees?['longitude'] as num?)?.toDouble();
  if (nom == null || lat == null || lng == null) return null;
  final bbox = (p['bbox'] as List?)?.cast<num>();
  final zone = bbox != null && bbox.length == 4
      ? ZoneCarte(
          ouest: bbox[0].toDouble(),
          sud: bbox[1].toDouble(),
          est: bbox[2].toDouble(),
          nord: bbox[3].toDouble(),
        )
      : ZoneCarte(
          sud: lat - RechercheEndroitMapbox._demiCote,
          nord: lat + RechercheEndroitMapbox._demiCote,
          ouest: lng - RechercheEndroitMapbox._demiCote,
          est: lng + RechercheEndroitMapbox._demiCote,
        );
  return EndroitTrouve(
    nom: nom,
    detail: p['place_formatted'] as String?,
    zone: zone,
  );
}
