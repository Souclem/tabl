import '../position/position_service.dart';
import '../restaurants/categories_lieu.dart';
import '../restaurants/distance.dart';
import '../restaurants/lieu_restaurant.dart';
import 'date_souvenir.dart';
import 'metadonnees_photo.dart';

/// Ce que les photos d'un repas laissent deviner : le jour, le moment et
/// l'endroit. Ce ne sont que des propositions, toutes modifiables.
class Precompletion {
  const Precompletion({
    this.date,
    this.moment,
    this.position,
    this.premierePhoto,
  });

  static const rien = Precompletion();

  final DateSouvenir? date;

  /// `'midi'` ou `'soir'`, `null` si l'heure ne le dit pas.
  final String? moment;

  /// Le centre des photos qui ont une position.
  final Coordonnees? position;

  /// L'heure de la première photo du repas.
  final DateTime? premierePhoto;
}

/// Le repas commence à la première photo : c'est elle qui donne le jour
/// et le moment. Une date encore à venir (horloge d'appareil fausse)
/// n'est pas retenue.
Precompletion precompleter(
  Iterable<MetadonneesPhoto> photos, {
  required DateTime maintenant,
}) {
  final dates = [
    for (final p in photos)
      if (p.prisLe case final d? when !d.isAfter(maintenant)) d,
  ]..sort();
  final placees = [
    for (final p in photos)
      if (p.aUnePosition) (latitude: p.latitude!, longitude: p.longitude!),
  ];
  final premiere = dates.firstOrNull;
  return Precompletion(
    date: premiere == null
        ? null
        : DateSouvenir(
            annee: premiere.year,
            mois: premiere.month,
            jour: premiere.day,
          ),
    moment: premiere == null ? null : momentDApresHeure(premiere),
    premierePhoto: premiere,
    position: placees.isEmpty
        ? null
        : (
            latitude:
                placees.map((p) => p.latitude).reduce((a, b) => a + b) /
                placees.length,
            longitude:
                placees.map((p) => p.longitude).reduce((a, b) => a + b) /
                placees.length,
          ),
  );
}

/// Déjeuner de 10 h à 17 h, dîner de 17 h à 3 h du matin ; entre les
/// deux, l'heure ne dit rien de sûr.
String? momentDApresHeure(DateTime heure) {
  final h = heure.hour;
  if (h >= 10 && h < 17) return 'midi';
  if (h >= 17 || h < 3) return 'soir';
  return null;
}

/// "20 h 41".
String heureLisible(DateTime heure) =>
    '${heure.hour} h ${heure.minute.toString().padLeft(2, '0')}';

/// Sous le nom du restaurant d'un souvenir : "Végétarien · Liège · à
/// 40 m de la photo". [depuisLaPhoto] : la distance du lieu est celle
/// qui le sépare de l'endroit des photos (sinon, du téléphone : elle ne
/// dit rien du souvenir, on la tait).
String detailLieuSouvenir(LieuRestaurant lieu, {required bool depuisLaPhoto}) {
  final distance = lieu.distanceM;
  return [
    if (lieu.categories.isNotEmpty) libelleCategorie(lieu.categories.first),
    if (lieu.ville.isNotEmpty) lieu.ville,
    if (depuisLaPhoto && distance != null)
      'à ${distanceLisible(distance)} de la photo',
  ].join(' · ');
}
