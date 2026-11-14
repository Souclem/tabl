import 'dart:typed_data';

import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'depot_publication_simule.dart';

Uint8List _octets(int n) => Uint8List.fromList([n, n + 1, n + 2]);

/// Un JPEG minimal portant un segment EXIF (APP1) que l'envoi doit retirer.
Uint8List _jpegAvecExif() => Uint8List.fromList([
  0xFF, 0xD8, //
  0xFF, 0xE1, 0x00, 0x08, 0x45, 0x78, 0x69, 0x66, 0x00, 0x00, // Exif
  0xFF, 0xDB, 0x00, 0x04, 0x00, 0x00, //
  0xFF, 0xDA, 0x00, 0x04, 0x00, 0x00, 0x01, 0x02, 0x03, //
  0xFF, 0xD9,
]);

DemandePublication _demande({
  String id = 'moment-1',
  int photos = 3,
  Map<String, int> etoiles = const {},
  AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
  List<Uint8List>? octets,
  Set<String> amis = const {'ami-1'},
}) => DemandePublication(
  id: id,
  lieu: const LieuRestaurant(nom: 'Chez Marcel', ville: 'Liège'),
  photos: octets ?? [for (var i = 0; i < photos; i++) _octets(i * 10)],
  emotion: Emotion.coupDeCoeur,
  priseLe: DateTime(2026, 11, 8, 12, 30),
  legende: 'Une belle table',
  etoiles: etoiles,
  amisTaguesIds: amis,
  audience: audience,
  empreintes: const ['abc', 'abc', 'def'],
);

AudienceSouvenir _audienceTables(Set<String> ids) =>
    AudienceSouvenir(mode: ModeAudience.seulement, tableIds: ids);

