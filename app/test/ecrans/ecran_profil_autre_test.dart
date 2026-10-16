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

SouvenirFeed _publication(String id, String restaurant) => SouvenirFeed(
  id: id,
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

void main() {
  testWidgets('profil public : ses publications, qui se déplient sur place', (
    tester,
  ) async {
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
    expect(find.text('emma'), findsOneWidget);
    expect(find.text('2 moments'), findsOneWidget);
    expect(find.text('Suivre'), findsOneWidget);

    await tester.tap(find.text('Bibo'));
    await tester.pumpAndSettle();
    expect(find.text('Réduire'), findsOneWidget);
    // Pas de "⋯" sur le profil de quelqu'un d'autre.
    expect(find.byTooltip('Options'), findsNothing);
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
    expect(find.text('Bibo'), findsNothing);
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
    final souvenirs = _FauxSouvenirService([_publication('1', 'Bibo')]);
    final abonnements = _FauxAbonnementService(
      estPrive: true,
      statut: StatutAbonnement.abonne,
    );
    await _ouvrir(tester, abonnements: abonnements, souvenirs: souvenirs);

    expect(find.text('Bibo'), findsOneWidget);

    await tester.tap(find.text('Abonné'));
    await tester.pumpAndSettle();
    expect(find.text('Ne plus suivre emma ?'), findsOneWidget);
    await tester.tap(find.text('Ne plus suivre'));
    await tester.pumpAndSettle();

    expect(abonnements.arretes, ['emma-id']);
    expect(find.text('Ce profil est privé'), findsOneWidget);
    expect(find.text('Bibo'), findsNothing);
    expect(find.text('Suivre'), findsOneWidget);
  });
}
