import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

SuggestionAmi _suggestion(
  String pseudo, {
  bool meSuit = false,
  int momentsCommuns = 0,
  int amisCommuns = 0,
  List<String> noms = const [],
  StatutAbonnement statut = StatutAbonnement.aucun,
}) => SuggestionAmi(
  profil: ProfilPublic(
    id: '$pseudo-id',
    pseudo: pseudo,
    statut: statut,
    meSuit: meSuit,
  ),
  momentsCommuns: momentsCommuns,
  amisCommuns: amisCommuns,
  nomsAmisCommuns: noms,
);

void main() {
  group('classerSuggestions', () {
    test(
      "qui me suit, puis qui était à table avec moi, puis les amis d'amis",
      () {
        final classees = classerSuggestions([
          _suggestion('zoe', amisCommuns: 3),
          _suggestion('tom', momentsCommuns: 1),
          _suggestion('anna', meSuit: true),
          _suggestion('paul', amisCommuns: 1),
        ]);
        expect(
          [for (final s in classees) s.profil.pseudo],
          ['anna', 'tom', 'zoe', 'paul'],
        );
      },
    );

    test('à égalité, par pseudo ; jamais plus de dix', () {
      final classees = classerSuggestions([
        for (var i = 11; i >= 0; i--)
          _suggestion('ami${i.toString().padLeft(2, '0')}', amisCommuns: 1),
      ]);
      expect(classees, hasLength(nombreMaxSuggestions));
      expect(classees.first.profil.pseudo, 'ami00');
    });
  });

  group('raisonSuggestion', () {
    test('la raison la plus forte, en une ligne', () {
      expect(
        raisonSuggestion(_suggestion('a', meSuit: true, amisCommuns: 4)),
        'Vous suit',
      );
      expect(
        raisonSuggestion(_suggestion('a', momentsCommuns: 1)),
        'Avec vous dans un moment',
      );
      expect(
        raisonSuggestion(_suggestion('a', momentsCommuns: 3)),
        'Avec vous dans 3 moments',
      );
    });

    test('les amis en commun, nommés', () {
      expect(
        raisonSuggestion(
          _suggestion('a', amisCommuns: 1, noms: const ['emma']),
        ),
        'Suivi par emma',
      );
      expect(
        raisonSuggestion(
          _suggestion('a', amisCommuns: 2, noms: const ['emma', 'léo']),
        ),
        'Suivi par emma et léo',
      );
      expect(
        raisonSuggestion(
          _suggestion('a', amisCommuns: 5, noms: const ['emma', 'léo']),
        ),
        'Suivi par emma et 4 autres',
      );
    });
  });

  test('le bouton : suivre, suivre en retour, puis où en est mon suivi', () {
    expect(libelleSuivreSuggestion(_suggestion('a')), 'Suivre');
    expect(
      libelleSuivreSuggestion(_suggestion('a', meSuit: true)),
      'Suivre en retour',
    );
    expect(
      libelleSuivreSuggestion(
        _suggestion('a', meSuit: true, statut: StatutAbonnement.abonne),
      ),
      'Abonné',
    );
    expect(
      libelleSuivreSuggestion(
        _suggestion('a', statut: StatutAbonnement.demandeEnvoyee),
      ),
      'Demande envoyée',
    );
  });
}
