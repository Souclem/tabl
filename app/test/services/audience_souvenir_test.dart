import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

const _prive = ContexteAudience(
  profilPrive: true,
  abonnesIds: {'emma', 'thomas', 'maman'},
  membresParTable: {
    'marbella': {'emma', 'lucas'},
  },
);

const _public = ContexteAudience(
  profilPrive: false,
  abonnesIds: {'emma'},
  membresParTable: {},
);

void main() {
  group('profil privé', () {
    test('"Tout le monde" = les abonnés', () {
      expect(
        _prive.libellePortee(AudienceSouvenir.toutLeMonde),
        'Visible par 3 personnes',
      );
    });

    test('"Seulement…" réunit Tables et personnes, sans doublon', () {
      const audience = AudienceSouvenir(
        mode: ModeAudience.seulement,
        tableIds: {'marbella'},
        personneIds: {'emma', 'thomas'},
      );
      expect(_prive.personnesVisibles(audience), {'emma', 'lucas', 'thomas'});
    });

    test('"Tout le monde sauf…" retire les exclus des abonnés', () {
      const audience = AudienceSouvenir(
        mode: ModeAudience.sauf,
        personneIds: {'maman'},
      );
      expect(_prive.libellePortee(audience), 'Visible par 2 personnes');
    });

    test('ami tagué non abonné : hors audience en "Tout le monde"', () {
      expect(
        _prive.taguesHorsAudience(AudienceSouvenir.toutLeMonde, {
          'emma',
          'sarah',
        }),
        {'sarah'},
      );
    });

    test('ami tagué exclu : hors audience', () {
      const audience = AudienceSouvenir(
        mode: ModeAudience.sauf,
        personneIds: {'emma'},
      );
      expect(_prive.taguesHorsAudience(audience, {'emma'}), {'emma'});
    });
  });

  group('profil public', () {
    test('"Tout le monde" = tous les utilisateurs, pas un nombre', () {
      expect(_public.personnesVisibles(AudienceSouvenir.toutLeMonde), isNull);
      expect(
        _public.libellePortee(AudienceSouvenir.toutLeMonde),
        'Visible par tous les utilisateurs de Tabl',
      );
    });

    test('un ami tagué n\'est hors audience que s\'il est exclu', () {
      const audience = AudienceSouvenir(
        mode: ModeAudience.sauf,
        personneIds: {'emma'},
      );
      expect(_public.taguesHorsAudience(audience, {'emma', 'sarah'}), {
        'emma',
      });
      expect(
        _public.libellePortee(audience),
        'Visible par tous les utilisateurs de Tabl, sauf 1 personne',
      );
    });
  });

  test('"Seulement…" vide est invalide, les autres modes toujours valides', () {
    expect(const AudienceSouvenir(mode: ModeAudience.seulement).estValide, isFalse);
    expect(const AudienceSouvenir(mode: ModeAudience.sauf).estValide, isTrue);
  });

  test('normalisée : vide ce qui ne compte pas pour le mode', () {
    const audience = AudienceSouvenir(
      mode: ModeAudience.sauf,
      tableIds: {'marbella'},
      personneIds: {'maman'},
    );
    final normalisee = audience.normalisee();
    expect(normalisee.tableIds, isEmpty);
    expect(normalisee.personneIds, {'maman'});
  });

  test('libellé court', () {
    const audience = AudienceSouvenir(
      mode: ModeAudience.seulement,
      tableIds: {'marbella'},
      personneIds: {'emma', 'thomas'},
    );
    expect(
      libelleAudience(
        audience,
        nomsTables: {'marbella': 'Marbella'},
        pseudos: {'emma': 'Emma', 'thomas': 'Thomas'},
      ),
      'Seulement Marbella, Emma +1',
    );
  });
}
