import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_notifications.dart';
import 'package:app/ecrans/ecran_repondre_avis.dart';
import 'package:app/ecrans/feuille_restaurant.dart';

class _FauxAvisService implements AvisService {
  final List<({String restaurant, List<String> a, String message})> demandes =
      [];
  final List<({String demande, ReponseAvis reponse, String? mot})> reponses =
      [];

  @override
  Future<void> demander({
    required String restaurantId,
    required List<String> destinataireIds,
    required String message,
  }) async => demandes.add((
    restaurant: restaurantId,
    a: destinataireIds,
    message: message,
  ));

  @override
  Future<void> repondre(
    String demandeId,
    ReponseAvis reponse, {
    String? mot,
  }) async => reponses.add((demande: demandeId, reponse: reponse, mot: mot));
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  _FauxSouvenirService([this.moments = const []]);

  final List<SouvenirFeed> moments;

  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async =>
      moments;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxNotificationService implements NotificationService {
  _FauxNotificationService(this.notifications);

  final List<NotificationTabl> notifications;

  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async => (notifications: notifications, vuesLe: null);

  @override
  Future<void> marquerVues(DateTime moment) async {}
}

SouvenirFeed _moment(String id, String auteur, DateTime date) => SouvenirFeed(
  id: id,
  photoUrl: null,
  legende: null,
  restaurantNom: 'Septime',
  ville: 'Paris',
  moment: 'soir',
  dateVisite: date,
  auteurPseudo: auteur,
  auteurId: 'id-$auteur',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  emotion: Emotion.coupDeCoeur,
  restaurantId: 'r1',
);

void _grandEcran(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('depuis la fiche : choisir à qui demander, et envoyer', (
    tester,
  ) async {
    _grandEcran(tester);
    final avis = _FauxAvisService();
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: TablTheme.sombre(),
          home: FicheRestaurant(
            nom: 'Septime',
            sousTitre: 'Gastronomique · Paris',
            restaurantId: 'r1',
            souvenirService: _FauxSouvenirService([
              _moment('2', 'Emma', DateTime(2026, 10, 1)),
              _moment('3', 'Emma', DateTime(2026, 6, 1)),
              _moment('1', 'Thomas', DateTime(2026, 9, 1)),
            ]),
            avisService: avis,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Demander'));
      await tester.pumpAndSettle();
    });

    expect(find.text('2 proches y sont allés'), findsOneWidget);
    // Le plus fidèle est choisi d'avance.
    expect(find.text('Envoyer à Emma'), findsOneWidget);
    expect(
      find.text('Tu me conseilles d\'aller chez Septime ?'),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Thomas'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer aux 2'));
    await tester.pumpAndSettle();

    final demande = avis.demandes.single;
    expect(demande.restaurant, 'r1');
    expect(demande.a.toSet(), {'id-Emma', 'id-Thomas'});
    expect(demande.message, 'Tu me conseilles d\'aller chez Septime ?');
    expect(
      find.textContaining('Votre question part à 2 proches'),
      findsOneWidget,
    );
  });

  testWidgets('répondre : une réponse en un toucher, un mot si on veut', (
    tester,
  ) async {
    _grandEcran(tester);
    final avis = _FauxAvisService();
    final retours = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => retours.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EcranRepondreAvis(
                      avisService: avis,
                      demandeId: 'd1',
                      demandeur: 'Martin',
                      question:
                          'Tu me conseilles d\'aller chez Osteria Bella ?',
                    ),
                  ),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Martin vous demande'), findsOneWidget);
    final envoyer = find.widgetWithText(TablBouton, 'Envoyer ma réponse');
    expect(tester.widget<TablBouton>(envoyer).onPresse, isNull);

    await tester.tap(find.text('Ça dépend'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Seulement le midi');
    await tester.tap(envoyer);
    await tester.pumpAndSettle();

    expect(avis.reponses.single, (
      demande: 'd1',
      reponse: ReponseAvis.depend,
      mot: 'Seulement le midi',
    ));
    expect(retours, [true]);
  });

  testWidgets(
    'une demande d\'avis reçue : « Répondre » dans les notifications',
    (tester) async {
      _grandEcran(tester);
      await mockNetworkImagesFor(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TablTheme.sombre(),
            home: EcranNotifications(
              notificationService: _FauxNotificationService([
                NotificationTabl(
                  type: TypeNotification.demandeAvis,
                  acteur: (id: 'martin', pseudo: 'Martin', photoUrl: null),
                  creeLe: DateTime.now(),
                  restaurantId: 'r1',
                  restaurantNom: 'Osteria Bella',
                  texte: 'Tu me conseilles d\'aller chez Osteria Bella ?',
                  demandeId: 'd1',
                ),
              ]),
              abonnementService: _FauxAbonnementService(),
              souvenirService: _FauxSouvenirService(),
              avisService: _FauxAvisService(),
            ),
          ),
        );
        await tester.pumpAndSettle();
      });

      expect(find.text('UNE DEMANDE'), findsOneWidget);
      expect(
        find.textContaining('vous demande votre avis chez Osteria Bella'),
        findsOneWidget,
      );
      await tester.tap(find.text('Répondre'));
      await tester.pumpAndSettle();
      expect(find.text('Martin vous demande'), findsOneWidget);
    },
  );
}
