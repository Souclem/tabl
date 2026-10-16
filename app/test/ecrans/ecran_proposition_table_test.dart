import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_proposition_table.dart';

class _FauxTableService implements TableService {
  _FauxTableService(this.detail);

  DetailProposition detail;

  final List<({String id, bool go})> reponses = [];
  final List<({String id, List<DateTime> dates})> datesDefinies = [];
  final List<({String id, String dateCandidateId, String fuseau})> confirmations = [];
  final List<({String id, String heure})> heuresAjoutees = [];
  final List<String> replanifications = [];
  final List<String> annulations = [];

  @override
  Future<DetailProposition> detailProposition(String propositionId) async => detail;

  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) async {
    reponses.add((id: propositionId, go: go));
  }

  @override
  Future<void> definirDatesCandidates(String propositionId, List<DateTime> datesLocales) async {
    datesDefinies.add((id: propositionId, dates: datesLocales));
  }

  @override
  Future<void> soumettreDisponibilites(String propositionId, List<String> dateCandidateIds) async {}

  @override
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  }) async {
    confirmations.add((id: propositionId, dateCandidateId: dateCandidateId, fuseau: fuseauHoraire));
  }

  @override
  Future<void> ajouterHeure(String propositionId, String heure) async {
    heuresAjoutees.add((id: propositionId, heure: heure));
  }

  @override
  Future<void> replanifier(String propositionId) async {
    replanifications.add(propositionId);
  }

  @override
  Future<void> annulerProposition(String propositionId) async {
    annulations.add(propositionId);
  }

  @override
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) async => const [];
  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) async {}
  @override
  Future<void> supprimerMessageOrganisation(String messageId) async {}

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

DetailProposition _detail({
  bool active = true,
  String etatTexte = 'Choisissez vos dates',
  int nombreGo = 0,
  bool? monInteret,
  bool parMoi = false,
  List<CandidatDateProposition> candidats = const [],
  int progressionSoumis = 0,
  int progressionEligibles = 0,
  ConfirmationProposition? confirmation,
}) {
  return DetailProposition(
    id: 'p-1',
    restaurantNom: 'Bibo',
    ville: 'Marbella',
    proposePar: 'Thomas',
    parMoi: parMoi,
    active: active,
    etatTexte: etatTexte,
    nombreGo: nombreGo,
    monInteret: monInteret,
    candidats: candidats,
    progressionSoumis: progressionSoumis,
    progressionEligibles: progressionEligibles,
    moiAiSoumisReponse: false,
    confirmation: confirmation,
    peutAccederChat: false,
    nombreMessages: 0,
  );
}

void main() {
  Future<void> pump(WidgetTester tester, TableService service) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranPropositionTable(propositionId: 'p-1', tableService: service),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('proposition terminale : affiche seulement le texte d\'état', (tester) async {
    final service = _FauxTableService(_detail(active: false, etatTexte: 'Annulée'));
    await pump(tester, service);

    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('GO'), findsNothing);
  });

  testWidgets('aucun GO : GO/Je passe visibles, tap GO appelle le service', (tester) async {
    final service = _FauxTableService(_detail());
    await pump(tester, service);

    expect(find.text('GO'), findsOneWidget);
    await tester.tap(find.text('GO'));
    await tester.pumpAndSettle();

    expect(service.reponses, [(id: 'p-1', go: true)]);
  });

  testWidgets('nombreGo > 0, pas de dates, creator : "Proposer des dates"', (tester) async {
    final service = _FauxTableService(_detail(nombreGo: 3, parMoi: true, monInteret: true));
    await pump(tester, service);

    expect(find.text('Proposer des dates'), findsOneWidget);
  });

  testWidgets('nombreGo > 0, pas de dates, membre : message d\'attente (règle 6)', (tester) async {
    final service = _FauxTableService(_detail(nombreGo: 3, monInteret: true));
    await pump(tester, service);

    expect(find.text('En attente de dates de la part de Thomas.'), findsOneWidget);
    expect(find.text('Proposer des dates'), findsNothing);
  });

  testWidgets('une date à 100%, creator : bouton Confirmer appelle confirmerDate', (tester) async {
    final candidat = CandidatDateProposition(
      id: 'd-1',
      date: DateTime(2026, 9, 12),
      disponibles: 4,
      eligibles: 4,
      moiDisponible: true,
      passee: false,
    );
    final service = _FauxTableService(
      _detail(
        nombreGo: 4,
        parMoi: true,
        monInteret: true,
        candidats: [candidat],
        progressionSoumis: 4,
        progressionEligibles: 4,
      ),
    );
    await pump(tester, service);

    expect(find.text('Confirmer'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(service.confirmations, hasLength(1));
    expect(service.confirmations.first.dateCandidateId, 'd-1');
  });

  testWidgets('aucune date commune, creator : meilleurs compromis avec "Confirmer quand même"', (
    tester,
  ) async {
    final candidat = CandidatDateProposition(
      id: 'd-1',
      date: DateTime(2026, 9, 12),
      disponibles: 5,
      eligibles: 6,
      moiDisponible: true,
      passee: false,
    );
    final service = _FauxTableService(
      _detail(
        nombreGo: 6,
        parMoi: true,
        monInteret: true,
        candidats: [candidat],
        progressionSoumis: 6,
        progressionEligibles: 6,
      ),
    );
    await pump(tester, service);

    expect(find.text('Aucune date ne convient à tout le monde.'), findsOneWidget);
    expect(find.text('Confirmer quand même'), findsOneWidget);

    await tester.tap(find.text('Confirmer quand même'));
    await tester.pumpAndSettle();
    // Règle 18 : avertissement avant confirmation d'un compromis.
    expect(find.text('Confirmer quand même ?'), findsOneWidget);
  });

  testWidgets('confirmée sans heure : "Heure à confirmer" + bouton pour le creator', (
    tester,
  ) async {
    final service = _FauxTableService(
      _detail(
        nombreGo: 4,
        parMoi: true,
        monInteret: true,
        confirmation: ConfirmationProposition(
          date: DateTime(2026, 9, 12),
          heure: null,
          fuseauHoraire: 'Europe/Paris',
        ),
      ),
    );
    await pump(tester, service);

    expect(find.text('Heure à confirmer'), findsOneWidget);
    expect(find.text('Ajouter une heure'), findsOneWidget);
  });

  testWidgets('confirmée avec heure : "Prévu ... à HH:mm"', (tester) async {
    final service = _FauxTableService(
      _detail(
        nombreGo: 4,
        confirmation: ConfirmationProposition(
          date: DateTime(2026, 9, 12),
          heure: '20:30',
          fuseauHoraire: 'Europe/Paris',
        ),
      ),
    );
    await pump(tester, service);

    expect(find.textContaining('à 20:30'), findsOneWidget);
    // Membre, pas creator : pas de Replanifier/Annuler.
    expect(find.text('Annuler la sortie'), findsNothing);
  });
}
