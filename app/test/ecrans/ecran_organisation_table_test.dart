import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_organisation_table.dart';

class _FauxTableService implements TableService {
  _FauxTableService({List<MessageOrganisation> messages = const []})
    : _messages = List.of(messages);

  List<MessageOrganisation> _messages;
  final List<({String id, String contenu})> messagesEnvoyes = [];
  final List<String> messagesSupprimes = [];

  @override
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) async =>
      List.of(_messages);

  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) async {
    messagesEnvoyes.add((id: propositionId, contenu: contenu));
    _messages = [
      ..._messages,
      MessageOrganisation(
        id: 'm-${_messages.length}',
        auteurId: 'moi',
        auteurPseudo: 'Moi',
        contenu: contenu,
        creeLe: DateTime.now(),
        parMoi: true,
      ),
    ];
  }

  @override
  Future<void> supprimerMessageOrganisation(String messageId) async {
    messagesSupprimes.add(messageId);
    _messages = _messages.where((m) => m.id != messageId).toList();
  }

  @override
  Future<DetailProposition> detailProposition(String propositionId) async =>
      throw UnimplementedError();
  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {}
  @override
  Future<void> definirDatesCandidates(String propositionId, List<DateTime> datesLocales) async {}
  @override
  Future<void> soumettreDisponibilites(String propositionId, List<String> dateCandidateIds) async {}
  @override
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  }) async {}
  @override
  Future<void> ajouterHeure(String propositionId, String heure) async {}
  @override
  Future<void> replanifier(String propositionId) async {}
  @override
  Future<void> annulerProposition(String propositionId) async {}
  @override
  Future<List<ResumeTable>> mesTables() async => throw UnimplementedError();
  @override
  Future<List<ResumeTable>> mesInvitations() async => throw UnimplementedError();
  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) async => throw UnimplementedError();
  @override
  Future<GroupeTable> table(String tableId) async => throw UnimplementedError();
  @override
  Future<void> accepterInvitation(String tableId) async {}
  @override
  Future<void> refuserInvitation(String tableId) async {}
  @override
  Future<void> inviter(String tableId, String profilId) async {}
  @override
  Future<void> quitter(String tableId) async {}
  @override
  Future<void> retirerMembre(String tableId, String profilId) async {}
  @override
  Future<void> renommer(String tableId, String nom) async {}
  @override
  Future<void> supprimer(String tableId) async {}
  @override
  Future<
    ({
      List<ExperienceHistoireTable> experiences,
      List<RecurrenceTable> laOuOnRevient,
    })
  >
  histoire(String tableId) async => throw UnimplementedError();
  @override
  Future<List<PropositionTable>> propositions(String tableId) async => const [];
  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async => throw UnimplementedError();
  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) async => const [];
}

void main() {
  testWidgets('aucun message : état vide invitant à discuter', (tester) async {
    final service = _FauxTableService();
    await tester.pumpWidget(
      MaterialApp(
        home: EcranOrganisationTable(propositionId: 'p-1', tableService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discutez des détails pratiques ici.'), findsOneWidget);
  });

  testWidgets('affiche les messages existants, jamais de statut "vu" (règle 46)', (tester) async {
    final service = _FauxTableService(
      messages: [
        MessageOrganisation(
          id: 'm-1',
          auteurId: 'u-emma',
          auteurPseudo: 'Emma',
          contenu: '20h30 ça vous va ?',
          creeLe: DateTime(2026, 9, 10),
          parMoi: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EcranOrganisationTable(propositionId: 'p-1', tableService: service),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('20h30 ça vous va ?'), findsOneWidget);
    expect(find.text('Emma'), findsOneWidget);
    expect(find.textContaining('vu'), findsNothing);
  });

  testWidgets('envoyer un message texte appelle le service et l\'affiche', (tester) async {
    final service = _FauxTableService();
    await tester.pumpWidget(
      MaterialApp(
        home: EcranOrganisationTable(propositionId: 'p-1', tableService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Je réserve.');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(service.messagesEnvoyes, [(id: 'p-1', contenu: 'Je réserve.')]);
    expect(find.text('Je réserve.'), findsOneWidget);
  });

  testWidgets('supprimer son propre message (appui long) appelle le service', (tester) async {
    final service = _FauxTableService(
      messages: [
        MessageOrganisation(
          id: 'm-1',
          auteurId: 'moi',
          auteurPseudo: 'Moi',
          contenu: 'Je réserve.',
          creeLe: DateTime(2026, 9, 10),
          parMoi: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EcranOrganisationTable(propositionId: 'p-1', tableService: service),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Je réserve.'));
    await tester.pumpAndSettle();

    expect(service.messagesSupprimes, ['m-1']);
  });
}
