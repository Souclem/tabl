import '../restaurants/distance.dart';
import '../restaurants/lieu_restaurant.dart';
import 'date_souvenir.dart';
import 'journal_profil.dart';
import 'metadonnees_photo.dart';
import 'presentation_souvenir.dart';

/// Au plus, par import : de quoi ranger plusieurs repas sans peser trop
/// lourd sur le téléphone (chaque photo est gardée en mémoire jusqu'à
/// son ajout).
const nombreMaxPhotosImport = 60;

/// Deux photos d'un même repas : prises à moins de ce temps l'une de
/// l'autre…
const ecartMaxDansUnRepas = Duration(hours: 3);

/// … et à moins de cette distance (quand les deux ont une position).
const distanceMaxDansUnRepas = 300.0;

/// Les photos choisies pour un import, rangées en repas.
class RangementImport {
  const RangementImport({
    required this.repas,
    required this.dejaImportees,
    required this.inexploitables,
  });

  /// Du plus ancien au plus récent ; dans chacun, les photos dans
  /// l'ordre où elles ont été prises.
  final List<List<PhotoChoisie>> repas;

  /// Déjà dans un souvenir : ignorées.
  final int dejaImportees;

  /// Ni date ni position (ou une position loin de tout repas) : rien ne
  /// dit à quel repas elles appartiennent.
  final int inexploitables;
}

/// Range des photos en repas, sans rien regarder d'autre que leur date
/// et leur position. Triées par heure, une photo rejoint le repas en
/// cours si elle suit la précédente de moins de [ecartMaxDansUnRepas]
/// et n'a pas été prise à plus de [distanceMaxDansUnRepas] de lui ;
/// sinon, un nouveau repas commence. Une photo sans date rejoint le
/// repas dont elle est assez proche, s'il y en a un. Les photos dont
/// l'[empreintes] est déjà connue (déjà importées) sont écartées.
RangementImport rangerEnRepas(
  List<PhotoChoisie> photos, {
  Set<String> empreintes = const {},
}) {
  var dejaImportees = 0;
  final datees = <PhotoChoisie>[];
  final sansDate = <PhotoChoisie>[];
  for (final p in photos) {
    final empreinte = p.metadonnees.empreinte;
    if (empreinte != null && empreintes.contains(empreinte)) {
      dejaImportees++;
    } else if (p.metadonnees.prisLe != null) {
      datees.add(p);
    } else {
      sansDate.add(p);
    }
  }
  datees.sort((a, b) => a.metadonnees.prisLe!.compareTo(b.metadonnees.prisLe!));

  final repas = <List<PhotoChoisie>>[];
  for (final photo in datees) {
    final enCours = repas.lastOrNull;
    if (enCours != null && _memeRepas(enCours, photo)) {
      enCours.add(photo);
    } else {
      repas.add([photo]);
    }
  }

  var inexploitables = 0;
  for (final photo in sansDate) {
    final proche = photo.metadonnees.aUnePosition
        ? _repasLePlusProche(repas, photo.metadonnees)
        : null;
    if (proche == null) {
      inexploitables++;
    } else {
      proche.add(photo);
    }
  }
  return RangementImport(
    repas: repas,
    dejaImportees: dejaImportees,
    inexploitables: inexploitables,
  );
}

bool _memeRepas(List<PhotoChoisie> repas, PhotoChoisie photo) {
  final m = photo.metadonnees;
  final derniere = repas.last.metadonnees.prisLe!;
  if (m.prisLe!.difference(derniere) > ecartMaxDansUnRepas) return false;
  if (!m.aUnePosition) return true;
  // Comparée à la dernière photo localisée du repas : on peut changer de
  // table, pas de quartier.
  final placee = repas.lastWhere(
    (p) => p.metadonnees.aUnePosition,
    orElse: () => photo,
  );
  return _distance(placee.metadonnees, m) <= distanceMaxDansUnRepas;
}

List<PhotoChoisie>? _repasLePlusProche(
  List<List<PhotoChoisie>> repas,
  MetadonneesPhoto photo,
) {
  List<PhotoChoisie>? meilleur;
  var meilleureDistance = distanceMaxDansUnRepas;
  for (final r in repas) {
    for (final p in r) {
      if (!p.metadonnees.aUnePosition) continue;
      final d = _distance(p.metadonnees, photo);
      if (d <= meilleureDistance) {
        meilleur = r;
        meilleureDistance = d;
      }
    }
  }
  return meilleur;
}

double _distance(MetadonneesPhoto a, MetadonneesPhoto b) =>
    distanceEnMetres(a.latitude!, a.longitude!, b.latitude!, b.longitude!);

/// Combien de photos d'un repas n'ont pas de position : elles y sont
/// par leur heure, on le dit (« 1 photo sans position, rattachée par
/// l'heure »).
String? mentionSansPosition(List<PhotoChoisie> repas) {
  if (repas.every((p) => !p.metadonnees.aUnePosition)) return null;
  final n = repas.where((p) => !p.metadonnees.aUnePosition).length;
  if (n == 0) return null;
  return n == 1
      ? '1 photo sans position, rattachée par l\'heure'
      : '$n photos sans position, rattachées par l\'heure';
}

/// Ce qu'un import a ajouté, pour son bilan.
class BilanImport {
  const BilanImport({
    required this.souvenirs,
    required this.restaurants,
    this.periode,
  });

  /// "3".
  final int souvenirs;
  final int restaurants;

  /// "Mars 2019 — Août 2026", ou "Mars 2023" pour un seul mois ; `null`
  /// sans souvenir.
  final String? periode;
}

BilanImport bilanImport(
  List<({LieuRestaurant lieu, DateSouvenir date})> ajoutes,
) {
  if (ajoutes.isEmpty) {
    return const BilanImport(souvenirs: 0, restaurants: 0);
  }
  final dates = ajoutes.map((a) => a.date.date).toList()..sort();
  String mois(DateTime d) => '${majuscule(nomDuMois(d.month))} ${d.year}';
  final debut = mois(dates.first);
  final fin = mois(dates.last);
  return BilanImport(
    souvenirs: ajoutes.length,
    restaurants: {for (final a in ajoutes) a.lieu.cle}.length,
    periode: debut == fin ? debut : '$debut — $fin',
  );
}
