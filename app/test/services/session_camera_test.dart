import 'dart:io';
import 'dart:typed_data';

import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory racine;
  late DateTime maintenant;
  late int compteur;
  late BrouillonsLocaux brouillons;

  final midi = DateTime(2026, 11, 8, 12, 30);
  Uint8List octets(int n) => Uint8List.fromList([n, n + 1, n + 2]);

  SessionCamera session() =>
      SessionCamera(brouillons, maintenant: () => maintenant);

  setUp(() {
    racine = Directory.systemTemp.createTempSync('session_camera_test');
    maintenant = DateTime(2026, 11, 8, 12, 40);
    compteur = 0;
    brouillons = BrouillonsLocaux(
      racine,
      maintenant: () => maintenant,
      genererId: () => 'id${++compteur}',
    );
  });

  tearDown(() => racine.deleteSync(recursive: true));

  group('ajout', () {
    test('sans brouillon : la première photo en crée un, les suivantes '
        's\'y ajoutent', () async {
      final s = session();
      expect(s.actif, isNull);
      final a = s.ajouter(octets: octets(1), priseLe: midi);
      final b = s.ajouter(
        octets: octets(2),
        priseLe: midi.add(const Duration(seconds: 2)),
      );
      final premier = await a;
      final second = await b;
      expect(second.id, premier.id);
      expect(second.photos, hasLength(2));
      expect(await brouillons.lister(), hasLength(1));
    });

    test('sur un brouillon repris : les photos s\'ajoutent à la suite, même '
        'des heures plus tard', () async {
      final repris = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );
      final s = SessionCamera(
        brouillons,
        actif: repris,
        maintenant: () => maintenant,
      );
      final b = await s.ajouter(
        octets: octets(2),
        priseLe: midi.add(const Duration(hours: 5)),
      );
      expect(b.id, repris.id);
      expect(b.photos, hasLength(2));
      expect(await brouillons.lister(), hasLength(1));
    });

    test('la position relevée est gardée avec la photo', () async {
      final s = SessionCamera(
        brouillons,
        positionService: _PositionFixe(),
        maintenant: () => maintenant,
      );
      await s.actualiserPosition();
      final b = await s.ajouter(octets: octets(1), priseLe: midi);
      expect(b.photos.single.position, (latitude: 50.63, longitude: 5.57));
    });

    test('terminer attend les photos en cours', () async {
      final s = session();
      final enCours = s.ajouter(octets: octets(1), priseLe: midi);
      final fini = await s.terminer();
      expect(fini, isNotNull);
      expect(fini!.photos, hasLength(1));
      await enCours;
    });

    test('reordonner change l\'ordre du brouillon', () async {
      final s = session();
      await s.ajouter(octets: octets(1), priseLe: midi);
      final b = await s.ajouter(octets: octets(2), priseLe: midi);
      final ids = [for (final p in b.photos) p.id];

      final range = await s.reordonner(ids.reversed.toList());

      expect([for (final p in range!.photos) p.id], ids.reversed);
      expect(s.actif!.photos.first.id, ids.last);
      final relu = await brouillons.charger(b.id);
      expect([for (final p in relu!.photos) p.id], ids.reversed);
    });
  });

  group('import', () {
    PhotoChoisie photo(int n, DateTime? prisLe, {bool gps = false}) => (
      octets: octets(n),
      metadonnees: MetadonneesPhoto(
        prisLe: prisLe,
        latitude: gps ? 50.6 : null,
        longitude: gps ? 5.5 : null,
      ),
    );

    test('garde la date et la position, la plus ancienne d\'abord', () async {
      final s = session();
      final b = await s.ajouterImportees([
        photo(2, midi.add(const Duration(minutes: 5)), gps: true),
        photo(1, midi),
      ]);
      expect(b, isNotNull);
      expect(b!.photos.map((p) => p.priseLe), [
        midi,
        midi.add(const Duration(minutes: 5)),
      ]);
      expect(b.photos.last.position, (latitude: 50.6, longitude: 5.5));
      expect(b.photos.first.position, isNull);
    });

    test(
      'des photos de jours différents restent dans le même brouillon',
      () async {
        final s = session();
        await s.ajouterImportees([
          photo(1, midi),
          photo(2, midi.add(const Duration(days: 2))),
        ]);
        final liste = await brouillons.lister();
        expect(liste, hasLength(1));
        expect(liste.single.photos, hasLength(2));
      },
    );

    test('un deuxième import s\'ajoute aux photos déjà là, sans les '
        'remplacer', () async {
      // Le bug : trois photos importées, puis une quatrième d'un autre
      // jour, et les trois premières disparaissaient de la caméra (elles
      // partaient dans un autre brouillon).
      final s = session();
      await s.ajouterImportees([
        photo(1, midi),
        photo(2, midi.add(const Duration(minutes: 5))),
        photo(3, midi.add(const Duration(minutes: 10))),
      ]);
      final b = await s.ajouterImportees([
        photo(4, midi.subtract(const Duration(days: 3))),
      ]);

      expect(b!.photos, hasLength(4));
      expect(s.actif!.photos, hasLength(4));
      expect(await brouillons.lister(), hasLength(1));
    });

    test('rien de choisi : rien de gardé', () async {
      final s = session();
      expect(await s.ajouterImportees(const []), isNull);
      expect(await brouillons.lister(), isEmpty);
    });
  });

  group('libellés', () {
    test('compteur', () {
      expect(libelleCompteurPhotos(1), 'photo gardée');
      expect(libelleCompteurPhotos(4), 'photos gardées');
      expect(libelleCompteurPhotos(10), 'photos · le maximum publiable');
      expect(libelleCompteurPhotos(13), 'photos · retirez-en 3 pour continuer');
    });

    test('dix photos au plus pour continuer', () {
      expect(peutContinuerCamera(0), isFalse);
      expect(peutContinuerCamera(1), isTrue);
      expect(peutContinuerCamera(10), isTrue);
      expect(peutContinuerCamera(13), isFalse);
      expect(libelleTropDePhotos(13), startsWith('10 photos au maximum : '));
      expect(libelleTropDePhotos(13), contains('retirez-en 3'));
    });

    test('continuer', () => expect(libelleContinuer(3), 'Continuer · 3'));
  });
}

class _PositionFixe implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.63, longitude: 5.57);
}
