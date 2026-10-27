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
    this.autresEndroits = const [],
    this.premierePhoto,
  });

  static const rien = Precompletion();

  final DateSouvenir? date;

  /// `'midi'` ou `'soir'`, `null` si l'heure ne le dit pas.
  final String? moment;

  /// Le centre de l'endroit où la plupart des photos ont été prises.
  final Coordonnees? position;

  /// Les autres endroits des photos, s'il y en a (une photo dans la rue,
  /// une autre ailleurs) : on y cherche aussi, au cas où.
  final List<Coordonnees> autresEndroits;

  /// L'heure de la première photo du repas.
  final DateTime? premierePhoto;
}

/// Les photos d'un repas, même choisies un peu large (une photo dans la
/// rue, une autre chez soi après), ont surtout été prises au restaurant :
/// l'endroit retenu est celui où les photos sont les plus nombreuses
/// ([endroitDesPhotos]). Le repas commence à la première photo de cet
/// endroit (toutes, si aucune n'a de position) : elle donne le jour et
/// le moment. Une date encore à venir (horloge d'appareil fausse) n'est
/// pas retenue.
Precompletion precompleter(
  Iterable<MetadonneesPhoto> photos, {
  required DateTime maintenant,
}) {
  final valables = [
    for (final p in photos)
      if (p.prisLe?.isAfter(maintenant) ?? false)
        MetadonneesPhoto(latitude: p.latitude, longitude: p.longitude)
      else
        p,
  ];
  final endroits = endroitsDesPhotos(valables);
  final duRepas = endroits.firstOrNull?.photos ?? valables;
  final dates = [for (final p in duRepas) ?p.prisLe]..sort();
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
    position: endroits.firstOrNull?.position,
    autresEndroits: [for (final e in endroits.skip(1)) e.position],
  );
}

/// Les endroits où les photos ont été prises, le principal d'abord :
/// chaque photo compte celles prises à moins de [rayonM] d'elle, le
/// groupe le plus fourni forme le premier endroit — à égalité, celui de
/// la photo la plus ancienne —, puis on recommence avec les autres
/// photos. Deux photos prises à deux endroits : deux endroits, celui de
/// la première d'abord. Vide si aucune n'a de position.
List<({Coordonnees position, List<MetadonneesPhoto> photos})> endroitsDesPhotos(
  Iterable<MetadonneesPhoto> photos, {
  double rayonM = 150,
}) {
  final sansDate = DateTime(9999);
  // Les plus anciennes d'abord, pour qu'elles gagnent les égalités.
  final restantes = [
    for (final p in photos)
      if (p.aUnePosition) p,
  ]..sort((a, b) => (a.prisLe ?? sansDate).compareTo(b.prisLe ?? sansDate));
  bool proches(MetadonneesPhoto a, MetadonneesPhoto b) =>
      distanceEnMetres(a.latitude!, a.longitude!, b.latitude!, b.longitude!) <=
      rayonM;

  final endroits = <({Coordonnees position, List<MetadonneesPhoto> photos})>[];
  while (restantes.isNotEmpty) {
    List<MetadonneesPhoto>? groupe;
    for (final centre in restantes) {
      final voisines = [
        for (final p in restantes)
          if (proches(centre, p)) p,
      ];
      if (groupe == null || voisines.length > groupe.length) groupe = voisines;
    }
    final membres = groupe!;
    restantes.removeWhere(membres.contains);
    double moyenne(double Function(MetadonneesPhoto) valeur) =>
        membres.map(valeur).reduce((a, b) => a + b) / membres.length;
    endroits.add((
      position: (
        latitude: moyenne((p) => p.latitude!),
        longitude: moyenne((p) => p.longitude!),
      ),
      photos: membres,
    ));
  }
  return endroits;
}

/// [lieu] avec sa distance au plus proche des [endroits] (ceux des
/// photos, ou le téléphone) ; inchangé s'il n'y en a pas.
LieuRestaurant aDistanceDesEndroits(
  LieuRestaurant lieu,
  List<Coordonnees> endroits,
) {
  LieuRestaurant? meilleur;
  for (final e in endroits) {
    final candidat = lieu.aDistanceDe(e.latitude, e.longitude);
    final d = candidat.distanceM;
    if (d != null && (meilleur == null || d < meilleur.distanceM!)) {
      meilleur = candidat;
    }
  }
  return meilleur ?? lieu;
}

/// Déjeuner de 10 h à 17 h, dîner de 17 h à 3 h du matin ; entre les
/// deux, l'heure ne dit rien de sûr.
String? momentDApresHeure(DateTime heure) {
  final h = heure.hour;
  if (h >= 10 && h < 17) return 'midi';
  if (h >= 17 || h < 3) return 'soir';
  return null;
}

/// Le moment d'un repas pris maintenant : avant 17 h, c'est midi. Toujours
/// l'un ou l'autre — contrairement à [momentDApresHeure], l'heure d'un
/// moment publié sur place ne laisse pas de doute.
String momentDuJour(DateTime maintenant) =>
    maintenant.hour < 17 ? 'midi' : 'soir';

/// "20 h 41".
String heureLisible(DateTime heure) =>
    '${heure.hour} h ${heure.minute.toString().padLeft(2, '0')}';

/// D'où se mesure la distance d'un lieu proposé : l'endroit des photos
/// (un souvenir), ou là où l'on est (un moment publié sur place).
enum RepereDistance {
  photo('de la photo'),
  vous('de vous');

  const RepereDistance(this.libelle);

  final String libelle;
}

/// Sous le nom du restaurant d'un souvenir ou d'un moment : "Végétarien
/// · Liège · à 40 m de la photo". Sans [repere], la distance du lieu ne
/// dit rien du repas (mesurée depuis ailleurs) : on la tait.
String detailLieuSouvenir(LieuRestaurant lieu, {RepereDistance? repere}) {
  if (lieu.personnel) return 'Lieu personnel · jamais public';
  final distance = lieu.distanceM;
  return [
    if (lieu.categories.isNotEmpty) libelleCategorie(lieu.categories.first),
    if (lieu.ville.isNotEmpty) lieu.ville,
    if (repere != null && distance != null)
      'à ${distanceLisible(distance)} ${repere.libelle}',
  ].join(' · ');
}
