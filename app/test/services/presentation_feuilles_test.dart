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

    test('repasse au midi le même jour', () {
      final soir = DateTime(2026, 11, 8, 21);
      final midi = priseLePourMoment(soir, 'midi');
      expect(midi, DateTime(2026, 11, 8, 12, 30));
      expect(momentDuBrouillon(midi), 'midi');
    });
  });

  group('photos à publier', () {
    test('une à dix photos se publient', () {
      expect(nombrePhotosPublicable(0), isFalse);
      expect(nombrePhotosPublicable(1), isTrue);
      expect(nombrePhotosPublicable(nombreMaxPhotosSouvenir), isTrue);
      expect(nombrePhotosPublicable(nombreMaxPhotosSouvenir + 1), isFalse);
    });

    test('la première est la couverture', () {
      expect(titrePhotoMoment(0), 'Couverture');
      expect(titrePhotoMoment(1), 'Photo 2');
    });

    test('le compteur dit combien sont à publier', () {
      expect(compteurPhotosAPublier(3), '3 / 10 à publier');
    });

    test('au-delà de dix, la consigne demande d\'en retirer', () {
      expect(consignePhotos(aPublier: 10, total: 12), isNull);
      expect(
        consignePhotos(aPublier: 12, total: 12),
        'Un moment garde 10 photos au plus : retirez-en 2 de la publication.',
      );
    });

    test('toutes retirées : il faut en garder une', () {
      expect(
        consignePhotos(aPublier: 0, total: 3),
        'Gardez au moins une photo à publier.',
      );
      expect(consignePhotos(aPublier: 0, total: 0), isNull);
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
}
