import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_profil_autre.dart';

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService(this.publications);

  final List<SouvenirFeed> publications;
  final List<String> auteursDemandes = [];

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async {
    auteursDemandes.add(auteurId);
    return publications;
  }

  /// Mes moments où elle est taguée.
  List<SouvenirFeed> mesMomentsAvecElle = const [];

  @override
  Future<List<SouvenirFeed>> mesMomentsAvec(String profilId) async =>
      mesMomentsAvecElle;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  _FauxAbonnementService({required this.estPrive, required this.statut});

  final bool estPrive;
  StatutAbonnement statut;
  final List<String> suivis = [];
  final List<String> arretes = [];

  @override
  Future<ProfilVisite> profil(String id) async =>
      ProfilVisite(id: id, pseudo: 'emma', estPrive: estPrive, statut: statut);

  @override
  Future<CompteursProfil> compteurs(String profilId) async =>
      (moments: 5, abonnes: 40, abonnements: 31);

  @override
  Future<StatutAbonnement> suivre(String suiviId) async {
    suivis.add(suiviId);
    statut = estPrive
        ? StatutAbonnement.demandeEnvoyee
        : StatutAbonnement.abonne;
    return statut;
  }

  @override
  Future<void> arreterDeSuivre(String suiviId) async {
    arretes.add(suiviId);
    statut = StatutAbonnement.aucun;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SouvenirFeed _publication(
  String id,
  String restaurant, {
  List<PersonnePresente> presents = const [],
}) => SouvenirFeed(
  id: id,
  presents: presents,
  photoUrl: null,
  legende: 'Très bon.',
  restaurantNom: restaurant,
  ville: 'Liège',
  moment: 'soir',
  dateVisite: DateTime(2026, 9, 12),
  auteurPseudo: 'emma',
  auteurId: 'emma-id',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
);

Future<void> _ouvrir(
  WidgetTester tester, {
  required _FauxAbonnementService abonnements,
  required _FauxSouvenirService souvenirs,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: EcranProfilAutre(
          profilId: 'emma-id',
          pseudo: 'emma',
          abonnementService: abonnements,
          souvenirService: souvenirs,
        ),
      ),
    );
    await tester.pumpAndSettle();
  });
}

/// Une tuile du journal, par ce qu'en lit un lecteur d'écran.
Finder _tuile(String restaurant) =>
    find.bySemanticsLabel(RegExp('^$restaurant, '));

void main() {
  testWidgets('profil public : chiffres, journal, et un moment agrandi', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    final souvenirs = _FauxSouvenirService([
      _publication('1', 'Bibo'),
      _publication('2', 'Le Comptoir'),
    ]);
    await _ouvrir(
      tester,
      abonnements: _FauxAbonnementService(
        estPrive: false,
        statut: StatutAbonnement.aucun,
      ),
      souvenirs: souvenirs,
    );

    expect(souvenirs.auteursDemandes, ['emma-id']);
    expect(find.text('emma'), findsWidgets);
    // Les moments que je vois, ses abonnés et abonnements.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('31'), findsOneWidget);
    expect(find.text('Suivre'), findsOneWidget);
    expect(find.text('Septembre'), findsOneWidget);

    await mockNetworkImagesFor(() async {
      await tester.tap(_tuile('Bibo'));
      await tester.pumpAndSettle();
    });
    expect(find.byType(TablVisionneuseMoment), findsOneWidget);
    // Pas de « ⋯ » sur le moment de quelqu'un d'autre, mais Enregistrer.
    expect(find.byTooltip('Options'), findsNothing);
    expect(find.text('Enregistrer'), findsOneWidget);
    semantique.dispose();
  });

  testWidgets('« Toi & emma » : nos moments à deux, à revoir', (tester) async {
    final semantique = tester.ensureSemantics();
    const moi = PersonnePresente(id: 'moi', pseudo: 'clem', estMoi: true);
    final souvenirs = _FauxSouvenirService([
      _publication('1', 'Bibo', presents: const [moi]),
      _publication('2', 'Le Comptoir'),
    ]);
    await _ouvrir(
      tester,
      abonnements: _FauxAbonnementService(
        estPrive: false,
        statut: StatutAbonnement.abonne,
      ),
      souvenirs: souvenirs,
    );

    expect(find.text('Toi & emma'), findsOneWidget);
    expect(find.textContaining('1 moment ensemble'), findsOneWidget);

    await tester.tap(find.text('Revoir vos moments'));
    await tester.pumpAndSettle();
    expect(find.text('Vos moments à deux'), findsOneWidget);
    expect(_tuile('Bibo'), findsOneWidget);
    expect(_tuile('Le Comptoir'), findsNothing);
    semantique.dispose();
  });

  testWidgets('profil privé non suivi : rien que l\'en-tête, puis demande', (
    tester,
  ) async {
    final souvenirs = _FauxSouvenirService([_publication('1', 'Bibo')]);
    final abonnements = _FauxAbonnementService(
      estPrive: true,
      statut: StatutAbonnement.aucun,
    );
    await _ouvrir(tester, abonnements: abonnements, souvenirs: souvenirs);

    expect(find.text('Ce profil est privé'), findsOneWidget);
    // Son nombre de moments reste visible, comme sur Instagram.
    expect(find.text('5'), findsOneWidget);
    // Ses publications ne sont même pas demandées.
    expect(souvenirs.auteursDemandes, isEmpty);

    await tester.tap(find.text('Suivre'));
    await tester.pumpAndSettle();

    expect(abonnements.suivis, ['emma-id']);
    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(find.text('Ce profil est privé'), findsOneWidget);
  });

  testWidgets('profil privé suivi : visible ; ne plus suivre le recache', (
    tester,
  ) async {
    final semantique = tester.ensureSemantics();
    final souvenirs = _FauxSouvenirService([_publication('1', 'Bibo')]);
    final abonnements = _FauxAbonnementService(
      estPrive: true,
      statut: StatutAbonnement.abonne,
    );
    await _ouvrir(tester, abonnements: abonnements, souvenirs: souvenirs);

    expect(_tuile('Bibo'), findsOneWidget);

    await tester.tap(find.text('Abonné'));
    await tester.pumpAndSettle();
    expect(find.text('Ne plus suivre emma ?'), findsOneWidget);
    await tester.tap(find.text('Ne plus suivre'));
    await tester.pumpAndSettle();

    expect(abonnements.arretes, ['emma-id']);
    expect(find.text('Ce profil est privé'), findsOneWidget);
    expect(_tuile('Bibo'), findsNothing);
    expect(find.text('Suivre'), findsOneWidget);
    semantique.dispose();
  });
}
