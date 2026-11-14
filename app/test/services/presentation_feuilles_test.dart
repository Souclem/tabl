import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

ProfilPublic _personne(String id, String pseudo) =>
    ProfilPublic(id: id, pseudo: pseudo, statut: StatutAbonnement.abonne);

void main() {
  group('priseLePourMoment', () {
    test('garde l\'heure quand la prise est déjà de ce moment', () {
      final midi = DateTime(2026, 11, 8, 12, 10);
      expect(priseLePourMoment(midi, 'midi'), midi);
    });

    test('passe au soir à l\'heure habituelle du repas', () {
      final midi = DateTime(2026, 11, 8, 12, 10);
      expect(priseLePourMoment(midi, 'soir'), DateTime(2026, 11, 8, 20));
      expect(momentDuBrouillon(priseLePourMoment(midi, 'soir')), 'soir');
    });

    test('passe au petit-déjeuner à 8 h 30, le même jour', () {
      final soir = DateTime(2026, 11, 8, 21);
      final matin = priseLePourMoment(soir, 'matin');
      expect(matin, DateTime(2026, 11, 8, 8, 30));
      expect(momentDuBrouillon(matin), 'matin');
    });

    test('repasse au midi le même jour', () {
      final soir = DateTime(2026, 11, 8, 21);
      final midi = priseLePourMoment(soir, 'midi');
      expect(midi, DateTime(2026, 11, 8, 12, 30));
      expect(momentDuBrouillon(midi), 'midi');
    });
  });

  group('filtrerPersonnes', () {
    final gens = [_personne('1', 'Zoé'), _personne('2', 'Clément')];

    test('vide : tout le monde', () {
      expect(filtrerPersonnes(gens, '  '), gens);
    });

    test('sans accent ni casse', () {
      expect(filtrerPersonnes(gens, 'ZOE').map((p) => p.id), ['1']);
      expect(filtrerPersonnes(gens, 'clem').map((p) => p.id), ['2']);
      expect(filtrerPersonnes(gens, 'xyz'), isEmpty);
    });
  });

  group('personnesChezQui', () {
    ProfilPublic p(String id) =>
        ProfilPublic(id: id, pseudo: id, statut: StatutAbonnement.abonne);
    final suivis = [
      p('zoe'),
      p('emma'),
      p('léa'),
      p('martin'),
      p('ana'),
      p('bob'),
    ];

    test(
      'ceux qui étaient à table d\'abord, puis par pseudo, cinq au plus',
      () {
        expect(
          [
            for (final x in personnesChezQui(
              suivis,
              prioritairesIds: {'zoe'},
              max: 5,
            ))
              x.id,
          ],
          ['zoe', 'ana', 'bob', 'emma', 'léa'],
        );
      },
    );

    test('celle déjà choisie reste là, même au-delà de cinq', () {
      expect(
        [
          for (final x in personnesChezQui(suivis, choisieId: 'zoe', max: 5))
            x.id,
        ],
        ['ana', 'bob', 'emma', 'léa', 'martin', 'zoe'],
      );
    });

    test('sans maximum : toutes, celles d\'abord à table', () {
      expect(
        [
          for (final x in personnesChezQui(suivis, prioritairesIds: {'zoe'}))
            x.id,
        ],
        ['zoe', 'ana', 'bob', 'emma', 'léa', 'martin'],
      );
    });

    test('la recherche montre toutes celles qui correspondent', () {
      expect(
        [for (final x in personnesChezQui(suivis, recherche: 'LE')) x.id],
        ['léa'],
      );
    });
  });
}
