import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_profil.dart';

/// Seules les méthodes réellement appelées par le Profil sont
/// implémentées ; toute autre lève, ce qui signale un appel inattendu.
class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService(this.mesSouvenirs);

  final List<SouvenirFeed> mesSouvenirs;
  final List<String> auteursDemandes = [];

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async {
    auteursDemandes.add(auteurId);
    return mesSouvenirs;
  }

  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) async {}

  final List<AudienceSouvenir> audiencesModifiees = [];

  @override
  Future<({AudienceSouvenir audience, Set<String> amisTaguesIds})>
  audienceActuelle(String souvenirId) async =>
      (audience: AudienceSouvenir.toutLeMonde, amisTaguesIds: <String>{});

  @override
  Future<List<String>> modifierAudience(
    String souvenirId,
    AudienceSouvenir audience,
  ) async {
    audiencesModifiees.add(audience);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  final List<bool> reglagesPrive = [];

  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<bool> monProfilEstPrive() async => true;

  @override
  Future<void> definirProfilPrive(bool prive) async => reglagesPrive.add(prive);

  @override
  Future<Set<String>> mesAbonnesIds() async => {'sarah-id'};

  @override
  Future<List<ProfilPublic>> mesRelations() async => const [
    ProfilPublic(id: 'sarah-id', pseudo: 'sarah', statut: StatutAbonnement.abonne),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxTableService implements TableService {
  @override
  Future<List<ResumeTable>> mesTables() async => [];

  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _moi = Utilisateur(id: 'moi', email: 'clem@tabl.app', pseudo: 'clem');

SouvenirFeed _monSouvenir(String id, String restaurant) {
  return SouvenirFeed(
    id: id,
    photoUrl: null,
    legende: null,
    restaurantNom: restaurant,
    ville: 'Bruxelles',
    moment: 'soir',
    dateVisite: DateTime(2026, 10, 3),
    auteurPseudo: 'clem',
    nombreReactions: 0,
    jaiReagi: false,
    nombreCommentaires: 0,
    estAMoi: true,
  );
}

Future<_FauxSouvenirService> _ouvrirProfil(
  WidgetTester tester,
  List<SouvenirFeed> souvenirs, {
  _FauxAbonnementService? abonnementService,
}) async {
  final service = _FauxSouvenirService(souvenirs);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: EcranProfil(
          authService: _FauxAuthService(),
          abonnementService: abonnementService ?? _FauxAbonnementService(),
          souvenirService: service,
          utilisateur: _moi,
          tableService: _FauxTableService(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
  return service;
}

void main() {
  testWidgets('affiche ses propres publications, sans "Enregistrer"', (
    tester,
  ) async {
    final service = await _ouvrirProfil(tester, [
      _monSouvenir('1', 'Bibo'),
      _monSouvenir('2', 'Le Comptoir'),
    ]);

    expect(service.auteursDemandes, ['moi']);
    expect(find.text('2 moments'), findsOneWidget);
    expect(find.text('Bibo'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Le Comptoir'), 300);
    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(find.text('Enregistrer'), findsNothing);
  });

  testWidgets('une publication se déplie sur place, puis se réduit', (
    tester,
  ) async {
    await _ouvrirProfil(tester, [
      _monSouvenir('1', 'Bibo'),
      _monSouvenir('2', 'Le Comptoir'),
    ]);

    // Compactes : pas de "⋯", pas de "Réduire".
    expect(find.byTooltip('Options'), findsNothing);
    expect(find.text('Réduire'), findsNothing);

    await tester.tap(find.text('Bibo'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire'), findsOneWidget);
    expect(find.byTooltip('Options'), findsOneWidget);
    // Toujours sur le profil : pas de nouvelle page.
    expect(find.text('2 moments'), findsOneWidget);

    await tester.tap(find.text('Réduire'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire'), findsNothing);
    expect(find.byTooltip('Options'), findsNothing);
  });

  testWidgets('"⋯" → "Qui peut voir" modifie l\'audience sans changer de page', (
    tester,
  ) async {
    final service = await _ouvrirProfil(tester, [_monSouvenir('1', 'Bibo')]);

    // Les "⋯" sont sur la publication dépliée.
    await tester.tap(find.text('Bibo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qui peut voir'));
    await tester.pumpAndSettle();

    expect(find.text('Qui peut voir ce moment ?'), findsOneWidget);
    expect(find.text('La personne qui vous suit'), findsOneWidget);

    await tester.tap(find.text('Seulement…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sarah'));
    await tester.pumpAndSettle();
    expect(find.text('Visible par 1 personne'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();

    final audience = service.audiencesModifiees.single;
    expect(audience.mode, ModeAudience.seulement);
    expect(audience.personneIds, {'sarah-id'});
    expect(find.text('Audience mise à jour.'), findsOneWidget);
  });

  testWidgets('passer le profil en public demande confirmation', (
    tester,
  ) async {
    final abonnements = _FauxAbonnementService();
    await _ouvrirProfil(tester, [], abonnementService: abonnements);

    await tester.ensureVisible(find.text('Profil privé'));
    await tester.tap(find.text('Profil privé'));
    await tester.pumpAndSettle();
    expect(find.text('Rendre votre profil public ?'), findsOneWidget);

    await tester.tap(find.text('Rendre public'));
    await tester.pumpAndSettle();

    expect(abonnements.reglagesPrive, [false]);
    expect(
      find.textContaining('Tous les utilisateurs de Tabl peuvent voir'),
      findsOneWidget,
    );
  });

  testWidgets('aucune publication : message dédié', (tester) async {
    await _ouvrirProfil(tester, []);

    expect(find.text("Vous n'avez encore rien publié."), findsOneWidget);
    expect(find.text('Aucun moment'), findsOneWidget);
  });
}
