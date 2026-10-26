import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

LieuCarte _lieu(
  String nom, {
  int amis = 1,
  int revenants = 0,
  int coupsDeCoeur = 0,
  List<String> ressentis = const [],
  List<String> visages = const ['Emma'],
  DateTime? derniere,
  String ville = 'Liège',
  double latitude = 50.64,
  double longitude = 5.57,
}) => LieuCarte(
  restaurantId: nom,
  nom: nom,
  ville: ville,
  latitude: latitude,
  longitude: longitude,
  amis: amis,
  visites: amis + revenants,
  coupsDeCoeur: coupsDeCoeur,
  amisQuiReviennent: revenants,
  ressentis: ressentis,
  derniereVisite: derniere,
  visages: [for (final v in visages) (pseudo: v, photoUrl: null)],
);

void main() {
  final maintenant = DateTime(2026, 10, 27, 12);

  test('la note sur 5 vient des ressentis, calculée par l\'app', () {
    expect(noteSurCinq(['😍', '🙂']), 4.25);
    expect(noteSurCinq(['🤩']), 5);
    expect(noteSurCinq([]), isNull);
    expect(noteSurCinq(['?']), isNull);
    expect(noteLisible(4.25), '4,3');
  });

  test('« il y a » : jours, semaines, mois, années', () {
    expect(ilYA(DateTime(2026, 10, 27), maintenant), 'aujourd\'hui');
    expect(ilYA(DateTime(2026, 10, 26), maintenant), 'hier');
    expect(ilYA(DateTime(2026, 10, 24), maintenant), 'il y a 3 jours');
    expect(ilYA(DateTime(2026, 10, 6), maintenant), 'il y a 3 semaines');
    expect(ilYA(DateTime(2026, 6, 27), maintenant), 'il y a 4 mois');
    expect(ilYA(DateTime(2024, 10, 1), maintenant), 'il y a 2 ans');
  });

  test('qui la connaît : un, deux, ou deux et les autres', () {
    expect(quiLaConnait(_lieu('A')), 'Emma la connaît');
    expect(
      quiLaConnait(_lieu('A', amis: 2, visages: ['Emma', 'Martin'])),
      'Emma et Martin la connaissent',
    );
    expect(
      quiLaConnait(_lieu('A', amis: 5, visages: ['Emma', 'Martin', 'Louise'])),
      'Emma, Martin +3 la connaissent',
    );
  });

  test('le signal doré : le cercle revient, puis les coups de cœur', () {
    expect(
      signalLieu(_lieu('A', revenants: 3), maintenant),
      '3 de vos proches y retournent',
    );
    expect(
      signalLieu(_lieu('A', revenants: 1), maintenant),
      'Votre cercle revient ici',
    );
    expect(
      signalLieu(_lieu('A', coupsDeCoeur: 1), maintenant),
      'Un coup de cœur dans votre cercle',
    );
    expect(
      signalLieu(_lieu('A', derniere: DateTime(2026, 10, 24)), maintenant),
      'Dernière visite il y a 3 jours',
    );
    expect(
      signalLieu(_lieu('A', derniere: DateTime(2026, 1, 1)), maintenant),
      isNull,
    );
  });

  test('les tris', () {
    final lieux = [
      _lieu('Ancien', derniere: DateTime(2026, 1, 1), amis: 5),
      _lieu('Récent', derniere: DateTime(2026, 10, 1), ressentis: ['😐']),
      _lieu('Fidèle', revenants: 2, ressentis: ['😍', '😍']),
      _lieu('Loin', latitude: 48.86, longitude: 2.35),
    ];
    String premier(TriCercle tri) => trierLieux(
      lieux,
      tri,
      position: (latitude: 48.85, longitude: 2.34),
    ).first.nom;

    expect(premier(TriCercle.recents), 'Récent');
    expect(premier(TriCercle.ilsYRetournent), 'Fidèle');
    expect(premier(TriCercle.mieuxNotes), 'Fidèle');
    expect(premier(TriCercle.plusProches), 'Loin');
    expect(premier(TriCercle.plusConnus), 'Ancien');
  });

  test('la raison d\'une place dans la liste, selon le tri', () {
    final lieu = _lieu(
      'A',
      amis: 4,
      revenants: 2,
      ressentis: ['😍', '🙂'],
      derniere: DateTime(2026, 10, 26),
    );
    expect(
      ligneSelonTri(lieu, TriCercle.recents, maintenant: maintenant),
      'Dernière visite hier',
    );
    expect(
      ligneSelonTri(lieu, TriCercle.ilsYRetournent, maintenant: maintenant),
      '2 proches y retournent',
    );
    expect(
      ligneSelonTri(lieu, TriCercle.mieuxNotes, maintenant: maintenant),
      '4,3 · 2 avis',
    );
    expect(
      ligneSelonTri(
        lieu,
        TriCercle.plusProches,
        maintenant: maintenant,
        distanceM: 720,
      ),
      '9 min à pied',
    );
    expect(
      ligneSelonTri(lieu, TriCercle.plusConnus, maintenant: maintenant),
      '4 proches connaissent cette adresse',
    );
  });

  test('les villes du cercle, et celle qu\'on regarde', () {
    final villes = villesDuCercle([
      _lieu('A'),
      _lieu('B', ville: 'liège'),
      _lieu('C', ville: 'Paris', latitude: 48.86, longitude: 2.35),
      _lieu('D', ville: ''),
    ]);

    expect(
      [for (final v in villes) (v.nom, v.compte)],
      [('Liège', 2), ('Paris', 1)],
    );
    expect(villeRegardee(villes, 50.63, 5.58)?.nom, 'Liège');
    expect(villeRegardee(villes, 45.0, 10.0), isNull);
  });

  test('à pied jusqu\'à 2 km, en kilomètres ensuite', () {
    expect(distanceAPied(60), '1 min à pied');
    expect(distanceAPied(1500), '19 min à pied');
    expect(distanceAPied(3400), '3,4 km');
  });

  test('la période : jusqu\'où remonter', () {
    expect(PeriodeCarte.troisMois.depuis(maintenant), DateTime(2026, 7, 27));
    expect(PeriodeCarte.unAn.depuis(maintenant), DateTime(2025, 10, 27));
    expect(PeriodeCarte.tout.depuis(maintenant), isNull);
  });
}
