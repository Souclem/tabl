import 'presentation_souvenir.dart';

/// Le jour d'un souvenir ajouté après coup : le mois et l'année
/// suffisent, le jour est facultatif (« mars 2023 »).
class DateSouvenir {
  const DateSouvenir({required this.annee, required this.mois, this.jour});

  final int annee;

  /// De 1 à 12.
  final int mois;

  /// `null` : pas retenu.
  final int? jour;

  /// La date enregistrée : le 1er du mois quand le jour n'est pas connu.
  DateTime get date => DateTime(annee, mois, jour ?? 1);

  /// Un souvenir est passé : pas un jour (ou un mois) qui n'est pas
  /// encore arrivé.
  bool estDansLeFutur(DateTime maintenant) => jour == null
      ? annee * 12 + mois > maintenant.year * 12 + maintenant.month
      : date.isAfter(
          DateTime(maintenant.year, maintenant.month, maintenant.day),
        );

  /// "12 mars 2023", ou "mars 2023" sans le jour.
  String get libelle => [?jour, nomDuMois(mois), annee].join(' ');

  /// Le même mois ou la même année, avec un jour gardé seulement s'il
  /// existe encore (31 → février : plus de jour).
  DateSouvenir copierAvec({int? annee, int? mois, int? Function()? jour}) {
    final a = annee ?? this.annee;
    final m = mois ?? this.mois;
    final j = jour != null ? jour() : this.jour;
    return DateSouvenir(
      annee: a,
      mois: m,
      jour: j != null && j <= joursDansLeMois(a, m) ? j : null,
    );
  }
}

/// 28 à 31.
int joursDansLeMois(int annee, int mois) => DateTime(annee, mois + 1, 0).day;

/// Les années proposées pour un souvenir, de la plus récente à la plus
/// ancienne.
List<int> anneesSouvenir(DateTime maintenant) => [
  for (var a = maintenant.year; a >= maintenant.year - 60; a--) a,
];
