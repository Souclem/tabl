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
}