void main() {
  late DepotPublicationSimule depot;
  late PublicationEnDeuxTemps service;

  setUp(() {
    depot = DepotPublicationSimule();
    service = PublicationEnDeuxTemps(depot);
  });

  group('succès', () {
    test('préparer écrit un brouillon invisible, valider le publie', () async {
      final prepare = await service.preparer(_demande());

      expect(prepare.id, 'moment-1');
      expect(prepare.dejaPublie, isFalse);
      expect(prepare.tablesEnEchec, isEmpty);
      expect(depot.lignes['moment-1']!['statut'], statutBrouillon);
      expect(depot.lignes['moment-1']!['auteur_id'], 'auteur-1');
      expect(depot.appels, isNot(contains('commit')));

      await service.valider('moment-1');
      expect(depot.lignes['moment-1']!['statut'], statutPublie);
    });

    test('l\'id de la demande est celui de la ligne et des fichiers', () async {
      await service.preparer(_demande());

      expect(depot.fichiers.keys, {
        'auteur-1/moment-1-0.jpg',
        'auteur-1/moment-1-1.jpg',
        'auteur-1/moment-1-2.jpg',
      });
      final ligne = depot.lignes['moment-1']!;
      expect(ligne['photo_url'], 'auteur-1/moment-1-0.jpg');
      expect(depot.liens['photos'], {
        'auteur-1/moment-1-1.jpg',
        'auteur-1/moment-1-2.jpg',
      });
    });

    test(
      'les colonnes du moment : lieu, émotion, date, moment, légende',
      () async {
        await service.preparer(_demande());

        final ligne = depot.lignes['moment-1']!;
        expect(ligne['restaurant_id'], 'resto-1');
        expect(ligne['emotion'], Emotion.coupDeCoeur.emoji);
        expect(ligne['legende'], 'Une belle table');
        expect(ligne['moment'], 'midi');
        expect(ligne['date_visite'], '2026-11-08');
        expect(ligne['visibilite'], ModeAudience.toutLeMonde.valeur);
        expect(depot.liens['amis'], {'ami-1'});
        expect(depot.liens['empreintes'], {'abc', 'def'});
      },
    );

    test(
      'les étoiles s\'écrivent dans notes, sans les notes invalides',
      () async {
        await service.preparer(
          _demande(
            etoiles: const {
              'cuisine': 4,
              'ambiance': 3,
              'service': 0,
              'lieu': 6,
              'inconnue': 5,
            },
          ),
        );

        expect(depot.lignes['moment-1']!['notes'], {
          'cuisine': 4,
          'ambiance': 3,
        });
      },
    );

    test('sans étoile, notes est vide (null)', () async {
      await service.preparer(_demande());

      expect(depot.lignes['moment-1']!['notes'], isNull);
    });

    test('les photos passent par sansMetadonnees avant l\'envoi', () async {
      final original = _jpegAvecExif();
      await service.preparer(_demande(octets: [original]));

      final envoye = depot.fichiers['auteur-1/moment-1-0.jpg']!;
      expect(envoye, sansMetadonnees(original));
      expect(envoye.length, lessThan(original.length));
    });

    test('un moment sans photo est accepté', () async {
      final prepare = await service.preparer(_demande(photos: 0));

      expect(prepare.id, 'moment-1');
      expect(depot.lignes['moment-1']!['photo_url'], isNull);
      expect(depot.fichiers, isEmpty);
    });

    test('au plus dix photos', () async {
      expect(() => service.preparer(_demande(photos: 11)), throwsArgumentError);
      expect(depot.lignes, isEmpty);
    });

    test('les Tables dont l\'association échoue sont rendues', () async {
      depot.tablesRefusees = {'table-2'};

      final prepare = await service.preparer(
        _demande(
          audience: const AudienceSouvenir(
            mode: ModeAudience.seulement,
            tableIds: {'table-1', 'table-2'},
          ),
        ),
      );

      expect(prepare.tablesEnEchec, ['table-2']);
      expect(depot.tables['moment-1'], {'table-1'});
      expect(depot.lignes['moment-1']!['statut'], statutBrouillon);
    });
  });

  group('progression', () {
    test('0 au départ puis une fois par photo envoyée, sur le total', () async {
      final vues = <(int, int)>[];

      await service.preparer(
        _demande(photos: 4),
        surProgression: (envoyees, total) => vues.add((envoyees, total)),
      );

      expect(vues, [(0, 4), (1, 4), (2, 4), (3, 4), (4, 4)]);
    });

    test('un moment sans photo ne signale que 0 sur 0', () async {
      final vues = <(int, int)>[];

      await service.preparer(
        _demande(photos: 0),
        surProgression: (envoyees, total) => vues.add((envoyees, total)),
      );

      expect(vues, [(0, 0)]);
    });

    test('les photos envoyées avant une panne restent comptées', () async {
      depot.echecAuRang = 2;
      final vues = <(int, int)>[];

      await expectLater(
        service.preparer(
          _demande(),
          surProgression: (envoyees, total) => vues.add((envoyees, total)),
        ),
        throwsStateError,
      );

      expect(vues.last, (2, 3));
      expect(depot.lignes, isEmpty);
    });
  });

  group('échec au commit', () {
    test('rien n\'est publié : le brouillon reste, invisible', () async {
      await service.preparer(_demande());
      depot.echecAuCommit = true;

      await expectLater(service.valider('moment-1'), throwsStateError);

      expect(depot.lignes['moment-1']!['statut'], statutBrouillon);
      expect(depot.fichiers, hasLength(3));
    });

    test('« Réessayer » : valider rejoué publie, sans rien renvoyer', () async {
      await service.preparer(_demande());
      depot.echecAuCommit = true;
      await expectLater(service.valider('moment-1'), throwsStateError);
      depot.echecAuCommit = false;
      depot.appels.clear();

      await service.valider('moment-1');

      expect(depot.lignes['moment-1']!['statut'], statutPublie);
      expect(depot.appels, ['commit']);
    });

    test('« Garder » : après l\'échec, on peut encore abandonner', () async {
      await service.preparer(_demande());
      depot.echecAuCommit = true;
      await expectLater(service.valider('moment-1'), throwsStateError);

      await service.abandonner('moment-1');

      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
    });

    test('valider un moment disparu le dit', () async {
      expect(service.valider('inconnu'), throwsA(isA<MomentIntrouvable>()));
    });
  });

  group('annulation avant commit', () {
    test('la ligne puis les photos sont supprimées', () async {
      await service.preparer(_demande());
      depot.appels.clear();

      await service.abandonner('moment-1');

      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
      expect(depot.appels, ['suppression ligne', 'suppression fichiers']);
    });

    test('ne touche ni aux photos d\'un autre moment', () async {
      await service.preparer(_demande(id: 'autre'));
      await service.preparer(_demande());

      await service.abandonner('moment-1');

      expect(depot.lignes.keys, ['autre']);
      expect(depot.fichiers.keys, everyElement(startsWith('auteur-1/autre-')));
      expect(depot.fichiers, hasLength(3));
    });

    test(
      'après une panne en pleine envoi, les photos orphelines partent',
      () async {
        depot.echecAuRang = 2;
        await expectLater(service.preparer(_demande()), throwsStateError);
        expect(depot.fichiers, isNotEmpty);

        await service.abandonner('moment-1');

        expect(depot.fichiers, isEmpty);
      },
    );

    test('abandonner rejoué, ou sans rien envoyé, est sans effet', () async {
      await service.abandonner('moment-1');
      await service.preparer(_demande());
      await service.abandonner('moment-1');
      await service.abandonner('moment-1');

      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
    });

    test('un moment déjà publié ne s\'abandonne plus', () async {
      await service.preparer(_demande());
      await service.valider('moment-1');

      await expectLater(
        service.abandonner('moment-1'),
        throwsA(isA<MomentDejaPublie>()),
      );

      expect(depot.lignes['moment-1']!['statut'], statutPublie);
      expect(depot.fichiers, hasLength(3));
    });

    test('publié entre la lecture du statut et la suppression : '
        'la ligne et les fichiers restent', () async {
      await service.preparer(_demande());
      depot.avantSuppressionLigne = () =>
          depot.lignes['moment-1']!['statut'] = statutPublie;

      await expectLater(
        service.abandonner('moment-1'),
        throwsA(isA<MomentDejaPublie>()),
      );

      expect(depot.lignes['moment-1']!['statut'], statutPublie);
      expect(depot.fichiers, hasLength(3));
      expect(depot.appels, isNot(contains('suppression fichiers')));
    });

    test('valider après abandon lève MomentIntrouvable', () async {
      await service.preparer(_demande());
      await service.abandonner('moment-1');

      await expectLater(
        service.valider('moment-1'),
        throwsA(isA<MomentIntrouvable>()),
      );
      expect(depot.lignes, isEmpty);
    });
  });

  group('relance idempotente', () {
    test(
      'une coupure en pleine envoi : la relance finit sans doublon',
      () async {
        depot.echecAuRang = 2;
        await expectLater(service.preparer(_demande()), throwsStateError);
        depot.echecAuRang = null;

        final prepare = await service.preparer(_demande());
        await service.valider(prepare.id);

        expect(depot.lignes, hasLength(1));
        expect(depot.lignes['moment-1']!['statut'], statutPublie);
        expect(depot.fichiers, hasLength(3));
      },
    );

    test(
      'préparer rejoué sur un brouillon le met à jour, sans 2e ligne',
      () async {
        await service.preparer(_demande());

        await service.preparer(_demande(etoiles: const {'cuisine': 5}));

        expect(depot.lignes, hasLength(1));
        expect(depot.appels.where((a) => a == 'creer'), hasLength(1));
        expect(depot.appels.where((a) => a == 'maj'), hasLength(1));
        expect(depot.lignes['moment-1']!['notes'], {'cuisine': 5});
        expect(depot.fichiers, hasLength(3));
        expect(depot.liens['empreintes'], {'abc', 'def'});
      },
    );

    test(
      'une relance qui retire Table, ami et photos ne laisse que la demande',
      () async {
        await service.preparer(
          _demande(audience: _audienceTables({'table-x', 'table-y'})),
        );
        expect(depot.tables['moment-1'], {'table-x', 'table-y'});

        await service.preparer(
          _demande(
            photos: 1,
            octets: [_octets(99)],
            audience: _audienceTables({'table-y'}),
            amis: const {},
          ),
        );

        expect(depot.tables['moment-1'], {'table-y'});
        expect(depot.liens['amis'], isEmpty);
        expect(depot.liens['photos'], isEmpty);
        expect(depot.fichiers.keys, {'auteur-1/moment-1-0.jpg'});
        expect(
          depot.lignes['moment-1']!['photo_url'],
          'auteur-1/moment-1-0.jpg',
        );
      },
    );

    test(
      'une relance qui remplace une photo envoie le nouveau contenu',
      () async {
        await service.preparer(_demande(photos: 2));
        final nouvelles = [_octets(200), _octets(210)];

        await service.preparer(_demande(octets: nouvelles));

        expect(depot.fichiers['auteur-1/moment-1-0.jpg'], nouvelles[0]);
        expect(depot.fichiers['auteur-1/moment-1-1.jpg'], nouvelles[1]);
      },
    );

    test('une relance après une coupure en plein envoi, photos changées, '
        'ne garde pas les anciens fichiers', () async {
      depot.echecAuRang = 1;
      await expectLater(
        service.preparer(_demande(photos: 2)),
        throwsStateError,
      );
      depot.echecAuRang = null;
      final nouvelles = [_octets(200), _octets(210)];

      await service.preparer(_demande(octets: nouvelles));

      expect(depot.fichiers['auteur-1/moment-1-0.jpg'], nouvelles[0]);
      expect(depot.fichiers['auteur-1/moment-1-1.jpg'], nouvelles[1]);
    });

    test(
      'ne touche pas aux fichiers ni aux liens d\'un autre moment',
      () async {
        await service.preparer(_demande(id: 'moment-2'));

        await service.preparer(_demande());

        expect(depot.fichiers, hasLength(6));
        expect(depot.tables.containsKey('moment-2'), isTrue);
      },
    );

    test('un autre id est un autre moment', () async {
      await service.preparer(_demande());
      await service.preparer(_demande(id: 'moment-2'));

      expect(depot.lignes.keys, {'moment-1', 'moment-2'});
      expect(depot.fichiers, hasLength(6));
    });

    test('après le commit, préparer rejoué ne renvoie rien', () async {
      await service.preparer(_demande());
      await service.valider('moment-1');
      depot.appels.clear();

      final prepare = await service.preparer(_demande());

      expect(prepare.dejaPublie, isTrue);
      expect(depot.appels, isEmpty);
      expect(depot.lignes['moment-1']!['statut'], statutPublie);
    });

    test('valider rejoué est sans effet', () async {
      await service.preparer(_demande());
      await service.valider('moment-1');
      await service.valider('moment-1');

      expect(depot.lignes['moment-1']!['statut'], statutPublie);
    });

    test('le nom des fichiers ne dépend que de l\'id et du rang', () {
      expect(cheminPhotoMoment('u', 'm', 3), 'u/m-3.jpg');
    });
  });
}
