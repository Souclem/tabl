import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_notifications.dart';

class _FauxNotificationService implements NotificationService {
  _FauxNotificationService(this.notifications, {this.vuesLe});

  List<NotificationTabl> notifications;
  final DateTime? vuesLe;
  final List<DateTime> vues = [];

  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async => (notifications: notifications, vuesLe: vuesLe);

  @override
  Future<void> marquerVues(DateTime moment) async => vues.add(moment);
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

  final List<String> acceptees = [];
  final List<String> refusees = [];

  @override
  Future<void> accepterDemande(String suiveurId) async =>
      acceptees.add(suiveurId);

  @override
  Future<void> refuserDemande(String suiveurId) async =>
      refusees.add(suiveurId);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxCarteService implements CarteService {
  @override
  Future<LieuCarte?> lieuDuRestaurant(String restaurantId) async =>
      const LieuCarte(
        restaurantId: 'r1',
        nom: 'Bibo',
        ville: 'Liège',
        adresse: 'Rue du Pont 16',
        categories: ['italien'],
        latitude: 50.6,
        longitude: 5.5,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FausseTableService implements TableService {
  @override
  Future<List<ResumeTable>> mesTables() async => const [
    ResumeTable(
      id: 't1',
      nom: 'Les mardis',
      nombreMembres: 4,
      etatTexte: '',
      actionRequise: false,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

NotificationTabl _n(
  TypeNotification type,
  String qui,
  DateTime quand, {
  String? souvenir,
}) => NotificationTabl(
  type: type,
  acteur: (id: qui, pseudo: qui, photoUrl: null),
  creeLe: quand,
  souvenirId: souvenir,
  restaurantNom: souvenir == null ? null : 'Bibo',
);

Future<void> _ouvrir(
  WidgetTester tester,
  _FauxNotificationService notifications,
  _FauxAbonnementService abonnements, {
  CarteService? carteService,
  TableService? tableService,
}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: EcranNotifications(
          notificationService: notifications,
          abonnementService: abonnements,
          souvenirService: _FauxSouvenirService(),
          carteService: carteService,
          tableService: tableService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

void main() {
  testWidgets('un avis reçu ouvre la fiche : sous-titre et « On y va ? »', (
    tester,
  ) async {
    final notifications = _FauxNotificationService([
      NotificationTabl(
        type: TypeNotification.avisRecu,
        acteur: (id: 'emma', pseudo: 'Emma', photoUrl: null),
        creeLe: DateTime.now(),
        restaurantId: 'r1',
        restaurantNom: 'Bibo',
      ),
    ]);
    await _ouvrir(
      tester,
      notifications,
      _FauxAbonnementService(),
      carteService: _FauxCarteService(),
      tableService: _FausseTableService(),
    );

    await tester.tap(find.textContaining('Emma'));
    await mockNetworkImagesFor(() => tester.pumpAndSettle());

    expect(find.text('On y va ?'), findsOneWidget);
    expect(find.textContaining('Rue du Pont 16'), findsWidgets);
  });

  testWidgets('les demandes en tête, puis les nouvelles et le reste', (
    tester,
  ) async {
    final maintenant = DateTime.now();
    final notifications = _FauxNotificationService([
      _n(
        TypeNotification.demandeSuivi,
        'Léa',
        maintenant.subtract(const Duration(hours: 1)),
      ),
      _n(
        TypeNotification.reaction,
        'Emma',
        maintenant.subtract(const Duration(hours: 2)),
        souvenir: 's1',
      ),
      _n(
        TypeNotification.nouvelAbonne,
        'Martin',
        maintenant.subtract(const Duration(days: 9)),
      ),
    ], vuesLe: maintenant.subtract(const Duration(days: 1)));
    await _ouvrir(tester, notifications, _FauxAbonnementService());

    expect(find.text('DEMANDE DE SUIVI'), findsOneWidget);
    expect(find.text('NOUVELLES'), findsOneWidget);
    expect(find.text('PLUS TÔT'), findsOneWidget);
    expect(find.textContaining('souhaite vous suivre'), findsOneWidget);
    expect(
      find.textContaining('a aimé votre moment chez Bibo'),
      findsOneWidget,
    );
    expect(find.textContaining('vous suit désormais'), findsOneWidget);
    // Ouvert : tout est vu.
    expect(notifications.vues, hasLength(1));
  });

  testWidgets('accepter une demande sur place', (tester) async {
    final abonnements = _FauxAbonnementService();
    final notifications = _FauxNotificationService([
      _n(TypeNotification.demandeSuivi, 'Léa', DateTime.now()),
    ]);
    await _ouvrir(tester, notifications, abonnements);

    notifications.notifications = [
      _n(TypeNotification.nouvelAbonne, 'Léa', DateTime.now()),
    ];
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    expect(abonnements.acceptees, ['Léa']);
    expect(find.text('Léa vous suit désormais.'), findsOneWidget);
    expect(find.text('Accepter'), findsNothing);
  });

  testWidgets('rien de neuf : on le dit simplement', (tester) async {
    await _ouvrir(
      tester,
      _FauxNotificationService([]),
      _FauxAbonnementService(),
    );

    expect(find.text('Rien de neuf pour l\'instant.'), findsOneWidget);
    expect(find.byType(TablLigneNotification), findsNothing);
  });
}
