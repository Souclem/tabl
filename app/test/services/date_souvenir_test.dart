import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  final maintenant = DateTime(2026, 10, 26, 18);

  test('le mois et l\'année suffisent : le 1er du mois, sans le jour', () {
    const date = DateSouvenir(annee: 2023, mois: 3);

    expect(date.date, DateTime(2023, 3, 1));
    expect(date.libelle, 'mars 2023');
    expect(
      const DateSouvenir(annee: 2023, mois: 3, jour: 12).libelle,
      '12 mars 2023',
    );
  });

  test('un souvenir est passé : ni un mois ni un jour à venir', () {
    expect(
      const DateSouvenir(annee: 2026, mois: 10).estDansLeFutur(maintenant),
      isFalse,
    );
    expect(
      const DateSouvenir(annee: 2026, mois: 11).estDansLeFutur(maintenant),
      isTrue,
    );
    expect(
      const DateSouvenir(
        annee: 2026,
        mois: 10,
        jour: 26,
      ).estDansLeFutur(maintenant),
      isFalse,
    );
    expect(
      const DateSouvenir(
        annee: 2026,
        mois: 10,
        jour: 27,
      ).estDansLeFutur(maintenant),
      isTrue,
    );
  });

  test('changer de mois oublie un jour qui n\'y existe pas', () {
    const date = DateSouvenir(annee: 2023, mois: 1, jour: 31);

    expect(date.copierAvec(mois: 2).jour, isNull);
    expect(date.copierAvec(mois: 3).jour, 31);
    expect(date.copierAvec(jour: () => null).jour, isNull);
  });

  test('jours du mois, années bissextiles comprises', () {
    expect(joursDansLeMois(2024, 2), 29);
    expect(joursDansLeMois(2023, 2), 28);
    expect(joursDansLeMois(2023, 12), 31);
  });

  test('les années proposées partent de cette année', () {
    final annees = anneesSouvenir(maintenant);

    expect(annees.first, 2026);
    expect(annees, contains(2000));
    expect(annees.last, lessThan(annees.first));
  });

  test('sans le jour, une date se lit au mois', () {
    expect(
      dateLisibleSouvenir(DateTime(2023, 3), jourConnu: false),
      'mars 2023',
    );
    expect(
      dateLisibleSouvenir(DateTime(2026, 3, 12), maintenant: maintenant),
      '12 mars',
    );
  });
}
