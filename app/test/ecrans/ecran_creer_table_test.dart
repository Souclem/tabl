import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_creer_table.dart';

class _FauxTableService implements TableService {
  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async => {for (final id in tableIds) id: <String>{}};

  final List<({String nom, String? emoji, List<String> membres})> appelsCreer = [];

  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) async {
    appelsCreer.add((nom: nom, emoji: emoji, membres: membresInvitesIds));
    return GroupeTable(
      id: 't-nouvelle',
      nom: nom,
      creeParMoi: true,
      jeSuisAdmin: true,
      membres: const [],
    );
  }

  @override
  Future<List<ResumeTable>> mesTables() async => [];
  @override
  Future<List<ResumeTable>> mesInvitations() async => [];
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
  histoire(String tableId) async =>
      (experiences: const <ExperienceHistoireTable>[], laOuOnRevient: const <RecurrenceTable>[]);
  @override
  Future<List<PropositionTable>> propositions(String tableId) async => [];
  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async => throw UnimplementedError();
  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {}
  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) async => [];
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
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) async => [];
  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) async {}
  @override
  Future<void> supprimerMessageOrganisation(String messageId) async {}
}

class _FauxAbonnementService implements AbonnementService {
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

  _FauxAbonnementService({this.amis = const []});

  final List<ProfilPublic> amis;

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
  Future<List<ProfilPublic>> mesRelations() async => amis;
}

/// Pousse EcranCreerTable sur une pile de navigation réelle (pour que
/// `Navigator.pop(true)` ait un écran en dessous, comme en vrai — poussé
/// depuis EcranTables).
Future<void> _ouvrir(
  WidgetTester tester,
  TableService tableService,
  AbonnementService abonnementService,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => EcranCreerTable(
                  tableService: tableService,
                  abonnementService: abonnementService,
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
}

void main() {
  testWidgets('le bouton Créer reste inactif tant qu\'aucun nom n\'est saisi', (
    tester,
  ) async {
    await _ouvrir(tester, _FauxTableService(), _FauxAbonnementService());

    final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(bouton.onPressed, isNull);
  });

  testWidgets('créer une Table avec un membre sélectionné appelle le service', (
    tester,
  ) async {
    final service = _FauxTableService();
    final abonnements = _FauxAbonnementService(
      amis: const [
        ProfilPublic(id: 'a1', pseudo: 'emma', statut: StatutAbonnement.abonne),
      ],
    );

    await _ouvrir(tester, service, abonnements);

    await tester.enterText(find.byType(TextField).first, 'Marbella');
    await tester.pump();

    await tester.tap(find.text('emma'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Créer'));
    await tester.pumpAndSettle();

    expect(service.appelsCreer, hasLength(1));
    expect(service.appelsCreer.single.nom, 'Marbella');
    expect(service.appelsCreer.single.emoji, isNull);
    expect(service.appelsCreer.single.membres, ['a1']);
  });
}
