import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

const _liege = ZoneCarte(sud: 50.60, ouest: 5.50, nord: 50.70, est: 5.65);

LieuCarte _lieu(
  String id,
  double lat,
  double lng, {
  int amis = 0,
  bool envie = false,
}) => LieuCarte(
  restaurantId: id,
  nom: id,
  ville: 'Liège',
  latitude: lat,
  longitude: lng,
  estEnvie: envie,
  visites: [
    for (var i = 0; i < amis; i++)
      VisiteCarte(
        souvenirId: '$id-$i',
        auteurId: 'ami$i',
        auteurPseudo: 'ami$i',
        estMoi: false,
        moment: 'soir',
        date: DateTime(2026, 10, 1),
      ),
  ],
);

void main() {
  test('plus d\'amis = plus pertinent ; l\'annuaire vaut zéro', () {
    expect(
      pertinence(_lieu('a', 0, 0, amis: 3)),
      greaterThan(pertinence(_lieu('b', 0, 0, amis: 1))),
    );
    expect(pertinence(_lieu('c', 0, 0)), 0);
  });

  test('deux lieux qui se chevauchent : seul le plus pertinent reste', () {
    final affiches = lieuxAAfficher([
      _lieu('petit', 50.6400, 5.5700, amis: 1),
      _lieu('populaire', 50.6401, 5.5701, amis: 5),
      _lieu('loin', 50.6800, 5.6200, amis: 1),
    ], _liege);
    expect(affiches.map((l) => l.nom), ['populaire', 'loin']);
  });

  test('une envie passe devant un lieu populaire au même endroit', () {
    final affiches = lieuxAAfficher([
      _lieu('populaire', 50.6402, 5.5702, amis: 9),
      _lieu('envie', 50.6400, 5.5700, envie: true),
    ], _liege);
    expect(affiches.map((l) => l.nom), ['envie']);
  });

  test('de très près, tous les restaurants de l\'annuaire s\'affichent', () {
    const rue = ZoneCarte(sud: 50.6400, ouest: 5.5700, nord: 50.6420, est: 5.5730);
    final voisins = [
      for (var i = 0; i < 12; i++) _lieu('r$i', 50.6410, 5.5710 + i * 0.00001),
    ];
    expect(lieuxAAfficher(voisins, rue, zoom: 13).length, lessThan(12));
    expect(lieuxAAfficher(voisins, rue, zoom: 17), hasLength(12));
  });

  test('hors de la zone visible : rien', () {
    expect(lieuxAAfficher([_lieu('bxl', 50.85, 4.35, amis: 9)], _liege), isEmpty);
  });

  test('jamais plus que la limite', () {
    final grille = [
      for (var i = 0; i < 30; i++)
        for (var j = 0; j < 30; j++)
          _lieu('$i-$j', 50.60 + i * 0.0033, 5.50 + j * 0.005, amis: 1),
    ];
    expect(lieuxAAfficher(grille, _liege, limite: 20), hasLength(20));
    expect(lieuxAAfficher(grille, _liege, zoom: 18, limite: 900), hasLength(900));
  });
}
