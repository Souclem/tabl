import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

Brouillon _brouillon(String id, DateTime modifieLe, {LieuRestaurant? lieu}) =>
    Brouillon(
      id: id,
      creeLe: modifieLe,
      modifieLe: modifieLe,
      priseLe: modifieLe,
      lieu: lieu,
    );

void main() {
  final maintenant = DateTime(2026, 11, 11, 15);

  test('2 h puis 5 h après la dernière modification', () {
    final rappels = rappelsBrouillons([
      _brouillon('a', maintenant),
    ], maintenant: maintenant);

    expect(
      [for (final r in rappels) r.dans],
      [const Duration(hours: 2), const Duration(hours: 5)],
    );
    expect(
      [for (final r in rappels) r.identifiant],
      ['brouillon-a-0', 'brouillon-a-1'],
    );
    expect(rappels.first.brouillonId, 'a');
  });

  test('seuls les rappels encore à venir', () {
    final rappels = rappelsBrouillons([
      _brouillon('trois_heures', maintenant.subtract(const Duration(hours: 3))),
      _brouillon('hier', maintenant.subtract(const Duration(days: 1))),
    ], maintenant: maintenant);

    expect(rappels, hasLength(1));
    expect(rappels.single.identifiant, 'brouillon-trois_heures-1');
    expect(rappels.single.dans, const Duration(hours: 2));
  });

  test('le titre nomme le lieu quand il est choisi', () {
    expect(
      titreRappelBrouillon(
        _brouillon(
          'a',
          maintenant,
          lieu: const LieuRestaurant(nom: 'Le Comptoir', ville: 'Liège'),
        ),
      ),
      'Votre moment chez Le Comptoir',
    );
    expect(
      titreRappelBrouillon(_brouillon('a', maintenant)),
      'Votre moment vous attend',
    );
    expect(
      titreRappelBrouillon(
        _brouillon('a', maintenant, lieu: const LieuRestaurant.domicile()),
      ),
      'Votre moment chez vous',
    );
    expect(
      titreRappelBrouillon(
        _brouillon(
          'a',
          maintenant,
          lieu: const LieuRestaurant.personnel(
            nom: 'Pique-nique',
            genre: GenreLieu.ailleurs,
          ),
        ),
      ),
      'Votre moment vous attend',
    );
    expect(identifiantsRappels('a'), ['brouillon-a-0', 'brouillon-a-1']);
  });
}
