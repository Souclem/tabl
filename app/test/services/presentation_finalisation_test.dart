import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compteurMot', () {
    test('n\'apparaît qu\'à partir de 250 caractères', () {
      expect(compteurMot(0), isNull);
      expect(compteurMot(249), isNull);
      expect(compteurMot(250), '250 / 300');
      expect(compteurMot(270), '270 / 300');
      expect(compteurMot(301), '301 / 300');
    });
  });

  group('ValidationSouvenir.mot', () {
    test('accepte jusqu\'à 300 caractères', () {
      expect(ValidationSouvenir.mot(''), isNull);
      expect(ValidationSouvenir.mot('a' * 300), isNull);
      expect(ValidationSouvenir.mot('a' * 301), '300 caractères maximum.');
    });
  });

  test('cinq catégories d\'étoiles, dans l\'ordre', () {
    expect(
      [for (final c in categoriesEtoiles) c.cle],
      ['cuisine', 'ambiance', 'service', 'lieu', 'qualite_prix'],
    );
  });

  group('repasDApresHeure', () {
    test('suit l\'heure', () {
      expect(repasDApresHeure(DateTime(2026, 8, 20, 8)), 'petit-déjeuner');
      expect(repasDApresHeure(DateTime(2026, 8, 20, 12, 30)), 'déjeuner');
      expect(repasDApresHeure(DateTime(2026, 8, 20, 16)), 'goûter');
      expect(repasDApresHeure(DateTime(2026, 8, 20, 20)), 'dîner');
      expect(repasDApresHeure(DateTime(2026, 8, 20, 2)), 'dîner');
    });
  });

  group('dates', () {
    final maintenant = DateTime(2026, 8, 20, 14);

    test('un moment en création', () {
      expect(
        dateLisibleBrouillon(
          DateTime(2026, 8, 20, 12, 30),
          maintenant: maintenant,
        ),
        'Aujourd’hui · déjeuner · 12 h 30',
      );
      expect(
        dateLisibleBrouillon(DateTime(2026, 8, 19, 20), maintenant: maintenant),
        startsWith('Hier · dîner · '),
      );
    });

    test('un moment publié : seulement midi ou soir', () {
      expect(
        dateLisibleMomentPublie(
          DateTime(2026, 8, 19),
          'soir',
          maintenant: maintenant,
        ),
        'Hier · dîner',
      );
      expect(
        dateLisibleMomentPublie(
          DateTime(2026, 8, 20),
          'midi',
          maintenant: maintenant,
        ),
        'Aujourd’hui · déjeuner',
      );
    });
  });

  group('etapeFinalisation', () {
    EtapeFinalisation etape({
      bool modification = false,
      bool photos = true,
      bool lieu = true,
    }) => etapeFinalisation(
      modification: modification,
      aDesPhotos: photos,
      aUnLieu: lieu,
    );

    test('photos d\'abord, puis le lieu, puis publier', () {
      expect(
        etape(photos: false, lieu: false),
        EtapeFinalisation.choisirPhotos,
      );
      expect(etape(photos: false), EtapeFinalisation.choisirPhotos);
      expect(etape(lieu: false), EtapeFinalisation.choisirLieu);
      expect(etape(), EtapeFinalisation.publier);
    });

    test('en modification : enregistrer', () {
      expect(etape(modification: true), EtapeFinalisation.enregistrer);
      expect(
        etape(modification: true, photos: false, lieu: false),
        EtapeFinalisation.enregistrer,
      );
    });

    test('seules publier et enregistrer exigent l\'émotion', () {
      expect(EtapeFinalisation.choisirPhotos.exigeEmotion, isFalse);
      expect(EtapeFinalisation.choisirLieu.exigeEmotion, isFalse);
      expect(EtapeFinalisation.publier.exigeEmotion, isTrue);
      expect(EtapeFinalisation.enregistrer.exigeEmotion, isTrue);
    });

    test('libellés', () {
      expect(EtapeFinalisation.choisirPhotos.libelle, 'Choisir les photos');
      expect(EtapeFinalisation.choisirLieu.libelle, 'Où étiez-vous ?');
      expect(EtapeFinalisation.publier.libelle, 'Publier');
    });
  });
}
