import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_modifier_partage.dart';

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService({
    required this._partagerAvecCercle,
    List<String> tableIds = const [],
  }) : _tableIds = List.of(tableIds);

  bool _partagerAvecCercle;
  List<String> _tableIds;
  final List<Map<String, Object?>> appelsModifierPartage = [];

  @override
  Future<({bool partagerAvecCercle, List<String> tableIds})> partageActuel(
    String souvenirId,
  ) async => (partagerAvecCercle: _partagerAvecCercle, tableIds: _tableIds);

  @override
  Future<List<String>> modifierPartage(
    String souvenirId, {
    required bool partagerAvecCercle,
    required List<String> tableIds,
  }) async {
    appelsModifierPartage.add({
      'souvenirId': souvenirId,
      'partagerAvecCercle': partagerAvecCercle,
      'tableIds': tableIds,
    });
    _partagerAvecCercle = partagerAvecCercle;
    _tableIds = tableIds;
    return const [];
  }

  @override
  Future<String> enregistrerBrouillon({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
  }) => throw UnimplementedError();
  @override
  Future<List<String>> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    bool partagerAvecCercle = true,
    List<String> tableIds = const [],
  }) => throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> feed() => throw UnimplementedError();
  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) =>
      throw UnimplementedError();
  @override
  Future<List<Commentaire>> commentaires(String souvenirId) =>
      throw UnimplementedError();
  @override
  Future<void> commenter(String souvenirId, String texte) =>
      throw UnimplementedError();
  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
}

class _FauxTableService implements TableService {
  _FauxTableService({this.tables = const []});

  final List<ResumeTable> tables;

  @override
  Future<List<ResumeTable>> mesTables() async => tables;

  @override
  Future<List<ResumeTable>> mesInvitations() => throw UnimplementedError();
  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) => throw UnimplementedError();
  @override
  Future<GroupeTable> table(String tableId) => throw UnimplementedError();
  @override
  Future<void> accepterInvitation(String tableId) => throw UnimplementedError();
  @override
  Future<void> refuserInvitation(String tableId) => throw UnimplementedError();
  @override
  Future<void> inviter(String tableId, String profilId) =>
      throw UnimplementedError();
  @override
  Future<void> quitter(String tableId) => throw UnimplementedError();
  @override
  Future<void> retirerMembre(String tableId, String profilId) =>
      throw UnimplementedError();
  @override
  Future<void> renommer(String tableId, String nom) =>
      throw UnimplementedError();
  @override
  Future<void> supprimer(String tableId) => throw UnimplementedError();
  @override
  Future<
    ({
      List<ExperienceHistoireTable> experiences,
      List<RecurrenceTable> laOuOnRevient,
    })
  >
  histoire(String tableId) => throw UnimplementedError();
  @override
  Future<List<PropositionTable>> propositions(String tableId) =>
      throw UnimplementedError();
  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) => throw UnimplementedError();
  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) =>
      throw UnimplementedError();
  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) =>
      throw UnimplementedError();
  @override
  Future<DetailProposition> detailProposition(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<void> definirDatesCandidates(
    String propositionId,
    List<DateTime> datesLocales,
  ) => throw UnimplementedError();
  @override
  Future<void> soumettreDisponibilites(
    String propositionId,
    List<String> dateCandidateIds,
  ) => throw UnimplementedError();
  @override
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  }) => throw UnimplementedError();
  @override
  Future<void> ajouterHeure(String propositionId, String heure) =>
      throw UnimplementedError();
  @override
  Future<void> replanifier(String propositionId) => throw UnimplementedError();
  @override
  Future<void> annulerProposition(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) =>
      throw UnimplementedError();
  @override
  Future<void> supprimerMessageOrganisation(String messageId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('charge le partage actuel et l\'affiche', (tester) async {
    final service = _FauxSouvenirService(
      partagerAvecCercle: true,
      tableIds: const ['table-1'],
    );
    final tableService = _FauxTableService(
      tables: const [
        ResumeTable(
          id: 'table-1',
          nom: 'Marbella',
          nombreMembres: 3,
          etatTexte: 'Rien de nouveau',
          actionRequise: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranModifierPartage(
          souvenirId: 'souvenir-1',
          souvenirService: service,
          tableService: tableService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Visible par votre cercle et les membres de Marbella.'),
      findsOneWidget,
    );
  });

  testWidgets('ajouter une Table (pas de réduction) : sauvegarde directe', (
    tester,
  ) async {
    final service = _FauxSouvenirService(partagerAvecCercle: true);
    final tableService = _FauxTableService(
      tables: const [
        ResumeTable(
          id: 'table-1',
          nom: 'Marbella',
          nombreMembres: 3,
          etatTexte: 'Rien de nouveau',
          actionRequise: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranModifierPartage(
          souvenirId: 'souvenir-1',
          souvenirService: service,
          tableService: tableService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Marbella'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    // Pas de dialogue : un ajout n'est jamais une réduction (règle 81).
    expect(find.text('Réduire le partage ?'), findsNothing);
    expect(service.appelsModifierPartage.single['tableIds'], ['table-1']);
  });

  testWidgets(
    'retirer une Table : avertissement avant sauvegarde (règle 81)',
    (tester) async {
      final service = _FauxSouvenirService(
        partagerAvecCercle: true,
        tableIds: const ['table-1'],
      );
      final tableService = _FauxTableService(
        tables: const [
          ResumeTable(
            id: 'table-1',
            nom: 'Famille',
            nombreMembres: 4,
            etatTexte: 'Rien de nouveau',
            actionRequise: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranModifierPartage(
            souvenirId: 'souvenir-1',
            souvenirService: service,
            tableService: tableService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(find.text('Réduire le partage ?'), findsOneWidget);
      expect(service.appelsModifierPartage, isEmpty);

      await tester.tap(find.text('Confirmer').last);
      await tester.pumpAndSettle();

      expect(service.appelsModifierPartage.single['tableIds'], <String>[]);
    },
  );

  testWidgets(
    'Cercle → Garder pour moi : avertissement avant sauvegarde (règle 82)',
    (tester) async {
      final service = _FauxSouvenirService(partagerAvecCercle: true);

      await tester.pumpWidget(
        MaterialApp(
          home: EcranModifierPartage(
            souvenirId: 'souvenir-1',
            souvenirService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Garder pour moi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmer'));
      await tester.pumpAndSettle();

      expect(
        find.text('Votre cercle ne pourra plus voir cette expérience.'),
        findsOneWidget,
      );
    },
  );
}
