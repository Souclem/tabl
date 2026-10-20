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
  Future<CompteursProfil> compteurs(String profilId) async =>
      (moments: 2, abonnes: 12, abonnements: 7);

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

SouvenirFeed _monSouvenir(
  String id,
  String restaurant, {
  DateTime? date,
  Emotion? emotion,
}) {
  return SouvenirFeed(
    id: id,
    photoUrl: null,
    legende: 'Très bon.',
    restaurantNom: restaurant,
    ville: 'Bruxelles',
    moment: 'soir',
    dateVisite: date ?? DateTime(2026, 10, 3),
    auteurPseudo: 'clem',
    nombreReactions: 0,
    jaiReagi: false,
    nombreCommentaires: 0,
    estAMoi: true,
    emotion: emotion,
  );
}

Future<_FauxSouvenirService> _ouvrirProfil(
  WidgetTester tester,
  List<SouvenirFeed> souvenirs, {
  _FauxAbonnementService? abonnementService,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

/// Une tuile du journal, par ce qu'en lit un lecteur d'écran.
Finder _tuile(String restaurant) =>
    find.bySemanticsLabel(RegExp('^$restaurant, '));

void main() {
  testWidgets('en-tête : moments, abonnés et abonnements', (tester) async {
    final service = await _ouvrirProfil(tester, [
      _monSouvenir('1', 'Bibo'),
      _monSouvenir('2', 'Le Comptoir'),
    ]);

    expect(service.auteursDemandes, ['moi']);
    // Les chiffres montent jusqu'à leur valeur, sous leur libellé.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('MOMENTS'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('ABONNÉS'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('ABONNEMENTS'), findsOneWidget);
    // Plus d'adresse e-mail ni de « sur Tabl depuis ».
    expect(find.text('clem@tabl.app'), findsNothing);
  });

  testWidgets('journal : les moments du mois en grille, par mois', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    await _ouvrirProfil(tester, [
      _monSouvenir('1', 'Bibo'),
      _monSouvenir('2', 'Le Comptoir', date: DateTime(2026, 9, 12)),
    ]);

    expect(find.text('Octobre'), findsOneWidget);
    expect(find.text('Septembre'), findsOneWidget);
    expect(_tuile('Bibo'), findsOneWidget);
    expect(_tuile('Le Comptoir'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('toucher une photo l\'agrandit, la croix la renvoie', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    await _ouvrirProfil(tester, [_monSouvenir('1', 'Bibo')]);

    await mockNetworkImagesFor(() async {
      await tester.tap(_tuile('Bibo'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(TablVisionneuseMoment), findsOneWidget);
    expect(find.text('Bibo'), findsOneWidget);
    expect(find.text('«\u00A0Très bon.\u00A0»'), findsOneWidget);
    // Son propre moment : pas d'« Enregistrer », mais le menu « ⋯ ».
    expect(find.text('Enregistrer'), findsNothing);
    expect(find.byTooltip('Options'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(TablVisionneuseMoment), findsNothing);
    semantique.dispose();
  });

  testWidgets('"⋯" → "Qui peut voir" modifie l\'audience', (tester) async {
    final semantique = tester.ensureSemantics();
    final service = await _ouvrirProfil(tester, [_monSouvenir('1', 'Bibo')]);

    await mockNetworkImagesFor(() async {
      await tester.tap(_tuile('Bibo'));
      await tester.pumpAndSettle();
    });
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
    semantique.dispose();
  });

  testWidgets('Bilan : l\'année en chiffres', (tester) async {
    await _ouvrirProfil(tester, [
      _monSouvenir('1', 'Bibo'),
      _monSouvenir('2', 'Bibo', date: DateTime(2026, 9, 12)),
    ]);

    await tester.tap(find.text('Bilan'));
    await tester.pumpAndSettle();

    expect(find.text('Ton 2026'), findsOneWidget);
    expect(find.text('2 moments · 1 adresse · 1 ville'), findsOneWidget);
    expect(find.text('LÀ OÙ TU REVIENS'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('Bruxelles'), findsOneWidget);
  });

  testWidgets('Réglages : passer le profil en public demande confirmation', (
    tester,
  ) async {
    final abonnements = _FauxAbonnementService();
    await _ouvrirProfil(tester, [], abonnementService: abonnements);

    await tester.tap(find.byTooltip('Réglages'));
    await tester.pumpAndSettle();
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
    expect(find.text('Journal'), findsNothing);
  });
}
