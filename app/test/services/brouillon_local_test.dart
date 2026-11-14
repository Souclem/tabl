import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory racine;
  late DateTime maintenant;
  late int compteur;
  late BrouillonsLocaux brouillons;

  BrouillonsLocaux ouvrir() => BrouillonsLocaux(
    racine,
    maintenant: () => maintenant,
    genererId: () => 'id${++compteur}',
  );

  final midi = DateTime(2026, 11, 8, 12, 30);
  Uint8List octets(int n) => Uint8List.fromList([n, n + 1, n + 2]);

  setUp(() {
    racine = Directory.systemTemp.createTempSync('brouillons_test');
    maintenant = DateTime(2026, 11, 8, 13);
    compteur = 0;
    brouillons = ouvrir();
  });

  tearDown(() => racine.deleteSync(recursive: true));

  group('écriture et relecture', () {
    test('une photo prise crée un brouillon relu tel quel', () async {
      final cree = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
        position: (latitude: 50.63, longitude: 5.57),
      );

      final relu = await ouvrir().charger(cree.id);
      expect(relu, isNotNull);
      expect(relu!.photos, hasLength(1));
      expect(relu.priseLe, midi);
      expect(relu.position, (latitude: 50.63, longitude: 5.57));
      expect(relu.creeLe, maintenant);
      final photo = relu.photos.single;
      expect(photo.priseLe, midi);
      expect(photo.position, (latitude: 50.63, longitude: 5.57));
      expect(
        await brouillons.fichierPhoto(relu.id, photo.id).readAsBytes(),
        octets(1),
      );
    });

    test('tous les champs survivent à une relecture', () async {
      final cree = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );
      maintenant = DateTime(2026, 11, 8, 14);
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(
          lieu: () => const LieuRestaurant(
            nom: 'Chez Zoé',
            ville: 'Liège',
            restaurantId: 'r1',
            fsqPlaceId: 'fsq1',
            adresse: 'Rue du Pont 16',
            latitude: 50.64,
            longitude: 5.58,
            categories: ['Italian Restaurant'],
            distanceM: 120,
          ),
          legende: () => 'Les pâtes',
          emotion: () => Emotion.coupDeCoeur,
          etoiles: {'cuisine': 4, 'ambiance': 3},
          avecQuiIds: {'p2', 'p1'},
          audience: const AudienceSouvenir(
            mode: ModeAudience.sauf,
            personneIds: {'p9'},
          ),
        ),
      );

      final relu = (await ouvrir().charger(cree.id))!;
      expect(relu.modifieLe, DateTime(2026, 11, 8, 14));
      expect(relu.lieu!.nom, 'Chez Zoé');
      expect(relu.lieu!.ville, 'Liège');
      expect(relu.lieu!.restaurantId, 'r1');
      expect(relu.lieu!.fsqPlaceId, 'fsq1');
      expect(relu.lieu!.adresse, 'Rue du Pont 16');
      expect(relu.lieu!.latitude, 50.64);
      expect(relu.lieu!.categories, ['Italian Restaurant']);
      expect(relu.lieu!.personnel, isFalse);
      expect(relu.legende, 'Les pâtes');
      expect(relu.emotion, Emotion.coupDeCoeur);
      expect(relu.etoiles, {'cuisine': 4, 'ambiance': 3});
      expect(relu.avecQuiIds, {'p1', 'p2'});
      expect(relu.audience.mode, ModeAudience.sauf);
      expect(relu.audience.personneIds, {'p9'});
    });

    test('un lieu personnel et un champ effacé se relisent', () async {
      final cree = await brouillons.creer();
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(
          lieu: () => const LieuRestaurant.personnel(nom: 'Chez mes parents'),
          legende: () => 'Dimanche',
        ),
      );
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(legende: () => null),
      );

      final relu = (await ouvrir().charger(cree.id))!;
      expect(relu.lieu!.personnel, isTrue);
      expect(relu.lieu!.nom, 'Chez mes parents');
      expect(relu.legende, isNull);
    });

    test('chez quelqu\'un de Tabl se relit, sans jamais de position', () async {
      final cree = await brouillons.creer();
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(
          lieu: () => const LieuRestaurant.chezQuelquun(
            hoteId: 'emma',
            hotePseudo: 'emma',
          ),
        ),
      );

      final relu = (await ouvrir().charger(cree.id))!.lieu!;
      expect(relu.genre, GenreLieu.chez);
      expect(relu.hoteId, 'emma');
      expect(relu.libelle, 'Chez emma');
    });

    test(
      'un brouillon d\'avant les genres : « personnel », sans position',
      () async {
        final cree = await brouillons.creer();
        final fichier = File(
          '${racine.path}/brouillons/${cree.id}/brouillon.json',
        );
        final json =
            jsonDecode(fichier.readAsStringSync()) as Map<String, dynamic>;
        json['lieu'] = {
          'nom': 'Chez mes parents',
          'ville': 'Liège',
          'latitude': 50.6,
          'longitude': 5.5,
          'categories': <String>[],
          'personnel': true,
        };
        fichier.writeAsStringSync(jsonEncode(json));

        final relu = (await ouvrir().charger(cree.id))!.lieu!;
        expect(relu.genre, GenreLieu.chez);
        expect(relu.nom, 'Chez mes parents');
        expect(relu.latitude, isNull);
        expect(relu.ville, '');
      },
    );

    test('un brouillon sans photo (« Sans photo ») est gardé', () async {
      final cree = await brouillons.creer();

      final relu = (await ouvrir().charger(cree.id))!;
      expect(relu.photos, isEmpty);
      expect(relu.priseLe, maintenant);
    });

    test('mettreAJour ne touche pas aux photos', () async {
      final cree = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );

      final misAJour = (await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(photos: const []),
      ))!;

      expect(misAJour.photos, hasLength(1));
    });

    test('mettreAJour sur un brouillon absent ne fait rien', () async {
      expect(await brouillons.mettreAJour('nul', (b) => b), isNull);
    });

    test('une note hors de 1 à 5 n\'est pas relue', () async {
      final cree = await brouillons.creer();
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(etoiles: {'cuisine': 4, 'service': 0, 'lieu': 9}),
      );

      expect((await ouvrir().charger(cree.id))!.etoiles, {'cuisine': 4});
    });

    test('un plat écrit est relu même sans note, dans l\'ordre', () async {
      final cree = await brouillons.creer();
      await brouillons.mettreAJour(
        cree.id,
        (b) => b.copieAvec(
          etoiles: {'plat:Risotto': 0, 'cuisine': 4, 'plat:Tiramisu': 3},
        ),
      );

      final relu = (await ouvrir().charger(cree.id))!.etoiles;
      expect(relu, {'plat:Risotto': 0, 'cuisine': 4, 'plat:Tiramisu': 3});
      expect(relu.keys.toList(), ['plat:Risotto', 'cuisine', 'plat:Tiramisu']);
    });

    test('un JSON illisible est ignoré, sans gêner les autres', () async {
      final bon = await brouillons.creer();
      final dossier = Directory('${racine.path}/brouillons/abime')
        ..createSync(recursive: true);
      File('${dossier.path}/brouillon.json').writeAsStringSync('{ pas du json');

      final liste = await ouvrir().lister();

      expect(liste.map((b) => b.id), [bon.id]);
      expect(await ouvrir().charger('abime'), isNull);
    });

    test('les écritures rapprochées ne se perdent pas', () async {
      final cree = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );

      await Future.wait([
        for (var i = 0; i < 8; i++)
          brouillons.ajouterPhoto(
            octets: octets(i),
            priseLe: midi.add(Duration(minutes: i)),
            brouillonId: cree.id,
          ),
        brouillons.mettreAJour(
          cree.id,
          (b) => b.copieAvec(legende: () => 'Pendant les prises'),
        ),
      ]);

      final relu = (await brouillons.charger(cree.id))!;
      expect(relu.photos, hasLength(9));
      expect(relu.legende, 'Pendant les prises');
    });

    test('lister : le plus récemment modifié d\'abord', () async {
      final ancien = await brouillons.creer();
      maintenant = maintenant.add(const Duration(hours: 1));
      final recent = await brouillons.creer();
      maintenant = maintenant.add(const Duration(hours: 1));
      await brouillons.mettreAJour(
        ancien.id,
        (b) => b.copieAvec(legende: () => 'Retouché'),
      );

      final liste = await brouillons.lister();

      expect(liste.map((b) => b.id), [ancien.id, recent.id]);
    });

    test('supprimerBrouillon efface le dossier et ses photos', () async {
      final cree = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );

      await brouillons.supprimerBrouillon(cree.id);

      expect(await brouillons.lister(), isEmpty);
      expect(
        brouillons.fichierPhoto(cree.id, cree.photos.single.id).existsSync(),
        isFalse,
      );
      await brouillons.supprimerBrouillon(cree.id);
    });
  });

  group('ajout des photos', () {
    test('sans brouillonId : un nouveau brouillon à chaque fois', () async {
      final premier = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );
      final second = await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi.add(const Duration(minutes: 1)),
      );

      expect(second.id, isNot(premier.id));
      expect(await brouillons.lister(), hasLength(2));
    });

    test('brouillonId : la photo s\'ajoute à la fin, quelle que soit sa '
        'date', () async {
      final premier = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );

      final suite = await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi.add(const Duration(days: 2)),
        brouillonId: premier.id,
      );

      expect(suite.id, premier.id);
      expect(suite.photos, hasLength(2));
      expect(await brouillons.lister(), hasLength(1));
    });

    test('une photo plus ancienne avance l\'heure du repas', () async {
      final premier = await brouillons.ajouterPhoto(
        octets: octets(1),
        priseLe: midi,
      );

      final suite = await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi.subtract(const Duration(hours: 1)),
        brouillonId: premier.id,
      );

      expect(suite.priseLe, midi.subtract(const Duration(hours: 1)));
      expect(suite.photos.last.priseLe, suite.priseLe);
    });

    test(
      'un brouillonId qui n\'existe plus : un nouveau, avec cet id',
      () async {
        final b = await brouillons.ajouterPhoto(
          octets: octets(1),
          priseLe: midi,
          brouillonId: 'disparu',
        );
        expect(b.id, 'disparu');
        expect(b.photos, hasLength(1));
      },
    );

    test('la position du brouillon est celle de la première prise', () async {
      final b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi.add(const Duration(minutes: 5)),
        position: (latitude: 50.6, longitude: 5.5),
        brouillonId: b.id,
      );
      final suite = await brouillons.ajouterPhoto(
        octets: octets(3),
        priseLe: midi.add(const Duration(minutes: 9)),
        position: (latitude: 1, longitude: 2),
        brouillonId: b.id,
      );

      expect(suite.position, (latitude: 50.6, longitude: 5.5));
    });
  });

  group('ordre des photos', () {
    test('reordonnerPhotos change l\'ordre, gardé à la relecture', () async {
      var b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      b = await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi,
        brouillonId: b.id,
      );
      b = await brouillons.ajouterPhoto(
        octets: octets(3),
        priseLe: midi,
        brouillonId: b.id,
      );
      final ids = b.photos.map((p) => p.id).toList();

      await brouillons.reordonnerPhotos(b.id, [ids[2], ids[0], ids[1]]);

      final relu = (await ouvrir().charger(b.id))!;
      expect(relu.photos.map((p) => p.id), [ids[2], ids[0], ids[1]]);
    });

    test('un ordre incomplet est refusé', () async {
      final b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);

      expect(
        () => brouillons.reordonnerPhotos(b.id, [b.photos.single.id, 'x']),
        throwsArgumentError,
      );
    });
  });

  group('corbeille', () {
    late Brouillon trois;

    setUp(() async {
      final b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi,
        brouillonId: b.id,
      );
      trois = await brouillons.ajouterPhoto(
        octets: octets(3),
        priseLe: midi,
        brouillonId: b.id,
      );
    });

    test(
      'supprimer une photo la met en corbeille, pas à la poubelle',
      () async {
        final retiree = trois.photos[1];

        final entree = (await brouillons.supprimerPhoto(trois.id, retiree.id))!;

        expect(entree.rang, 1);
        expect(entree.supprimeeLe, maintenant);
        expect(entree.expireLe, maintenant.add(const Duration(days: 30)));
        final relu = (await brouillons.charger(trois.id))!;
        expect(relu.photos.map((p) => p.id), [
          trois.photos[0].id,
          trois.photos[2].id,
        ]);
        expect(
          brouillons.fichierPhoto(trois.id, retiree.id).existsSync(),
          isFalse,
        );
        final corbeille = await ouvrir().listerCorbeille();
        expect(corbeille.map((e) => e.photo.id), [retiree.id]);
        expect(corbeille.single.brouillonId, trois.id);
      },
    );

    test('supprimer une photo inconnue ne fait rien', () async {
      expect(await brouillons.supprimerPhoto(trois.id, 'nul'), isNull);
      expect(await brouillons.supprimerPhoto('nul', 'nul'), isNull);
      expect(await brouillons.listerCorbeille(), isEmpty);
    });

    test('restaurer remet la photo à sa place avec son fichier', () async {
      final retiree = trois.photos[1];
      await brouillons.supprimerPhoto(trois.id, retiree.id);

      final restauree = (await brouillons.restaurerPhoto(retiree.id))!;

      expect(restauree.id, trois.id);
      expect(restauree.photos.map((p) => p.id), trois.photos.map((p) => p.id));
      expect(
        await brouillons.fichierPhoto(trois.id, retiree.id).readAsBytes(),
        octets(2),
      );
      expect(await brouillons.listerCorbeille(), isEmpty);
    });

    test('restaurer quand le brouillon n\'existe plus en crée un', () async {
      final retiree = trois.photos[0];
      await brouillons.supprimerPhoto(trois.id, retiree.id);
      await brouillons.supprimerBrouillon(trois.id);

      final restauree = (await brouillons.restaurerPhoto(retiree.id))!;

      expect(restauree.id, isNot(trois.id));
      expect(restauree.photos.map((p) => p.id), [retiree.id]);
      expect(
        await brouillons.fichierPhoto(restauree.id, retiree.id).readAsBytes(),
        octets(1),
      );
    });

    test('restaurer une photo absente de la corbeille ne fait rien', () async {
      expect(await brouillons.restaurerPhoto('nul'), isNull);
    });

    test('la plus récemment supprimée vient en premier', () async {
      await brouillons.supprimerPhoto(trois.id, trois.photos[0].id);
      maintenant = maintenant.add(const Duration(minutes: 1));
      await brouillons.supprimerPhoto(trois.id, trois.photos[2].id);

      final corbeille = await brouillons.listerCorbeille();

      expect(corbeille.map((e) => e.photo.id), [
        trois.photos[2].id,
        trois.photos[0].id,
      ]);
    });
  });

  group('purge de la corbeille', () {
    test('garde 29 jours, efface à 30 jours', () async {
      final b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      final photo = b.photos.single;
      await brouillons.supprimerPhoto(b.id, photo.id);
      final supprimeeLe = maintenant;

      maintenant = supprimeeLe.add(const Duration(days: 29, hours: 23));
      expect(await brouillons.purgerCorbeille(), 0);
      expect(await brouillons.listerCorbeille(), hasLength(1));

      maintenant = supprimeeLe.add(const Duration(days: 30));
      expect(await brouillons.purgerCorbeille(), 1);
      expect(await brouillons.listerCorbeille(), isEmpty);
      expect(await brouillons.restaurerPhoto(photo.id), isNull);
      expect(
        Directory('${racine.path}/corbeille').listSync(),
        isEmpty,
        reason: 'ni photo ni JSON ne restent',
      );
    });

    test('n\'efface que les photos échues', () async {
      var b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      b = await brouillons.ajouterPhoto(
        octets: octets(2),
        priseLe: midi,
        brouillonId: b.id,
      );
      await brouillons.supprimerPhoto(b.id, b.photos[0].id);
      maintenant = maintenant.add(const Duration(days: 20));
      await brouillons.supprimerPhoto(b.id, b.photos[1].id);

      maintenant = maintenant.add(const Duration(days: 11));

      expect(await brouillons.purgerCorbeille(), 1);
      expect((await brouillons.listerCorbeille()).map((e) => e.photo.id), [
        b.photos[1].id,
      ]);
    });

    test('sans corbeille, rien à purger', () async {
      expect(await brouillons.purgerCorbeille(), 0);
    });

    test('les brouillons ne sont jamais purgés', () async {
      final b = await brouillons.ajouterPhoto(octets: octets(1), priseLe: midi);
      maintenant = maintenant.add(const Duration(days: 90));

      await brouillons.purgerCorbeille();

      expect((await brouillons.charger(b.id))!.photos, hasLength(1));
    });
  });
}
