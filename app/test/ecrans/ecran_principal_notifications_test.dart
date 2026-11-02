import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_notifications.dart';
import 'package:app/ecrans/ecran_principal.dart';

class _FauxNotificationsSysteme implements NotificationsSysteme {
  int activations = 0;
  final _touchees = StreamController<String>.broadcast();

  void toucher(String type) => _touchees.add(type);

  @override
  Future<void> activer() async => activations++;

  @override
  Stream<String> get touchees => _touchees.stream;
}

class _FauxNotificationService implements NotificationService {
  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async => (
    notifications: [
      NotificationTabl(
        type: TypeNotification.demandeSuivi,
        acteur: (id: 'm', pseudo: 'martin', photoUrl: null),
        creeLe: DateTime.now(),
      ),
    ],
    vuesLe: null,
  );

  @override
  Future<void> marquerVues(DateTime moment) async {}
}

class _FauxAvisService implements AvisService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<List<ProfilPublic>> mesRelations() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<List<SouvenirFeed>> feed() async => [];

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  testWidgets('les notifications du téléphone : activées une fois connecté, '
      'et une notification touchée ouvre la cloche', (tester) async {
    final systeme = _FauxNotificationsSysteme();
    await tester.pumpWidget(
      MaterialApp(
        home: EcranPrincipal(
          authService: _FauxAuthService(),
          abonnementService: _FauxAbonnementService(),
          souvenirService: _FauxSouvenirService(),
          utilisateur: const Utilisateur(
            id: 'moi',
            email: 'moi@exemple.com',
            pseudo: 'moi',
          ),
          notificationService: _FauxNotificationService(),
          notificationsSysteme: systeme,
          avisService: _FauxAvisService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(systeme.activations, 1);
    expect(find.byType(EcranNotifications), findsNothing);

    systeme.toucher('demande_suivi');
    await tester.pumpAndSettle();
    expect(find.byType(EcranNotifications), findsOneWidget);
    expect(find.textContaining('souhaite vous suivre'), findsOneWidget);
  });
}
