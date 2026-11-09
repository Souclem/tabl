import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_feed.dart';
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
  late _FauxSouvenirService souvenirs;
  ResultatCloche? resultatDuParcours;
  var parcoursOuverts = 0;

  setUp(() {
    souvenirs = _FauxSouvenirService();
    resultatDuParcours = null;
    parcoursOuverts = 0;
  });

  /// L'écran principal dont le parcours de création rend [resultatDuParcours].
  Future<void> demarrer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
          ouvrirParcours: (_) async {
            parcoursOuverts++;
            return resultatDuParcours;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int ongletAffiche(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

  Future<void> aller(WidgetTester tester, String libelle) async {
    await tester.tap(find.bySemanticsLabel(libelle));
    await tester.pumpAndSettle();
  }

  /// Publie depuis le profil, pour que le retour au Fil se voie.
  Future<void> publierDepuisLeProfil(
    WidgetTester tester,
    ResultatCloche? resultat,
  ) async {
    await demarrer(tester);
    await aller(tester, 'Profil');
    expect(ongletAffiche(tester), TablOnglet.profil.index);
    resultatDuParcours = resultat;
    await aller(tester, 'Publier un moment');
    expect(parcoursOuverts, 1);
  }

  for (final issue in [IssueCloche.publie, IssueCloche.dejaPublie]) {
    testWidgets('$issue : retour au Fil rafraîchi, le nouveau moment en haut, '
        'sans message', (tester) async {
      await demarrer(tester);
      expect(find.text('Chez Nouveau'), findsNothing);
      await aller(tester, 'Profil');
      souvenirs.publie = true;
      resultatDuParcours = ResultatCloche(issue);

      await aller(tester, 'Publier un moment');

      expect(ongletAffiche(tester), TablOnglet.feed.index);
      expect(souvenirs.appelsFeed, 2);
      expect(find.byType(EcranFeed), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      final nouveau = tester.getTopLeft(find.text('Chez Nouveau')).dy;
      final ancien = tester.getTopLeft(find.text('Le Comptoir')).dy;
      expect(nouveau, lessThan(ancien));
    });
  }

  testWidgets('publié, mais des Tables en échec : le Fil, et un message '
      'discret (jamais un succès sans réserve)', (tester) async {
    await publierDepuisLeProfil(
      tester,
      const ResultatCloche(IssueCloche.publie, tablesEnEchec: ['t1', 't2']),
    );

    expect(ongletAffiche(tester), TablOnglet.feed.index);
    expect(souvenirs.appelsFeed, 2);
    expect(
      find.text('Publié, mais impossible de le partager avec 2 Tables.'),
      findsOneWidget,
    );
  });

  testWidgets('Modifier : on reste où l\'on est, rien ne bouge', (
    tester,
  ) async {
    await publierDepuisLeProfil(
      tester,
      const ResultatCloche(IssueCloche.modifier),
    );

    expect(ongletAffiche(tester), TablOnglet.profil.index);
    expect(souvenirs.appelsFeed, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('parcours quitté avant la cloche : rien ne bouge', (
    tester,
  ) async {
    await publierDepuisLeProfil(tester, null);

    expect(ongletAffiche(tester), TablOnglet.profil.index);
    expect(souvenirs.appelsFeed, 1);
    expect(find.byType(SnackBar), findsNothing);
  });

  final gardes = {
    IssueCloche.annule:
        'Publication annulée. Votre moment est gardé sur ce téléphone.',
    IssueCloche.brouillonGarde: 'Votre moment est gardé sur ce téléphone.',
    IssueCloche.enAttente: 'Votre moment sera envoyé dès que possible.',
  };
  for (final entree in gardes.entries) {
    testWidgets('${entree.key} : le Fil n\'est pas rechargé, un message dit '
        'où est le moment', (tester) async {
      await publierDepuisLeProfil(tester, ResultatCloche(entree.key));

      expect(ongletAffiche(tester), TablOnglet.profil.index);
      expect(souvenirs.appelsFeed, 1);
      expect(find.text(entree.value), findsOneWidget);
    });
  }
}
