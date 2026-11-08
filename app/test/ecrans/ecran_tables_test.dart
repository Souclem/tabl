import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_tables.dart';

class _FauxTableService implements TableService {
  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async => {for (final id in tableIds) id: <String>{}};

  _FauxTableService({
    List<ResumeTable> tables = const [],
    List<ResumeTable> invitations = const [],
  }) : _tables = List.of(tables),
       _invitations = List.of(invitations);

  final List<ResumeTable> _tables;
  List<ResumeTable> _invitations;
  final List<String> invitationsAcceptees = [];
  final List<String> invitationsRefusees = [];

  @override
  Future<List<ResumeTable>> mesTables() async => List.of(_tables);

  @override
  Future<List<ResumeTable>> mesInvitations() async => List.of(_invitations);

  @override
  Future<void> accepterInvitation(String tableId) async {
    invitationsAcceptees.add(tableId);
    _invitations = _invitations.where((t) => t.id != tableId).toList();
  }

  @override
  Future<void> refuserInvitation(String tableId) async {
    invitationsRefusees.add(tableId);
    _invitations = _invitations.where((t) => t.id != tableId).toList();
  }

  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<GroupeTable> table(String tableId) async => throw UnimplementedError();

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
  histoire(String tableId) async =>
      (experiences: const <ExperienceHistoireTable>[], laOuOnRevient: const <RecurrenceTable>[]);

  @override
  Future<List<PropositionTable>> propositions(String tableId) async => const [];

  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async => throw UnimplementedError();

  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {}

  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) async => const [];
  @override
  Future<DetailProposition> detailProposition(String propositionId) async =>
      throw UnimplementedError();
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
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) async => const [];
  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) async {}
  @override
  Future<void> supprimerMessageOrganisation(String messageId) async {}
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

  @override
  Future<CompteursProfil> compteurs(String profilId) =>
      throw UnimplementedError();

  @override
  Future<String> definirPhotoProfil(Uint8List photo) =>
      throw UnimplementedError();
  @override
  Future<ProfilVisite> profil(String id) => throw UnimplementedError();

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async => (abonnes: <ProfilPublic>[], abonnements: <ProfilPublic>[]);

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<bool> monProfilEstPrive() async => true;

  @override
  Future<void> definirProfilPrive(bool prive) async {}

  @override
  Future<List<ProfilPublic>> rechercher(String requete) async => [];
  @override
  Future<StatutAbonnement> suivre(String suiviId) async =>
      StatutAbonnement.demandeEnvoyee;
  @override
  Future<void> arreterDeSuivre(String suiviId) async {}
  @override
  Future<List<DemandeAbonnement>> demandesRecues() async => [];
  @override
  Future<void> accepterDemande(String suiveurId) async {}
  @override
  Future<void> refuserDemande(String suiveurId) async {}
  @override
  Future<int> nombreDemandesEnAttente() async => 0;
  @override
  Future<List<ProfilPublic>> mesRelations() async => [];
}

void main() {
  testWidgets('aucune table ni invitation : état vide avec CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranTables(
          tableService: _FauxTableService(),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Créez votre première Table'),
      findsOneWidget,
    );
    expect(find.text('Créer une Table'), findsOneWidget);
  });

  testWidgets('affiche les Tables avec leur état prioritaire', (tester) async {
    final service = _FauxTableService(
      tables: const [
        ResumeTable(
          id: 't1',
          nom: 'Marbella',
          emoji: '☀️',
          nombreMembres: 6,
          etatTexte: 'À vous de voter',
          actionRequise: true,
        ),
        ResumeTable(
          id: 't2',
          nom: 'Ski',
          nombreMembres: 3,
          etatTexte: 'Rien de nouveau',
          actionRequise: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranTables(
          tableService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Marbella'), findsOneWidget);
    expect(find.text('À vous de voter'), findsOneWidget);
    expect(find.text('Ski'), findsOneWidget);
    expect(find.text('Rien de nouveau'), findsOneWidget);
  });

  testWidgets('affiche une invitation et permet de l\'accepter', (tester) async {
    final service = _FauxTableService(
      invitations: const [
        ResumeTable(
          id: 't3',
          nom: 'Famille',
          nombreMembres: 0,
          etatTexte: 'Invitation en attente',
          actionRequise: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranTables(
          tableService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Famille'), findsOneWidget);
    expect(find.text('Accepter'), findsOneWidget);

    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();

    expect(service.invitationsAcceptees, ['t3']);
    expect(find.text('Famille'), findsNothing);
  });

  testWidgets('refuser une invitation la retire de la liste', (tester) async {
    final service = _FauxTableService(
      invitations: const [
        ResumeTable(
          id: 't4',
          nom: 'Les gars',
          nombreMembres: 0,
          etatTexte: 'Invitation en attente',
          actionRequise: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranTables(
          tableService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Refuser'));
    await tester.pumpAndSettle();

    expect(service.invitationsRefusees, ['t4']);
    expect(find.text('Les gars'), findsNothing);
  });
}
