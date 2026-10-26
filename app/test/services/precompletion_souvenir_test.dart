import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  final maintenant = DateTime(2026, 10, 26, 18);

  test('le repas commence à la première photo : jour et moment', () {
    final p = precompleter([
      MetadonneesPhoto(prisLe: DateTime(2023, 11, 3, 20, 58)),
      MetadonneesPhoto(prisLe: DateTime(2023, 11, 3, 20, 41)),
      const MetadonneesPhoto(),
    ], maintenant: maintenant);

    expect(p.date?.libelle, '3 novembre 2023');
    expect(p.moment, 'soir');
    expect(p.premierePhoto, DateTime(2023, 11, 3, 20, 41));
  });

  test('une date encore à venir (horloge fausse) n\'est pas retenue', () {
    final p = precompleter([
      MetadonneesPhoto(prisLe: DateTime(2030, 1, 1, 12)),
    ], maintenant: maintenant);

    expect(p.date, isNull);
    expect(p.moment, isNull);
  });

  test('l\'endroit : là où la plupart des photos ont été prises', () {
    // Deux au restaurant, une dans la rue avant, une chez soi après.
    final p = precompleter([
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 19, 50),
        latitude: 50.6400,
        longitude: 5.5700,
      ),
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 20, 41),
        latitude: 50.64735,
        longitude: 5.58045,
      ),
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 21, 10),
        latitude: 50.64745,
        longitude: 5.58055,
      ),
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 23, 30),
        latitude: 50.6100,
        longitude: 5.5100,
      ),
    ], maintenant: maintenant);

    expect(p.position?.latitude, closeTo(50.6474, 1e-4));
    expect(p.position?.longitude, closeTo(5.5805, 1e-4));
    // Le repas commence à la première photo du restaurant, pas de la rue.
    expect(p.premierePhoto, DateTime(2023, 11, 3, 20, 41));
  });

  test('à égalité, l\'endroit de la première photo', () {
    final p = precompleter([
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 21),
        latitude: 50.70,
        longitude: 5.60,
      ),
      MetadonneesPhoto(
        prisLe: DateTime(2023, 11, 3, 20),
        latitude: 50.60,
        longitude: 5.50,
      ),
    ], maintenant: maintenant);

    expect(p.position?.latitude, 50.60);
    // L'autre endroit n'est pas oublié : on y cherche aussi.
    expect(p.autresEndroits.single.latitude, 50.70);
    expect(p.premierePhoto, DateTime(2023, 11, 3, 20));
  });

  test('l\'endroit : le centre des photos d\'un même lieu', () {
    final p = precompleter([
      const MetadonneesPhoto(latitude: 50.6470, longitude: 5.5800),
      const MetadonneesPhoto(latitude: 50.6472, longitude: 5.5804),
      const MetadonneesPhoto(),
    ], maintenant: maintenant);

    expect(p.position?.latitude, closeTo(50.6471, 1e-9));
    expect(p.position?.longitude, closeTo(5.5802, 1e-9));
    expect(precompleter([], maintenant: maintenant).position, isNull);
  });

  test('le moment d\'après l\'heure, quand elle le dit', () {
    expect(momentDApresHeure(DateTime(2023, 1, 1, 12, 30)), 'midi');
    expect(momentDApresHeure(DateTime(2023, 1, 1, 16, 59)), 'midi');
    expect(momentDApresHeure(DateTime(2023, 1, 1, 17)), 'soir');
    expect(momentDApresHeure(DateTime(2023, 1, 1, 1, 30)), 'soir');
    expect(momentDApresHeure(DateTime(2023, 1, 1, 8)), isNull);
  });

  test('sous le nom : la distance à la photo, jamais celle du téléphone', () {
    const lieu = LieuRestaurant(
      nom: 'Como en Casa',
      ville: 'Liège',
      categories: ['Vegan and Vegetarian Restaurant'],
      distanceM: 42,
    );

    expect(
      detailLieuSouvenir(lieu, depuisLaPhoto: true),
      endsWith('Liège · à 40 m de la photo'),
    );
    expect(detailLieuSouvenir(lieu, depuisLaPhoto: false), endsWith('Liège'));
    expect(heureLisible(DateTime(2023, 1, 1, 20, 5)), '20 h 05');
    expect(
      detailLieuSouvenir(
        const LieuRestaurant.personnel(nom: 'Chez mes parents'),
        depuisLaPhoto: true,
      ),
      'Lieu personnel · jamais public',
    );
  });
}
