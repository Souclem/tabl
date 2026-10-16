import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

CandidatDateProposition _candidat({
  required DateTime date,
  required int disponibles,
  required int eligibles,
  bool passee = false,
}) {
  return CandidatDateProposition(
    id: date.toIso8601String(),
    date: date,
    disponibles: disponibles,
    eligibles: eligibles,
    moiDisponible: false,
    passee: passee,
  );
}

DetailProposition _detail({
  List<CandidatDateProposition> candidats = const [],
  ConfirmationProposition? confirmation,
}) {
  return DetailProposition(
    id: 'p-1',
    restaurantNom: 'Bibo',
    ville: 'Marbella',
    proposePar: 'Thomas',
    parMoi: false,
    active: true,
    etatTexte: 'Choisissez vos dates',
    nombreGo: 4,
    progressionSoumis: 4,
    progressionEligibles: 4,
    moiAiSoumisReponse: true,
    candidats: candidats,
    confirmation: confirmation,
    peutAccederChat: true,
    nombreMessages: 0,
  );
}

void main() {
  group('DetailProposition.datesCommunes', () {
    test('une seule date à 100% : une date commune (règle 15)', () {
      final detail = _detail(
        candidats: [
          _candidat(date: DateTime(2026, 9, 12), disponibles: 4, eligibles: 4),
          _candidat(date: DateTime(2026, 9, 13), disponibles: 3, eligibles: 4),
        ],
      );
      expect(detail.datesCommunes, hasLength(1));
      expect(detail.datesCommunes.first.date, DateTime(2026, 9, 12));
    });

    test('plusieurs dates à 100% : toutes retournées, triées par date (règle 16)', () {
      final detail = _detail(
        candidats: [
          _candidat(date: DateTime(2026, 9, 13), disponibles: 4, eligibles: 4),
          _candidat(date: DateTime(2026, 9, 12), disponibles: 4, eligibles: 4),
        ],
      );
      expect(detail.datesCommunes.map((c) => c.date), [DateTime(2026, 9, 12), DateTime(2026, 9, 13)]);
    });

    test('aucune date à 100% : liste vide, meilleursCompromis triés par disponibilité (règle 17)', () {
      final detail = _detail(
        candidats: [
          _candidat(date: DateTime(2026, 9, 12), disponibles: 5, eligibles: 6),
          _candidat(date: DateTime(2026, 9, 19), disponibles: 2, eligibles: 6),
          _candidat(date: DateTime(2026, 9, 13), disponibles: 5, eligibles: 6),
        ],
      );
      expect(detail.datesCommunes, isEmpty);
      expect(
        detail.meilleursCompromis.map((c) => c.disponibles),
        [5, 5, 2],
      );
    });

    test('une date passée ne compte jamais comme commune (règle 33)', () {
      final detail = _detail(
        candidats: [
          _candidat(date: DateTime(2020, 1, 1), disponibles: 4, eligibles: 4, passee: true),
        ],
      );
      expect(detail.datesCommunes, isEmpty);
      expect(detail.toutesLesDatesSontPassees, isTrue);
    });
  });

  group('DetailProposition.estPassee', () {
    test('confirmée sans heure : passée seulement le lendemain (règle 49)', () {
      final detail = _detail(
        confirmation: ConfirmationProposition(
          date: DateTime(2026, 9, 12),
          heure: null,
          fuseauHoraire: 'Europe/Paris',
        ),
      );
      expect(detail.estPassee(DateTime(2026, 9, 12, 23, 0)), isFalse);
      expect(detail.estPassee(DateTime(2026, 9, 13, 0, 1)), isTrue);
    });

    test('confirmée avec heure : passée dès l\'heure dépassée', () {
      final detail = _detail(
        confirmation: ConfirmationProposition(
          date: DateTime(2026, 9, 12),
          heure: '20:30',
          fuseauHoraire: 'Europe/Paris',
        ),
      );
      expect(detail.estPassee(DateTime(2026, 9, 12, 20, 0)), isFalse);
      expect(detail.estPassee(DateTime(2026, 9, 12, 20, 31)), isTrue);
    });

    test('pas de confirmation : jamais passée', () {
      expect(_detail().estPassee(DateTime(2099)), isFalse);
    });
  });

  group('DetailProposition.chatArchive', () {
    test('archivé 24h après l\'événement (règle 49)', () {
      final detail = _detail(
        confirmation: ConfirmationProposition(
          date: DateTime(2026, 9, 12),
          heure: '20:30',
          fuseauHoraire: 'Europe/Paris',
        ),
      );
      expect(detail.chatArchive(DateTime(2026, 9, 13, 20, 0)), isFalse);
      expect(detail.chatArchive(DateTime(2026, 9, 13, 20, 31)), isTrue);
    });
  });
}
