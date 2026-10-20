import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/feuille_restaurant.dart';

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService(this.avis);

  final List<SouvenirFeed> avis;
  final List<String> restaurantsDemandes = [];
  final List<(String, bool)> envies = [];

  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async {
    restaurantsDemandes.add(restaurantId);
    return avis;
  }

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) async =>
      envies.add((restaurantId, envie));

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SouvenirFeed _avis(String id, String auteur, DateTime date, {String? legende}) =>
    SouvenirFeed(
      id: id,
      photoUrl: null,
      legende: legende,
      restaurantNom: 'Como en Casa',
      ville: 'Liège',
      moment: 'soir',
      dateVisite: date,
      auteurPseudo: auteur,
      nombreReactions: 0,
      jaiReagi: false,
      nombreCommentaires: 0,
      emotion: Emotion.coupDeCoeur,
      restaurantId: 'r1',
    );

Future<void> _ouvrir(
  WidgetTester tester,
  _FauxSouvenirService service, {
  String? restaurantId = 'r1',
  Future<String> Function()? entrerDansTabl,
}) async {
  // Assez large pour la police des tests (plus large que la vraie), et
  // assez haut pour tout voir.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: Scaffold(
          body: FeuilleRestaurant(
            nom: 'Como en Casa',
            sousTitre: 'Végétarien · Rue Hors-Château 76, Liège',
            resume: 'Emma et 1 autre y sont allés',
            restaurantId: restaurantId,
            souvenirService: service,
            entrerDansTabl: entrerDansTabl,
            defilement: ScrollController(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets('en-tête et avis de mon réseau, version compacte', (tester) async {
    final service = _FauxSouvenirService([
      _avis('2', 'Emma', DateTime(2026, 10, 3), legende: 'On y retourne !'),
      _avis('1', 'Thomas', DateTime(2026, 9, 12)),
    ]);
    await _ouvrir(tester, service);

    expect(service.restaurantsDemandes, ['r1']);
    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('Emma et 1 autre y sont allés'), findsOneWidget);
    expect(find.text('2 avis de votre réseau'), findsOneWidget);
    expect(find.byType(TablLigneAvis), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Emma')).dy,
      lessThan(tester.getTopLeft(find.text('Thomas')).dy),
    );
  });

  testWidgets('un avis s\'agrandit sur place, puis se réduit', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService([
        _avis('1', 'Emma', DateTime(2026, 10, 3)),
        _avis('2', 'Thomas', DateTime(2026, 9, 12)),
      ]),
    );

    await mockNetworkImagesFor(() async {
      await tester.tap(find.text('Emma'));
      await tester.pumpAndSettle();
    });
    // Même écran : l'avis d'Emma est devenu une publication complète,
    // celui de Thomas reste compact.
    expect(find.byType(TablPublication), findsOneWidget);
    expect(find.byType(TablLigneAvis), findsOneWidget);
    expect(find.byTooltip('Commenter'), findsOneWidget);

    await tester.tap(find.text('Réduire'));
    await tester.pumpAndSettle();
    expect(find.byType(TablPublication), findsNothing);
    expect(find.byType(TablLigneAvis), findsNWidgets(2));
  });

  testWidgets('lieu de l\'annuaire : aucun avis, envie qui le fait entrer', (
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
    expect(find.textContaining('Personne de votre réseau'), findsOneWidget);

    await tester.tap(find.text('Ajouter à mes envies'));
    await tester.pumpAndSettle();

    expect(entrees, 1);
    expect(service.envies, [('nouveau', true)]);
    expect(find.text('Dans mes envies'), findsOneWidget);
  });
}
