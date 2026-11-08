import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/feuille_restaurant.dart';

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService(this.moments);

  final List<SouvenirFeed> moments;
  final List<String> restaurantsDemandes = [];
  final List<(String, bool)> envies = [];

  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async {
    restaurantsDemandes.add(restaurantId);
    return moments;
  }

  @override
  Future<void> basculerEnvie(
    String restaurantId, {
    required bool envie,
  }) async => envies.add((restaurantId, envie));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FausseTableService implements TableService {
  _FausseTableService(this.tables);

  final List<ResumeTable> tables;
  final List<({String table, String restaurant, String ville})> proposees = [];

  @override
  Future<List<ResumeTable>> mesTables() async => tables;

  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async {
    proposees.add((table: tableId, restaurant: nomRestaurant, ville: ville));
    return (
      proposition: PropositionTable(
        id: 'p1',
        restaurantId: 'r1',
        restaurantNom: nomRestaurant,
        ville: ville,
        proposePar: 'clem',
        parMoi: true,
        etatTexte: '',
        active: true,
        nombreGo: 0,
      ),
      dejaExistante: false,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _tableDuMardi = ResumeTable(
  id: 't1',
  nom: 'Les mardis',
  emoji: '🍝',
  nombreMembres: 4,
  etatTexte: '',
  actionRequise: false,
);

SouvenirFeed _moment(
  String id,
  String auteur,
  DateTime date, {
  Emotion? emotion = Emotion.coupDeCoeur,
  bool moi = false,
  List<String> impressions = const [],
  String? legende,
}) => SouvenirFeed(
  id: id,
  photoUrl: null,
  legende: legende,
  restaurantNom: 'Como en Casa',
  ville: 'Liège',
  moment: 'soir',
  dateVisite: date,
  auteurPseudo: moi ? 'clem' : auteur,
  auteurId: moi ? 'moi' : auteur,
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  emotion: emotion,
  estAMoi: moi,
  impressions: impressions,
  restaurantId: 'r1',
);

Future<void> _ouvrir(
  WidgetTester tester,
  _FauxSouvenirService service, {
  String? restaurantId = 'r1',
  Future<String> Function()? entrerDansTabl,
  String sousTitre = 'Végétarien · Rue Hors-Château 76, Liège',
  String nom = 'Como en Casa',
  double? latitude,
  double? longitude,
  TableService? tableService,
}) async {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: FicheRestaurant(
          nom: nom,
          sousTitre: sousTitre,
          latitude: latitude,
          longitude: longitude,
          restaurantId: restaurantId,
          tableService: tableService,
          souvenirService: service,
          entrerDansTabl: entrerDansTabl,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets('l\'avis du cercle, qui la connaît, qui y retourne', (
    tester,
  ) async {
    final service = _FauxSouvenirService([
      _moment('3', 'Emma', DateTime(2026, 10, 3), legende: 'On y retourne !'),
      _moment('2', 'Emma', DateTime(2026, 6, 3), emotion: Emotion.satisfait),
      _moment('1', 'Thomas', DateTime(2024, 9, 12), emotion: null),
    ]);
    await _ouvrir(tester, service);

    expect(service.restaurantsDemandes, ['r1']);
    expect(find.text('Como en Casa'), findsWidgets);
    // 😍 (5) et 🙂 (3,5) : 4,3 sur 5 ; Thomas n'a pas donné de ressenti.
    expect(find.text('4,3'), findsOneWidget);
    expect(find.text('2 avis · 1 passage sans avis'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('CONNAISSENT'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Y RETOURNE'), findsOneWidget);
    // Thomas y est allé le premier, en 2024.
    expect(find.text('PREMIÈRE DÉCOUVERTE'), findsOneWidget);
    expect(find.text('2024'), findsOneWidget);
    expect(find.text('Pas encore dans votre histoire.'), findsOneWidget);
    // Puis les moments du cercle, du plus récent au plus ancien.
    expect(find.byType(TablLigneAvis), findsNWidgets(3));
  });

  testWidgets('mon histoire ici, et ce qui ressort', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([
        _moment(
          '2',
          '',
          DateTime(2026, 8, 21),
          moi: true,
          impressions: ['Assiette · Exceptionnelle'],
        ),
        _moment(
          '1',
          '',
          DateTime(2026, 1, 10),
          moi: true,
          impressions: ['Assiette · Exceptionnelle', 'Service · Attentionné'],
        ),
      ]),
    );

    expect(find.text('FOIS ICI'), findsOneWidget);
    expect(
      find.text('Depuis janvier 2026 · dernière fois le 21 août 2026'),
      findsOneWidget,
    );
    expect(find.text('CE QUI RESSORT'), findsOneWidget);
    expect(find.text('Assiette exceptionnelle'), findsOneWidget);
    expect(find.text('2 fois'), findsOneWidget);
  });

  testWidgets('un moment s\'agrandit sur place', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([
        _moment('1', 'Emma', DateTime(2026, 10, 3)),
        _moment('2', 'Thomas', DateTime(2026, 9, 12)),
      ]),
    );

    await mockNetworkImagesFor(() async {
      await tester.tap(find.widgetWithText(TablLigneAvis, 'Emma'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(TablPublication), findsOneWidget);
    expect(find.byType(TablLigneAvis), findsOneWidget);
  });

  testWidgets('lieu de l\'annuaire : aucun avis, « Garder » le fait entrer', (
    tester,
  ) async {
    final service = _FauxSouvenirService([]);
    var entrees = 0;
    await _ouvrir(
      tester,
      service,
      restaurantId: null,
      entrerDansTabl: () async {
        entrees++;
        return 'nouveau';
      },
    );

    expect(service.restaurantsDemandes, isEmpty);
    expect(find.textContaining('Personne de votre cercle'), findsOneWidget);

    await tester.tap(find.byTooltip('Garder pour plus tard'));
    await tester.pumpAndSettle();

    expect(entrees, 1);
    expect(service.envies, [('nouveau', true)]);
    expect(find.byTooltip('Retirer de mes envies'), findsOneWidget);

    await tester.tap(find.byTooltip('Retirer de mes envies'));
    await tester.pumpAndSettle();

    expect(service.envies.last, ('nouveau', false));
    expect(find.byTooltip('Garder pour plus tard'), findsOneWidget);
  });

  testWidgets('l\'éventail : une carte par proche', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([
        _moment('3', 'Emma', DateTime(2026, 10, 3)),
        _moment('2', 'Emma', DateTime(2026, 6, 3)),
        _moment('1', 'Thomas', DateTime(2024, 9, 12), emotion: null),
      ]),
    );

    expect(find.byType(TablEventail), findsOneWidget);
    final eventail = tester.widget<TablEventail>(find.byType(TablEventail));
    expect(eventail.cartes.map((c) => c.pseudo), ['Emma', 'Thomas']);
    expect(eventail.cartes.first.fois, '2 fois');
    expect(eventail.autres, isNull);
  });

  testWidgets('pas d\'éventail sans proche', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService([]));
    expect(find.byType(TablEventail), findsNothing);
  });

  testWidgets('cinq proches : trois cartes et « +2 » qui ouvre « Qui y est '
      'allé »', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([
        for (var i = 1; i <= 5; i++)
          _moment('m$i', 'Ami$i', DateTime(2026, 10, i)),
      ]),
    );

    final eventail = tester.widget<TablEventail>(find.byType(TablEventail));
    expect(eventail.cartes, hasLength(3));
    expect(eventail.autres?.texte, '+2');

    await tester.tap(find.text('+2'));
    await tester.pumpAndSettle();

    expect(find.text('Qui y est allé'), findsWidgets);
    for (var i = 1; i <= 5; i++) {
      expect(find.text('Ami$i'), findsWidgets);
    }
  });

  testWidgets('« On y va ? » propose à la Table choisie', (tester) async {
    final tables = _FausseTableService([_tableDuMardi]);
    await _ouvrir(
      tester,
      _FauxSouvenirService([_moment('1', 'Emma', DateTime(2026, 10, 3))]),
      tableService: tables,
    );

    await tester.tap(find.text('On y va ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Les mardis'));
    await tester.pumpAndSettle();

    expect(tables.proposees, [
      (table: 't1', restaurant: 'Como en Casa', ville: 'Liège'),
    ]);
    expect(find.text('Proposé à Les mardis.'), findsOneWidget);
  });

  testWidgets('« On y va ? » est masqué sans Table', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([_moment('1', 'Emma', DateTime(2026, 10, 3))]),
      tableService: _FausseTableService(const []),
    );
    expect(find.text('On y va ?'), findsNothing);
  });

  testWidgets('« On y va ? » est masqué sans service de Tables', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([_moment('1', 'Emma', DateTime(2026, 10, 3))]),
    );
    expect(find.text('On y va ?'), findsNothing);
  });

  group('Itinéraire', () {
    final lancements = <String>[];

    setUp(() {
      lancements.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (appel) async {
              if (appel.method == 'launch') {
                lancements.add((appel.arguments as Map)['url'] as String);
              }
              return true;
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            null,
          );
    });

    testWidgets('part des coordonnées quand on les a', (tester) async {
      await _ouvrir(
        tester,
        _FauxSouvenirService([]),
        latitude: 50.64,
        longitude: 5.57,
      );

      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();

      expect(lancements.single, contains('50.64'));
      expect(lancements.single, contains('5.57'));
    });

    testWidgets('sans coordonnées : le nom et l\'adresse', (tester) async {
      await _ouvrir(tester, _FauxSouvenirService([]));

      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();

      final lien = Uri.parse(lancements.single);
      expect(
        lien.queryParameters['destination'],
        'Como en Casa, Rue Hors-Château 76, Liège',
      );
    });

    testWidgets('masqué quand on ne sait rien pour y aller', (tester) async {
      await _ouvrir(tester, _FauxSouvenirService([]), nom: '', sousTitre: '');
      expect(find.text('Itinéraire'), findsNothing);
    });
  });
}
