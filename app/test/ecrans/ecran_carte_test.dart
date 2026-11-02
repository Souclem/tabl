import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_carte.dart';

/// Faux service : applique quelques filtres comme le ferait la base, et
/// garde les recherches reçues pour vérifier que l'écran recharge.
class _FauxCarteService implements CarteService {
  _FauxCarteService(this.lieux);

  final List<LieuCarte> lieux;
  final List<FiltresCarte> recherches = [];
  final List<ZoneCarte> zones = [];
  final List<ModeExplorer> modes = [];
  final List<({String id, bool envie})> envies = [];

  @override
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    ModeExplorer mode = ModeExplorer.cercle,
    int limite = nombreMaxLieuxCarte,
  }) async {
    recherches.add(filtres);
    zones.add(zone);
    modes.add(mode);
    return [
      for (final l in lieux)
        if (switch (mode) {
              ModeExplorer.envies => l.estEnvie,
              ModeExplorer.maCarte => l.visiteParMoi,
              ModeExplorer.cercle => l.amis > 0,
            } &&
            (!filtres.coupsDeCoeur || l.coupsDeCoeur > 0) &&
            (filtres.personneId == null || l.amiPseudo == 'Emma'))
          l,
    ];
  }

  @override
  Future<Map<String, String>> photos(Iterable<String> chemins) async => {};

  @override
  Future<String> idRestaurant(LieuCarte lieu) async => lieu.restaurantId!;

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) async {
    envies.add((id: restaurantId, envie: envie));
  }
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async => (
    abonnes: <ProfilPublic>[],
    abonnements: const [
      ProfilPublic(id: 'emma', pseudo: 'Emma', statut: StatutAbonnement.abonne),
    ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Un restaurant où Emma est allée (à Liège, sauf [latitude] et
/// [longitude] données).
LieuCarte _lieu(
  String nom, {
  bool coupDeCoeur = false,
  bool envie = false,
  int revenants = 0,
  int amis = 1,
  DateTime? derniere,
  String ville = 'Liège',
  double latitude = 50.64,
  double longitude = 5.57,
}) => LieuCarte(
  restaurantId: nom,
  nom: nom,
  ville: ville,
  latitude: latitude,
  longitude: longitude,
  categories: const ['Brasserie'],
  quartier: 'Carré',
  estEnvie: envie,
  amis: amis,
  visites: amis + revenants,
  coupsDeCoeur: coupDeCoeur ? 1 : 0,
  amiPseudo: 'Emma',
  amisQuiReviennent: revenants,
  derniereVisite: derniere ?? DateTime(2026, 9, 1),
  ressentis: [if (coupDeCoeur) '😍' else '🙂'],
  visages: [
    (pseudo: 'Emma', photoUrl: null),
    if (amis > 1) (pseudo: 'Martin', photoUrl: null),
  ],
);

Future<_FauxCarteService> _ouvrir(
  WidgetTester tester,
  List<LieuCarte> lieux,
) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _FauxCarteService(lieux);
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: EcranCarte(
        carteService: service,
        abonnementService: _FauxAbonnementService(),
        afficherCarte: false,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return service;
}

Future<void> _enListe(WidgetTester tester) async {
  await tester.tap(find.text('Liste'));
  await tester.pumpAndSettle();
}

Future<void> _ouvrirFiltres(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel(RegExp('^Filtres')));
  await tester.pumpAndSettle();
}

Future<void> _voirLesAdresses(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Voir les adresses'));
  await tester.tap(find.text('Voir les adresses'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('en-tête : la ville regardée, les modes et les filtres', (
    tester,
  ) async {
    await _ouvrir(tester, [_lieu('Bibo'), _lieu('Le Campus')]);

    // Trop loin pour une ville : tout le cercle.
    expect(find.text('Votre cercle'), findsOneWidget);
    expect(find.text('2 adresses connues par vos proches'), findsOneWidget);
    for (final mode in ['Ma carte', 'Envies', 'Le cercle']) {
      expect(find.text(mode), findsOneWidget);
    }
    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Liste'), findsOneWidget);
    expect(find.bySemanticsLabel('Filtres'), findsOneWidget);
  });

  testWidgets('tout est chargé d\'un coup, en mode « Le cercle »', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [_lieu('Bibo')]);

    // Le monde entier : les bulles de la carte comptent juste partout.
    expect(service.zones.single, same(ZoneCarte.monde));
    expect(service.modes.single, ModeExplorer.cercle);
  });

  testWidgets('la liste : le premier en grand, puis « La suite »', (
    tester,
  ) async {
    await _ouvrir(tester, [
      _lieu('Bibo', derniere: DateTime(2026, 8, 1)),
      _lieu('Le Campus', derniere: DateTime(2026, 10, 1), amis: 2),
      _lieu('Le Comptoir Paris', latitude: 48.86, longitude: 2.35),
    ]);
    await _enListe(tester);

    // « Récents » : la visite la plus récente d'abord.
    expect(find.byType(TablCarteVedette), findsOneWidget);
    final vedette = tester.widget<TablCarteVedette>(
      find.byType(TablCarteVedette),
    );
    expect(vedette.nom, 'Le Campus');
    expect(vedette.quiLaConnait, 'Emma et Martin la connaissent');
    expect(find.text('La suite'), findsOneWidget);
    expect(find.text('Bibo'), findsOneWidget);
    // La liste s'en tient à la zone regardée (la Belgique au départ).
    expect(find.text('Le Comptoir Paris'), findsNothing);
  });

  testWidgets('les tris : « Ils y retournent » d\'abord ceux qui reviennent', (
    tester,
  ) async {
    await _ouvrir(tester, [
      _lieu('Bibo', derniere: DateTime(2026, 10, 1)),
      _lieu('Le Campus', revenants: 2, derniere: DateTime(2026, 1, 1)),
    ]);
    await _enListe(tester);
    expect(
      tester.widget<TablCarteVedette>(find.byType(TablCarteVedette)).nom,
      'Bibo',
    );

    await tester.tap(find.text('Ils y retournent'));
    await tester.pumpAndSettle();

    final vedette = tester.widget<TablCarteVedette>(
      find.byType(TablCarteVedette),
    );
    expect(vedette.nom, 'Le Campus');
    expect(vedette.raison, '2 proches y retournent');
  });

  testWidgets('chercher trouve aussi hors de la zone regardée', (tester) async {
    await _ouvrir(tester, [
      _lieu('Bibo'),
      _lieu('Le Comptoir Paris', latitude: 48.86, longitude: 2.35),
    ]);
    await _enListe(tester);

    await tester.enterText(find.byType(TextField), 'comptoir');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TablCarteVedette>(find.byType(TablCarteVedette)).nom,
      'Le Comptoir Paris',
    );

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucune adresse ne correspond à « zzz ».'),
      findsOneWidget,
    );
  });

  testWidgets('les filtres : une feuille, puis des puces à retirer', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [
      _lieu('Le Campus', coupDeCoeur: true),
      _lieu('Bibo'),
    ]);
    await _enListe(tester);

    await _ouvrirFiltres(tester);
    expect(find.text('Moment du repas'.toUpperCase()), findsOneWidget);
    await tester.ensureVisible(find.text('Coups de cœur 😍'));
    await tester.tap(find.text('Coups de cœur 😍'));
    await tester.pumpAndSettle();
    await _voirLesAdresses(tester);

    expect(service.recherches.last.coupsDeCoeur, isTrue);
    expect(find.bySemanticsLabel('Filtres, 1 actifs'), findsOneWidget);
    expect(find.text('Bibo'), findsNothing);

    // La puce retire le filtre.
    await tester.tap(find.bySemanticsLabel('Retirer le filtre Coups de cœur'));
    await tester.pumpAndSettle();
    expect(service.recherches.last.coupsDeCoeur, isFalse);
    expect(find.text('Bibo'), findsOneWidget);
  });

  testWidgets('filtre « Personnes » : la personne part à la base', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [_lieu('Bibo')]);
    await _ouvrirFiltres(tester);
    await tester.tap(find.text('Emma').last);
    await tester.pumpAndSettle();
    await _voirLesAdresses(tester);

    expect(service.recherches.last.personneId, 'emma');
    expect(find.bySemanticsLabel('Retirer le filtre Emma'), findsOneWidget);
  });

  testWidgets('aucune adresse pour ces filtres : on le dit', (tester) async {
    await _ouvrir(tester, [_lieu('Bibo')]);
    await _enListe(tester);
    await _ouvrirFiltres(tester);
    await tester.ensureVisible(find.text('Coups de cœur 😍'));
    await tester.tap(find.text('Coups de cœur 😍'));
    await tester.pumpAndSettle();
    await _voirLesAdresses(tester);

    expect(
      find.text('Aucune adresse de vos proches ne correspond à ces filtres.'),
      findsOneWidget,
    );
  });

  testWidgets('« Envies » : un autre mode, retenu pour la prochaine fois', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [
      _lieu('Bibo'),
      _lieu('Como en Casa', envie: true, amis: 0),
    ]);

    await tester.tap(find.text('Envies'));
    await tester.pumpAndSettle();

    expect(service.modes.last, ModeExplorer.envies);
    expect(find.text('Les adresses que vous gardez pour plus tard.'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('explorer_mode'), 'envies');
  });

  testWidgets('« Ma carte » : ma Constellation, et mes adresses par ville', (
    tester,
  ) async {
    final service = await _ouvrir(tester, [
      LieuCarte(
        restaurantId: 'r1',
        nom: 'Le Comptoir',
        ville: 'Liège',
        latitude: 50.64,
        longitude: 5.57,
        visiteParMoi: true,
        mesVisites: 6,
        maPremiereVisite: DateTime(2024, 1, 1),
        maDerniereVisite: DateTime(2026, 8, 1),
      ),
      LieuCarte(
        restaurantId: 'r2',
        nom: 'Osteria Bella',
        ville: 'Milan',
        latitude: 45.46,
        longitude: 9.19,
        visiteParMoi: true,
        mesVisites: 2,
        maPremiereVisite: DateTime(2025, 7, 1),
        maDerniereVisite: DateTime(2026, 7, 1),
      ),
    ]);

    await tester.tap(find.text('Ma carte'));
    await tester.pumpAndSettle();
    expect(service.modes.last, ModeExplorer.maCarte);
    expect(find.text('Constellation'), findsOneWidget);
    expect(find.text('Votre histoire, table par table.'), findsOneWidget);

    await _enListe(tester);
    // Par ville, la plus fréquentée d'abord ; pas de tri à choisir.
    expect(find.text('Ils y retournent'), findsNothing);
    expect(find.text('1 table · 6 repas'), findsOneWidget);
    expect(find.text('6 repas · août 2026'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Liège').first).dy,
      lessThan(tester.getTopLeft(find.text('Milan').first).dy),
    );
  });

  testWidgets('« Où cherchez-vous ? » : les villes du cercle', (tester) async {
    await _ouvrir(tester, [
      _lieu('Bibo'),
      _lieu('Le Campus'),
      _lieu(
        'Le Comptoir Paris',
        ville: 'Paris',
        latitude: 48.86,
        longitude: 2.35,
      ),
    ]);

    await tester.tap(find.bySemanticsLabel(RegExp('Changer de ville')));
    await tester.pumpAndSettle();
    expect(find.text('OÙ CHERCHEZ-VOUS ?'), findsOneWidget);
    expect(find.text('2 adresses connues par vos proches'), findsWidgets);

    await tester.tap(find.text('Paris'));
    await tester.pumpAndSettle();

    expect(find.text('Paris'), findsOneWidget);
    expect(find.text('1 adresse connue par vos proches'), findsOneWidget);
  });
}
