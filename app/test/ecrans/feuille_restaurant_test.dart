import 'package:flutter/material.dart';
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
          nom: 'Como en Casa',
          sousTitre: 'Végétarien · Rue Hors-Château 76, Liège',
          restaurantId: restaurantId,
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

    await tester.tap(find.text('Garder'));
    await tester.pumpAndSettle();

    expect(entrees, 1);
    expect(service.envies, [('nouveau', true)]);
    expect(find.text('Gardée'), findsOneWidget);
  });
}
