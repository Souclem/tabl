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

  test('l\'endroit : le centre des photos qui ont une position', () {
    final p = precompleter([
      const MetadonneesPhoto(latitude: 50.0, longitude: 5.0),
      const MetadonneesPhoto(latitude: 50.2, longitude: 5.4),
      const MetadonneesPhoto(),
    ], maintenant: maintenant);

    expect(p.position?.latitude, closeTo(50.1, 1e-9));
    expect(p.position?.longitude, closeTo(5.2, 1e-9));
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
  });
}
