import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

SouvenirFeed _moment(
  String id,
  String auteur,
  DateTime date, {
  Emotion? emotion,
  bool moi = false,
}) => SouvenirFeed(
  id: id,
  photoUrl: id == '1' ? 'photo-1' : null,
  legende: null,
  restaurantNom: 'Bibo',
  ville: 'Liège',
  moment: 'soir',
  dateVisite: date,
  auteurPseudo: auteur,
  auteurId: auteur,
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  emotion: emotion,
  estAMoi: moi,
);

void main() {
  test('le résumé d\'une fiche', () {
    final r = resumerFiche([
      _moment('4', 'moi', DateTime(2026, 8, 21), moi: true),
      _moment('3', 'Emma', DateTime(2026, 6, 1), emotion: Emotion.coupDeCoeur),
      _moment('2', 'Emma', DateTime(2025, 3, 1), emotion: Emotion.coupDeCoeur),
      _moment('1', 'Thomas', DateTime(2023, 5, 1), emotion: Emotion.neutre),
    ]);

    expect(r.note, 4); // (5 + 5 + 2) / 3
    expect(r.avis, 3);
    expect(r.sansAvis, 0);
    expect(r.emojiDominant, '😍');
    expect([for (final p in r.connaissent) p.pseudo], ['Emma', 'Thomas']);
    expect([for (final p in r.yRetournent) p.pseudo], ['Emma']);
    expect(r.premiereDecouverte?.proche.pseudo, 'Thomas');
    expect(r.premiereDecouverte?.annee, 2023);
    expect(r.mesFois, 1);
    expect(r.photoUrl, 'photo-1');
    expect(monHistoireIci(r), 'Le 21 août 2026');
  });

  test('le temps depuis la dernière fois', () {
    final maintenant = DateTime(2026, 10, 27);
    expect(tempsDepuis(DateTime(2026, 10, 27), maintenant), isNull);
    expect(tempsDepuis(DateTime(2026, 10, 26), maintenant), (
      nombre: '1',
      unite: 'jour',
    ));
    expect(tempsDepuis(DateTime(2026, 10, 6), maintenant), (
      nombre: '3',
      unite: 'semaines',
    ));
    expect(tempsDepuis(DateTime(2025, 6, 18), maintenant), (
      nombre: '16',
      unite: 'mois',
    ));
    expect(tempsDepuis(DateTime(2023, 1, 1), maintenant), (
      nombre: '3',
      unite: 'ans',
    ));
  });

  test('« Assiette · Exceptionnelle » se lit « Assiette exceptionnelle »', () {
    expect(
      impressionLisible('Assiette · Exceptionnelle'),
      'Assiette exceptionnelle',
    );
    expect(impressionLisible('Ambiance'), 'Ambiance');
  });

  group('l\'éventail des proches', () {
    final maintenant = DateTime(2026, 10, 27);
    List<ProcheFiche> proches(int n) => [
      for (var i = 0; i < n; i++)
        (
          id: 'p$i',
          pseudo: 'Proche $i',
          photoUrl: i == 0 ? 'photo' : null,
          fois: i + 1,
          derniere: DateTime(2026, 8, 27),
          emoji: i == 0 ? '😍' : null,
        ),
    ];

    test('aucun proche : aucune carte', () {
      final e = eventailProches([], maintenant);
      expect(e.cartes, isEmpty);
      expect(e.autres, isNull);
    });

    test('jusqu\'à 4 proches : une carte chacun, sans « + »', () {
      for (final n in [1, 3, 4]) {
        final e = eventailProches(proches(n), maintenant);
        expect(e.cartes, hasLength(n));
        expect(e.autres, isNull);
      }
    });

    test('5 proches : 3 cartes et « +2 »', () {
      final e = eventailProches(proches(5), maintenant);
      expect([for (final c in e.cartes) c.id], ['p0', 'p1', 'p2']);
      expect(e.autres, (texte: '+2', nombreux: false));
    });

    test('« + » plafonné à 10, doré au-delà', () {
      expect(eventailProches(proches(13), maintenant).autres, (
        texte: '+10',
        nombreux: false,
      ));
      expect(eventailProches(proches(14), maintenant).autres, (
        texte: '+10',
        nombreux: true,
      ));
    });

    test('les textes d\'une carte sont prêts à afficher', () {
      final c = eventailProches(proches(2), maintenant).cartes;
      expect(c[0].pseudo, 'Proche 0');
      expect(c[0].photoUrl, 'photo');
      expect(c[0].ressenti, '😍');
      expect(c[0].fois, '1 fois');
      expect(c[1].fois, '2 fois');
      expect(c[1].ressenti, isNull);
      expect(c[0].derniereVisite, 'Il y a 2 mois');
    });

    test('la dernière visite', () {
      String texte(DateTime d) => derniereVisiteLisible(d, maintenant);
      expect(texte(DateTime(2026, 10, 27)), "Aujourd'hui");
      expect(texte(DateTime(2026, 10, 26)), 'Hier');
      expect(texte(DateTime(2026, 10, 24)), 'Il y a 3 jours');
      expect(texte(DateTime(2026, 10, 6)), 'Il y a 3 semaines');
      expect(texte(DateTime(2023, 1, 1)), 'Il y a 3 ans');
    });
  });
}
