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

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<int> nombreDemandesEnAttente() async => 0;

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
  List<SouvenirFeed> souvenirs,
) async {
  final service = _FauxSouvenirService(souvenirs);
  await mockNetworkImagesFor(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: TablTheme.sombre(),
        home: EcranProfil(
          authService: _FauxAuthService(),
          abonnementService: _FauxAbonnementService(),
          souvenirService: service,
          utilisateur: _moi,
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

  testWidgets('le menu "⋯" propose "Modifier le partage"', (tester) async {
    await _ouvrirProfil(tester, [_monSouvenir('1', 'Bibo')]);

    await tester.tap(find.byTooltip('Options'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier le partage'), findsOneWidget);
  });

  testWidgets('aucune publication : message dédié', (tester) async {
    await _ouvrirProfil(tester, []);

    expect(find.text("Vous n'avez encore rien publié."), findsOneWidget);
    expect(find.text('Aucun moment'), findsOneWidget);
  });
}
