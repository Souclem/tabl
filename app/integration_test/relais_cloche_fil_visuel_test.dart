import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_principal.dart';

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<List<ProfilPublic>> mesRelations() async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Le Fil : ce que le serveur rend change quand [publie] passe à vrai, et
/// [appelsFeed] compte les chargements.
class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  int appelsFeed = 0;
  bool publie = false;

  @override
  Future<List<SouvenirFeed>> feed() async {
    appelsFeed++;
    return [
      if (publie) _moment('2', 'Chez Nouveau'),
      _moment('1', 'Le Comptoir'),
    ];
  }

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

SouvenirFeed _moment(String id, String restaurantNom) => SouvenirFeed(
  id: id,
  photoUrl: null,
  legende: 'Onze petites assiettes.',
  restaurantNom: restaurantNom,
  ville: 'Paris',
  moment: 'soir',
  dateVisite: DateTime(2026, 8, 20),
  auteurPseudo: 'martin',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  auteurId: 'martin-id',
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('relais cloche vers Fil', (tester) async {
    final souvenirs = _FauxSouvenirService();
    ResultatCloche? resultat;
    await tester.pumpWidget(
      MaterialApp(
        home: EcranPrincipal(
          authService: _FauxAuthService(),
          abonnementService: _FauxAbonnementService(),
          souvenirService: souvenirs,
          utilisateur: const Utilisateur(
            id: 'moi',
            email: 'moi@exemple.com',
            pseudo: 'moi',
          ),
          ouvrirParcours: (_) async => resultat,
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> capture(String nom) async {
      await tester.pump(const Duration(milliseconds: 500));
      debugPrint('CAPTURE:$nom');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    await tester.tap(find.bySemanticsLabel('Profil'));
    await tester.pumpAndSettle();
    await capture('relais_1_depart_profil');

    souvenirs.publie = true;
    resultat = const ResultatCloche(IssueCloche.publie);
    await tester.tap(find.bySemanticsLabel('Publier un moment'));
    await tester.pumpAndSettle();
    await capture('relais_2_publie_fil');

    await tester.tap(find.bySemanticsLabel('Profil'));
    await tester.pumpAndSettle();
    resultat = const ResultatCloche(
      IssueCloche.publie,
      tablesEnEchec: ['a', 'b'],
    );
    await tester.tap(find.bySemanticsLabel('Publier un moment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await capture('relais_3_tables_en_echec');

    await tester.pumpAndSettle(const Duration(seconds: 6));
    await tester.tap(find.bySemanticsLabel('Profil'));
    await tester.pumpAndSettle();
    resultat = const ResultatCloche(IssueCloche.brouillonGarde);
    await tester.tap(find.bySemanticsLabel('Publier un moment'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await capture('relais_4_brouillon_garde');
  });
}
