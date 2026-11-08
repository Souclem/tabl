import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_table.dart';

class _FauxTableService implements TableService {
  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async => {for (final id in tableIds) id: <String>{}};

  _FauxTableService({
    required this._table,
    List<PropositionTable> propositions = const [],
    List<DecouverteTable> decouvertes = const [],
  }) : _propositions = List.of(propositions),
       _decouvertes = List.of(decouvertes);

  final GroupeTable _table;
  List<PropositionTable> _propositions;
  final List<DecouverteTable> _decouvertes;

  final List<({String tableId, String nom, String ville})> propositionsCreees = [];
  final List<({String id, bool go})> reponses = [];

  @override
  Future<GroupeTable> table(String tableId) async => _table;

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
  Future<List<PropositionTable>> propositions(String tableId) async =>
      List.of(_propositions);

  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) async {
    propositionsCreees.add((tableId: tableId, nom: nomRestaurant, ville: ville));
    final nouvelle = PropositionTable(
      id: 'p-nouvelle',
      restaurantId: 'r-nouveau',
      restaurantNom: nomRestaurant,
      ville: ville,
      proposePar: 'moi',
      parMoi: true,
      etatTexte: 'Proposé',
      active: true,
      nombreGo: 0,
    );
    _propositions = [..._propositions, nouvelle];
    return (proposition: nouvelle, dejaExistante: false);
  }

  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {
    reponses.add((id: propositionId, go: go));
  }

  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) async => List.of(_decouvertes);

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

class _FauxCarteService implements CarteService {
  final List<({String id, bool garder})> basculements = [];

  @override
  Future<List<LieuCarte>> lieuxReseau(
    ZoneCarte zone,
    FiltresCarte filtres, {
    ModeExplorer mode = ModeExplorer.cercle,
    int limite = nombreMaxLieuxCarte,
  }) async => [];

  @override
  Future<Map<String, String>> photos(Iterable<String> chemins) async => {};

  @override
  Future<String> idRestaurant(LieuCarte lieu) async => lieu.restaurantId!;

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) async {
    basculements.add((id: restaurantId, garder: envie));
  }
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

const _tableVide = GroupeTable(
  id: 't1',
  nom: 'Marbella',
  creeParMoi: true,
  jeSuisAdmin: true,
  membres: [
    MembreTable(
      profilId: 'moi',
      pseudo: 'moi',
      statut: StatutMembreTable.actif,
      estAdmin: true,
    ),
  ],
);

void main() {
  testWidgets('ouverture manuelle : Notre histoire par défaut, vide', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranTable(
          tableId: 't1',
          tableService: _FauxTableService(table: _tableVide),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Votre histoire commence ici.'), findsOneWidget);
  });

  testWidgets('On y va ? vide : CTA "Proposer un restaurant" toujours visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranTable(
          tableId: 't1',
          tableService: _FauxTableService(table: _tableVide),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('On y va ?'));
    await tester.pumpAndSettle();

    expect(find.text('Une adresse en tête ?'), findsOneWidget);
    expect(find.text('Proposer un restaurant'), findsOneWidget);
  });

  testWidgets('proposer un restaurant : ouvre le dialogue et appelle le service', (
    tester,
  ) async {
    final service = _FauxTableService(table: _tableVide);
    await tester.pumpWidget(
      MaterialApp(
        home: EcranTable(
          tableId: 't1',
          tableService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('On y va ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Proposer un restaurant'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget, reason: 'dialogue ouvert');
    expect(find.byType(TextField), findsNWidgets(2), reason: 'deux champs');

    await tester.enterText(find.byType(TextField).first, 'Bibo');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Marbella');
    await tester.pumpAndSettle();

    final boutons = find.widgetWithText(FilledButton, 'Proposer');
    expect(boutons, findsOneWidget, reason: 'bouton Proposer du dialogue');
    final widget = tester.widget<FilledButton>(boutons);
    expect(widget.onPressed, isNotNull, reason: 'bouton actif après saisie');

    await tester.tap(boutons);
    await tester.pumpAndSettle();

    expect(service.propositionsCreees, [(tableId: 't1', nom: 'Bibo', ville: 'Marbella')]);
    expect(find.text('Bibo'), findsOneWidget);
  });

  testWidgets('GO sur une proposition active appelle repondreProposition', (
    tester,
  ) async {
    final service = _FauxTableService(
      table: _tableVide,
      propositions: const [
        PropositionTable(
          id: 'p1',
          restaurantId: 'r1',
          restaurantNom: 'Bibo',
          ville: 'Marbella',
          proposePar: 'Thomas',
          parMoi: false,
          etatTexte: 'À vous de voter',
          active: true,
          nombreGo: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranTable(
          tableId: 't1',
          tableService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('On y va ?'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(service.reponses, [(id: 'p1', go: true)]);
  });

  testWidgets('à découvrir : Garder bascule via CarteService', (tester) async {
    final carteService = _FauxCarteService();
    final service = _FauxTableService(
      table: _tableVide,
      decouvertes: const [
        DecouverteTable(
          restaurantId: 'r2',
          restaurantNom: 'Casa Mono',
          ville: 'Marbella',
          pseudosConnaisseurs: ['Emma', 'Thomas'],
          dejaGardeParMoi: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranTable(
          tableId: 't1',
          tableService: service,
          abonnementService: _FauxAbonnementService(),
          carteService: carteService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('À découvrir'));
    await tester.pumpAndSettle();

    expect(
      find.text('Emma et Thomas connaissent cette adresse'),
      findsOneWidget,
    );

    await tester.tap(find.text('Garder'));
    await tester.pumpAndSettle();

    expect(carteService.basculements, [(id: 'r2', garder: true)]);
  });
}
