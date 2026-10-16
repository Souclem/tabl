import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

VisiteCarte _v(
  String auteur, {
  bool moi = false,
  String moment = 'soir',
  Emotion? emotion,
  Set<String> tables = const {},
}) => VisiteCarte(
  souvenirId: '$auteur-$moment-${emotion?.emoji}',
  auteurId: auteur,
  auteurPseudo: auteur,
  estMoi: moi,
  moment: moment,
  date: DateTime(2026, 10, 1),
  emotion: emotion,
  tableIds: tables,
);

LieuCarte _lieu(
  String id, {
  List<VisiteCarte> visites = const [],
  bool envie = false,
  List<String> categories = const ['Italian Restaurant'],
}) => LieuCarte(
  restaurantId: id,
  nom: id,
  ville: 'Liège',
  latitude: 50.6,
  longitude: 5.5,
  categories: categories,
  visites: visites,
  estEnvie: envie,
);

void main() {
  final pizzeria = _lieu('pizzeria', visites: [_v('emma')]);
  final sushi = _lieu(
    'sushi',
    categories: const ['Sushi Restaurant'],
    visites: [
      _v('thomas', emotion: Emotion.coupDeCoeur, moment: 'midi'),
      _v('thomas', tables: {'marbella'}),
    ],
  );
  final cheznous = _lieu('cheznous', visites: [_v('moi', moi: true)]);
  final envie = _lieu('envie', envie: true);
  final annuaire = LieuCarte(
    fsqPlaceId: 'x',
    nom: 'annuaire',
    ville: 'Liège',
    latitude: 50.6,
    longitude: 5.5,
    categories: const ['Pizzeria'],
  );
  final tous = [pizzeria, sushi, cheznous, envie, annuaire];
  List<String> garde(FiltresCarte f) => [
    for (final l in tous)
      if (f.garde(l)) l.nom,
  ];

  test('sans filtre : tout est gardé, annuaire visible', () {
    expect(garde(FiltresCarte.aucun), hasLength(5));
    expect(FiltresCarte.aucun.annuaireVisible, isTrue);
  });

  test('une personne : seulement les lieux où elle est allée', () {
    expect(garde(const FiltresCarte(personneId: 'thomas')), ['sushi']);
  });

  test('une Table : les sorties partagées dans cette Table', () {
    expect(garde(const FiltresCarte(tableId: 'marbella')), ['sushi']);
  });

  test('cuisine : par famille, annuaire compris', () {
    expect(garde(const FiltresCarte(familles: {'Italienne et pizza'})), [
      'pizzeria',
      'cheznous',
      'envie',
      'annuaire',
    ]);
    expect(garde(const FiltresCarte(familles: {'Asiatique'})), ['sushi']);
  });

  test('mes envies, jamais essayé', () {
    expect(garde(const FiltresCarte(mesEnvies: true)), ['envie']);
    expect(
      garde(const FiltresCarte(jamaisEssaye: true)),
      isNot(contains('cheznous')),
    );
  });

  test('coups de cœur, midi/soir, là où on revient', () {
    expect(garde(const FiltresCarte(coupsDeCoeur: true)), ['sushi']);
    expect(garde(const FiltresCarte(moment: 'midi')), ['sushi']);
    expect(garde(const FiltresCarte(laOuOnRevient: true)), ['sushi']);
    // Combinés : la même visite doit correspondre aux deux.
    expect(
      garde(const FiltresCarte(laOuOnRevient: true, moment: 'midi')),
      isEmpty,
    );
  });

  test('un filtre réseau masque l\'annuaire et compte comme actif', () {
    const f = FiltresCarte(coupsDeCoeur: true, familles: {'Asiatique'});
    expect(f.annuaireVisible, isFalse);
    expect(f.nombreActifs, 2);
  });

  test('personnes proposées : sans moi, sans doublon, triées', () {
    expect(personnesDesLieux(tous).map((p) => p.pseudo), ['emma', 'thomas']);
  });
}
