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

  group('ouverture', () {
    test('sans brouillon : rien à reprendre ni à rejoindre', () async {
      final ouverture = await session().ouvrir();
      expect(ouverture.actif, isNull);
      expect(ouverture.aRejoindre, isNull);
      expect(ouverture.reprise, isFalse);
    });

    test(
      'retour avant 10 min : suite du repas, sans carte de reprise',
      () async {
        maintenant = midi;
        await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
        maintenant = midi.add(const Duration(minutes: 9));
        final ouverture = await session().ouvrir();
        expect(ouverture.actif, isNotNull);
        expect(ouverture.reprise, isFalse);
      },
    );

    test('retour à 10 min ou plus : carte de reprise', () async {
      maintenant = midi;
      await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      maintenant = midi.add(delaiCarteReprise);
      final ouverture = await session().ouvrir();
      expect(ouverture.actif, isNotNull);
      expect(ouverture.reprise, isTrue);
    });

    test('brouillon de 3 h ou plus : à rejoindre, pas actif', () async {
      maintenant = midi;
      await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      maintenant = midi.add(const Duration(hours: 4));
      final s = session();
      final ouverture = await s.ouvrir();
      expect(ouverture.actif, isNull);
      expect(ouverture.aRejoindre, isNotNull);
      expect(ouverture.reprise, isFalse);

      s.rejoindre();
      expect(s.actif?.id, ouverture.aRejoindre!.id);
      expect(s.aRejoindre, isNull);
    });
  });

  group('ajout', () {
    test('deux photos rapprochées partagent un brouillon', () async {
      final s = session();
      await s.ouvrir();
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

    test('« Autre repas » commence un nouveau brouillon', () async {
      final s = session();
      await s.ouvrir();
      final premier = await s.ajouter(octets: octets(1), priseLe: midi);
      s.autreRepas();
      final second = await s.ajouter(
        octets: octets(2),
        priseLe: midi.add(const Duration(minutes: 1)),
      );
      expect(second.id, isNot(premier.id));
      expect(await brouillons.lister(), hasLength(2));
    });

    test('la position relevée est gardée avec la photo', () async {
      final s = SessionCamera(
        brouillons,
        positionService: _PositionFixe(),
        maintenant: () => maintenant,
      );
      await s.ouvrir();
      await s.actualiserPosition();
      final b = await s.ajouter(octets: octets(1), priseLe: midi);
      expect(b.photos.single.position, (latitude: 50.63, longitude: 5.57));
    });

    test('terminer attend les photos en cours', () async {
      final s = session();
      await s.ouvrir();
      final enCours = s.ajouter(octets: octets(1), priseLe: midi);
      final fini = await s.terminer();
      expect(fini, isNotNull);
      expect(fini!.photos, hasLength(1));
      await enCours;
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
      await s.ouvrir();
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

    test('une photo d\'un autre repas commence un nouveau brouillon', () async {
      final s = session();
      await s.ouvrir();
      await s.ajouterImportees([
        photo(1, midi),
        photo(2, midi.add(const Duration(hours: 5))),
      ]);
      expect(await brouillons.lister(), hasLength(2));
    });

    test('rien de choisi : rien de gardé', () async {
      final s = session();
      await s.ouvrir();
      expect(await s.ajouterImportees(const []), isNull);
      expect(await brouillons.lister(), isEmpty);
    });
  });

  group('libellés', () {
    test('compteur', () {
      expect(libelleCompteurPhotos(1), 'photo gardée');
      expect(libelleCompteurPhotos(4), 'photos gardées');
      expect(libelleCompteurPhotos(10), 'photos · le maximum publiable');
      expect(libelleCompteurPhotos(12), contains('10'));
    });

    test('continuer', () => expect(libelleContinuer(3), 'Continuer · 3'));
  });
}

class _PositionFixe implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.63, longitude: 5.57);
}
