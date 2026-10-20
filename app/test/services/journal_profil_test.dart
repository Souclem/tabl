import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

const _arthur = PersonnePresente(id: 'a', pseudo: 'Arthur');
const _emma = PersonnePresente(id: 'e', pseudo: 'Emma');
const _moi = PersonnePresente(id: 'm', pseudo: 'clem', estMoi: true);

SouvenirFeed _moment(
  String id,
  DateTime date, {
  String restaurant = 'Bibo',
  String ville = 'Liège',
  String moment = 'soir',
  Emotion? emotion,
  String? photo,
  List<PersonnePresente> presents = const [],
  List<String> categories = const [],
}) => SouvenirFeed(
  id: id,
  photoUrl: photo,
  legende: null,
  restaurantNom: restaurant,
  ville: ville,
  moment: moment,
  dateVisite: date,
  auteurPseudo: 'clem',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  emotion: emotion,
  presents: presents,
  categories: categories,
  restaurantId: restaurant,
);

void main() {
  group('journal', () {
    test('années de la plus récente à la plus ancienne', () {
      expect(
        anneesDuJournal([
          _moment('1', DateTime(2025, 3, 1)),
          _moment('2', DateTime(2026, 1, 1)),
          _moment('3', DateTime(2025, 8, 1)),
        ]),
        [2026, 2025],
      );
    });

    test('une année regroupée par mois, avec qui et où', () {
      final mois = journalDeLAnnee([
        _moment('1', DateTime(2026, 10, 16), presents: [_arthur]),
        _moment('2', DateTime(2026, 9, 2)),
        _moment(
          '3',
          DateTime(2026, 10, 2),
          ville: 'Namur',
          presents: [_emma, _arthur],
        ),
        _moment('4', DateTime(2025, 10, 2)),
      ], 2026);

      expect(mois.map((m) => m.titre), ['Octobre', 'Septembre']);
      final octobre = mois.first;
      expect(octobre.compte, '2 moments');
      expect(octobre.souvenirs.map((s) => s.id), ['1', '3']);
      // Arthur, deux fois présent, passe devant Emma.
      expect(octobre.personnes.map((p) => p.pseudo), ['Arthur', 'Emma']);
      expect(octobre.recit, 'Arthur et Emma · Liège, Namur');
      expect(mois.last.recit, 'En solo · Liège');
    });

    test('le compte courant tagué se dit « Toi »', () {
      final mois = journalDeLAnnee([
        _moment('1', DateTime(2026, 10, 1), presents: [_moi, _arthur]),
      ], 2026);
      expect(mois.single.recit, 'Toi et Arthur · Liège');
    });

    test('vedette : le coup de cœur d\'un mois d\'au moins trois moments', () {
      final trois = [
        _moment('1', DateTime(2026, 10, 3)),
        _moment('2', DateTime(2026, 10, 2), emotion: Emotion.coupDeCoeur),
        _moment('3', DateTime(2026, 10, 1)),
      ];
      expect(indexVedette(trois), 1);
      expect(indexVedette(trois.sublist(0, 2)), isNull);
      expect(
        indexVedette([for (final s in trois) _moment(s.id, s.dateVisite)]),
        isNull,
      );
    });

    test('couverture : le dernier moment marquant, sinon le dernier', () {
      final souvenirs = [
        _moment('1', DateTime(2026, 10, 3), photo: 'recente'),
        _moment(
          '2',
          DateTime(2026, 9, 2),
          photo: 'marquante',
          emotion: Emotion.inoubliable,
        ),
      ];
      expect(photoCouverture(souvenirs), 'marquante');
      expect(photoCouverture([souvenirs.first]), 'recente');
      expect(photoCouverture([_moment('3', DateTime(2026))]), isNull);
    });

    test('détails d\'un moment agrandi', () {
      final s = _moment('1', DateTime(2026, 10, 16), presents: [_arthur, _moi]);
      expect(detailsMoment(s), 'Liège · 16 octobre 2026 · Dîner');
      expect(avecQuiMoment(s), 'avec Arthur et toi');
      expect(avecQuiMoment(_moment('2', DateTime(2026))), isNull);
    });
  });

  group('à deux', () {
    test('ses moments où je suis et les miens où il est, sans doublon', () {
      final duo = duoAvec(
        sesMoments: [
          _moment('1', DateTime(2026, 10, 16), presents: [_moi]),
          _moment('2', DateTime(2026, 9, 1)),
        ],
        mesMomentsAvecLui: [
          _moment('3', DateTime(2025, 3, 15), restaurant: 'Kumo'),
        ],
      )!;
      expect(duo.souvenirs.map((s) => s.id), ['1', '3']);
      expect(duo.depuis, 'À table ensemble depuis mars 2025');
      expect(
        duo.resume,
        '2 moments ensemble, dans 2 adresses. Le dernier : Bibo, le 16 '
        'octobre.',
      );
    });

    test('rien de partagé : pas de carte', () {
      expect(
        duoAvec(
          sesMoments: [_moment('1', DateTime(2026))],
          mesMomentsAvecLui: const [],
        ),
        isNull,
      );
    });
  });

  group('bilan', () {
    final tous = [
      _moment(
        '1',
        DateTime(2026, 10, 16),
        presents: [_arthur],
        categories: ['Restaurant', 'Italian Restaurant'],
      ),
      _moment(
        '2',
        DateTime(2026, 9, 18),
        restaurant: 'Kumo',
        ville: 'Bruxelles',
        moment: 'midi',
        presents: [_arthur, _emma],
        categories: ['Sushi Restaurant'],
      ),
      _moment(
        '3',
        DateTime(2026, 8, 3),
        presents: [_emma],
        categories: ['Italian Restaurant'],
      ),
      _moment('4', DateTime(2025, 11, 23)),
    ];

    test('le sien, à « tu »', () {
      final bilan = bilanDeLAnnee(tous, 2026);
      expect(bilan.titre, 'Ton 2026');
      expect(bilan.resume, '3 moments · 2 adresses · 2 villes');
      expect(bilan.titres.retours, 'Là où tu reviens');
      expect(bilan.roleBinome, 'Ton binôme de table');
      expect(bilan.binome!.nom, 'Arthur');
      expect(bilan.binome!.detail, '2 moments · 2 adresses');
      expect(bilan.autresProches.map((p) => p.nom), ['Emma']);
    });

    test('retours : deux visites dans l\'année, depuis la toute première', () {
      final retour = bilanDeLAnnee(tous, 2026).retours.single;
      expect(retour.restaurantNom, 'Bibo');
      expect(retour.nombreVisites, 2);
      expect(retour.lieu, 'Liège · depuis novembre 2025');
      expect(retour.total, '3 visites au total');
    });

    test('villes, moments et cuisines', () {
      final bilan = bilanDeLAnnee(tous, 2026);
      expect(bilan.villes.map((v) => (v.nom, v.part)), [
        ('Liège', 1.0),
        ('Bruxelles', 0.5),
      ]);
      expect(bilan.moments.map((m) => (m.libelle, m.detail)), [
        ('Dîner', '2 · 67 %'),
        ('Déjeuner', '1 · 33 %'),
      ]);
      // "Restaurant" est trop général : la catégorie suivante compte.
      expect(bilan.cuisines, ['Italien · 2', 'Sushi · 1']);
    });

    test('celui d\'un autre, à son prénom', () {
      final bilan = bilanDeLAnnee(
        [
          _moment('1', DateTime(2026, 10, 1), presents: [_moi]),
        ],
        2026,
        prenom: 'Arthur',
      );
      expect(bilan.titre, 'Le 2026 d’Arthur');
      expect(bilan.titres.avecQui, 'Avec qui Arthur partage ses tables');
      expect(bilan.roleBinome, 'Son binôme de table : toi');
      expect(bilan.binome!.nom, 'Toi');
      expect(
        bilanDeLAnnee(const [], 2026, prenom: 'Louise').titre,
        'Le 2026 de Louise',
      );
    });
  });
}
