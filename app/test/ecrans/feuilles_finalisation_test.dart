import 'package:app/ecrans/feuille_avec_qui.dart';
import 'package:app/ecrans/feuille_ou_et_quand.dart';
import 'package:app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _poser(
  WidgetTester tester,
  Widget Function(BuildContext) ouvrir,
) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => ouvrir(context),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  ),
);

Future<void> _ouvrir(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  const comptoir = LieuRestaurant(
    nom: 'Le Comptoir',
    ville: 'Liège',
    restaurantId: 'r1',
    latitude: 50.6,
    longitude: 5.5,
    categories: ['Italian Restaurant'],
    distanceM: 40,
  );
  const chezZoe = LieuRestaurant(nom: 'Chez Zoé', ville: 'Liège');

  group('Où et quand', () {
    const emma = ProfilPublic(
      id: 'emma',
      pseudo: 'emma',
      statut: StatutAbonnement.abonne,
    );
    const martin = ProfilPublic(
      id: 'martin',
      pseudo: 'martin',
      statut: StatutAbonnement.abonne,
    );

    Future<void> ouvrir(
      WidgetTester tester, {
      required LieuRestaurant? lieu,
      String? moment = 'midi',
      List<List<LieuRestaurant>> proches = const [],
      List<ProfilPublic> suivis = const [],
      RechercheLieuService? recherche,
      void Function(ResultatOuEtQuand?)? surResultat,
    }) async {
      await _poser(tester, (context) {
        ouvrirFeuilleOuEtQuand(
          context,
          lieu: lieu,
          moment: moment,
          endroits: const [(latitude: 50.6, longitude: 5.5)],
          prochesParEndroit: proches,
          repere: RepereDistance.photo,
          rechercheLieuService: recherche,
          positionService: null,
          personnesSuivies: Future.value(suivis),
        ).then((r) => surResultat?.call(r));
        return const SizedBox();
      });
      await _ouvrir(tester);
    }

    void coche(WidgetTester tester, String titre, bool attendu) => expect(
      tester.getSemantics(find.bySemanticsLabel(titre)),
      isSemantics(isChecked: attendu),
    );

    Future<void> toucher(WidgetTester tester, String texte) async {
      await tester.tap(find.text(texte));
      await tester.pumpAndSettle();
    }

    Future<void> versLaMaison(WidgetTester tester) async {
      await tester.tap(find.bySemanticsLabel('Pas au restaurant'));
      await tester.pumpAndSettle();
    }

    Future<void> chercher(WidgetTester tester, String texte) async {
      await tester.enterText(find.byType(TextField).first, texte);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    }

    testWidgets('le restaurant proposé est déjà coché : « OK » le garde', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        proches: [
          [comptoir, chezZoe],
        ],
        surResultat: (r) => resultat = r,
      );

      // Pas de question à répondre.
      expect(find.textContaining('Étiez-vous'), findsNothing);
      coche(tester, 'Le Comptoir', true);
      coche(tester, 'Chez Zoé', false);

      await toucher(tester, 'OK');
      expect(resultat!.lieu, comptoir);
      expect(resultat!.moment, 'midi');
    });

    testWidgets('toucher une autre ligne la coche, sans fermer', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        proches: [
          [comptoir, chezZoe],
        ],
        surResultat: (r) => resultat = r,
      );

      await toucher(tester, 'Chez Zoé');
      expect(resultat, isNull);
      coche(tester, 'Chez Zoé', true);
      // La liste se replie sur le choix…
      expect(find.text('Le Comptoir'), findsNothing);
      expect(find.text('VOTRE CHOIX'), findsOneWidget);

      // … et se rouvre à la demande, le choix toujours coché.
      await toucher(tester, 'Voir les autres restaurants');
      coche(tester, 'Chez Zoé', true);
      coche(tester, 'Le Comptoir', false);

      await toucher(tester, 'OK');
      expect(resultat!.lieu, chezZoe);
    });

    testWidgets('retoucher le choix replié rouvre la liste', (tester) async {
      await ouvrir(
        tester,
        lieu: comptoir,
        proches: [
          [comptoir, chezZoe],
        ],
      );

      await toucher(tester, 'Le Comptoir');
      expect(find.text('Chez Zoé'), findsNothing);
      await toucher(tester, 'Le Comptoir');
      expect(find.text('Chez Zoé'), findsOneWidget);
    });

    testWidgets('beaucoup de restaurants : la liste défile, le repas reste', (
      tester,
    ) async {
      await ouvrir(
        tester,
        lieu: null,
        proches: [
          [
            for (var i = 0; i < 20; i++)
              LieuRestaurant(
                nom: 'Resto $i',
                ville: 'Liège',
                restaurantId: 'r$i',
              ),
          ],
        ],
      );

      final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
      // Le dernier est plus bas, à atteindre en faisant défiler…
      expect(find.text('Resto 19', skipOffstage: false), findsOneWidget);
      // … pendant que le moment du repas et « OK » restent à l'écran.
      for (final texte in ['Dîner', 'OK']) {
        expect(
          tester.getRect(find.text(texte)).bottom,
          lessThanOrEqualTo(ecran.height),
          reason: texte,
        );
      }
      final avant = tester.getRect(find.text('Dîner'));
      await tester.drag(find.text('Resto 3'), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Dîner')), avant);
    });

    testWidgets('Déjeuner / Dîner / Petit-déjeuner se choisissent', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(tester, lieu: comptoir, surResultat: (r) => resultat = r);

      await toucher(tester, 'Dîner');
      await toucher(tester, 'Petit-déjeuner');
      await toucher(tester, 'OK');

      expect(resultat!.moment, 'matin');
      expect(resultat!.lieu, comptoir);
    });

    testWidgets('un moment publié n\'offre pas le moment du repas', (
      tester,
    ) async {
      await ouvrir(tester, lieu: comptoir, moment: null);

      expect(find.text('MOMENT DU REPAS'), findsNothing);
      expect(find.text('Déjeuner'), findsNothing);
    });

    testWidgets('la recherche cherche dans la feuille, au fil de la frappe', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        recherche: _FausseRecherche([chezZoe]),
        surResultat: (r) => resultat = r,
      );

      await chercher(tester, 'zoé');

      // Pas d'autre feuille : on reste dans « Où et quand ».
      expect(find.text('Quel restaurant ?'), findsNothing);
      expect(find.text('Où et quand'), findsOneWidget);
      await toucher(tester, 'Chez Zoé');
      coche(tester, 'Chez Zoé', true);
      await toucher(tester, 'OK');
      expect(resultat!.lieu, chezZoe);
    });

    testWidgets('« Pas dans Tabl ? » : écrit sur place, sans position', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: null,
        recherche: _FausseRecherche(const []),
        surResultat: (r) => resultat = r,
      );

      await chercher(tester, 'Le Truck');
      expect(find.text('Aucun restaurant trouvé.'), findsOneWidget);
      await toucher(tester, 'Pas dans Tabl ?');

      // Le nom cherché est déjà écrit ; l'épingle reste à placer soi-même.
      expect(find.text('Quel restaurant ?'), findsNothing);
      expect(find.text('Placer sur la carte'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Ville'), 'Gand');
      await toucher(tester, 'Ajouter');
      await toucher(tester, 'OK');

      final lieu = resultat!.lieu!;
      expect(lieu.nom, 'Le Truck');
      expect(lieu.ville, 'Gand');
      expect(lieu.estManuel, isTrue);
      expect(lieu.latitude, isNull);
      expect(lieu.longitude, isNull);
    });

    testWidgets('« Pas dans Tabl ? » sans ville : un mot la demande', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(tester, lieu: null, surResultat: (r) => resultat = r);

      await toucher(tester, 'Pas dans Tabl ?');
      await tester.enterText(
        find.widgetWithText(TextField, 'Nom du restaurant'),
        'Le Truck',
      );
      await toucher(tester, 'OK');

      expect(find.text('Entrez la ville.'), findsOneWidget);
      expect(resultat, isNull);
    });

    group('la maison', () {
      testWidgets('bascule la feuille hors des restaurants, et revient', (
        tester,
      ) async {
        await ouvrir(
          tester,
          lieu: comptoir,
          proches: [
            [comptoir],
          ],
        );
        expect(find.text('CHEZ PERSONNE'), findsNothing);

        await versLaMaison(tester);
        expect(find.text('CHEZ PERSONNE'), findsOneWidget);
        expect(find.text('Chez moi'), findsOneWidget);
        expect(find.text('Le Comptoir'), findsNothing);

        await versLaMaison(tester);
        expect(find.text('Le Comptoir'), findsOneWidget);
      });

      testWidgets('« Chez moi » : aucune adresse ni position', (tester) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(tester, lieu: comptoir, surResultat: (r) => resultat = r);

        await versLaMaison(tester);
        await toucher(tester, 'Chez moi');
        await toucher(tester, 'OK');

        final lieu = resultat!.lieu!;
        expect(lieu.genre, GenreLieu.domicile);
        expect(lieu.latitude, isNull);
        expect(lieu.longitude, isNull);
        expect(lieu.adresse, isNull);
        expect(lieu.libelle, 'Chez vous');
      });

      testWidgets('un lieu personnel ouvre la feuille côté maison, coché', (
        tester,
      ) async {
        await ouvrir(tester, lieu: const LieuRestaurant.domicile());

        expect(find.text('CHEZ PERSONNE'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Chez moi')),
          isSemantics(isSelected: true),
        );
      });

      testWidgets('chez une personne suivie : liée par son profil', (
        tester,
      ) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(
          tester,
          lieu: null,
          suivis: [martin, emma],
          surResultat: (r) => resultat = r,
        );

        await versLaMaison(tester);
        await tester.tap(find.bySemanticsLabel('Chez emma'));
        await tester.pumpAndSettle();
        await toucher(tester, 'OK');

        final lieu = resultat!.lieu!;
        expect(lieu.genre, GenreLieu.chez);
        expect(lieu.hoteId, 'emma');
        expect(lieu.libelle, 'Chez emma');
        expect(lieu.latitude, isNull);
      });

      testWidgets('la recherche trouve une personne', (tester) async {
        await ouvrir(tester, lieu: null, suivis: [martin, emma]);

        await versLaMaison(tester);
        await tester.enterText(find.byType(TextField), 'em');
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Chez emma'), findsOneWidget);
        expect(find.bySemanticsLabel('Chez martin'), findsNothing);
        expect(find.text('Chez moi'), findsNothing);
      });

      testWidgets('beaucoup de personnes : tout reste visible', (tester) async {
        await ouvrir(
          tester,
          lieu: null,
          suivis: [
            for (var i = 0; i < 40; i++)
              ProfilPublic(
                id: 'p$i',
                pseudo: 'personne$i',
                statut: StatutAbonnement.abonne,
              ),
          ],
        );
        await versLaMaison(tester);

        // La rangée défile de côté : « Chez personne », le moment du repas
        // et « OK » restent à l'écran sans faire défiler la feuille.
        final ecran = tester.view.physicalSize / tester.view.devicePixelRatio;
        for (final texte in ['Pique-nique', 'Autre', 'Dîner', 'OK']) {
          expect(
            tester.getRect(find.text(texte)).bottom,
            lessThanOrEqualTo(ecran.height),
            reason: texte,
          );
        }
        expect(find.text('Chez moi'), findsOneWidget);
      });

      testWidgets('« Chez… » : quelqu\'un hors Tabl, juste un nom', (
        tester,
      ) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(tester, lieu: null, surResultat: (r) => resultat = r);

        await versLaMaison(tester);
        await toucher(tester, 'Chez…');
        await tester.enterText(find.byType(TextField).last, 'Mamie');
        // « OK » de la feuille : le nom écrit n'est pas perdu.
        await toucher(tester, 'OK');

        final lieu = resultat!.lieu!;
        expect(lieu.nom, 'Chez Mamie');
        expect(lieu.genre, GenreLieu.chez);
        expect(lieu.hoteId, isNull);
      });

      testWidgets('« Chez… » sans nom : un mot le demande', (tester) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(tester, lieu: null, surResultat: (r) => resultat = r);

        await versLaMaison(tester);
        await toucher(tester, 'Chez…');
        await tester.enterText(find.byType(TextField).last, 'chez ');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(find.text('Donnez-lui un nom.'), findsOneWidget);
        expect(resultat, isNull);
      });

      testWidgets('« Chez personne » : pique-nique, ou un autre mot', (
        tester,
      ) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(tester, lieu: null, surResultat: (r) => resultat = r);

        await versLaMaison(tester);
        await toucher(tester, 'Pique-nique');
        await toucher(tester, 'OK');

        expect(resultat!.lieu!.genre, GenreLieu.ailleurs);
        expect(resultat!.lieu!.nom, 'Pique-nique');
      });

      testWidgets('« Autre » : un lieu sans hôte ni adresse', (tester) async {
        ResultatOuEtQuand? resultat;
        await ouvrir(tester, lieu: null, surResultat: (r) => resultat = r);

        await versLaMaison(tester);
        await toucher(tester, 'Autre');
        await tester.enterText(find.byType(TextField).last, 'Au bord du lac');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        await toucher(tester, 'OK');

        expect(resultat!.lieu!.genre, GenreLieu.ailleurs);
        expect(resultat!.lieu!.nom, 'Au bord du lac');
      });
    });

    testWidgets('fermée sans rien choisir : null', (tester) async {
      var rendu = false;
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        surResultat: (r) {
          rendu = true;
          resultat = r;
        },
      );

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(rendu, isTrue);
      expect(resultat, isNull);
    });
  });

  group('Avec qui', () {
    final gens = [
      const ProfilPublic(
        id: 'p1',
        pseudo: 'Zoé',
        statut: StatutAbonnement.abonne,
      ),
      const ProfilPublic(
        id: 'p2',
        pseudo: 'Clément',
        statut: StatutAbonnement.abonne,
      ),
      const ProfilPublic(
        id: 'p3',
        pseudo: 'Louis',
        statut: StatutAbonnement.aucun,
        meSuit: true,
      ),
    ];

    testWidgets('toucher une personne la coche aussitôt', (tester) async {
      final recus = <Set<String>>[];
      await _poser(tester, (context) {
        ouvrirFeuilleAvecQui(
          context,
          personnes: gens,
          selection: {'p1'},
          onChange: recus.add,
        );
        return const SizedBox();
      });
      await _ouvrir(tester);

      await tester.tap(find.text('Clément'));
      await tester.pump();
      expect(recus.last, {'p1', 'p2'});
      expect(
        tester.getSemantics(find.bySemanticsLabel('Clément')),
        isSemantics(isChecked: true),
      );

      await tester.tap(find.text('Zoé'));
      await tester.pump();
      expect(recus.last, {'p2'});
    });

    testWidgets('la recherche filtre sans tenir compte des accents', (
      tester,
    ) async {
      await _poser(tester, (context) {
        ouvrirFeuilleAvecQui(
          context,
          personnes: gens,
          selection: {},
          onChange: (_) {},
        );
        return const SizedBox();
      });
      await _ouvrir(tester);

      await tester.enterText(find.byType(TextField), 'zoe');
      await tester.pump();

      expect(find.text('Zoé'), findsOneWidget);
      expect(find.text('Clément'), findsNothing);

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.pump();
      expect(find.text('Aucune personne trouvée.'), findsOneWidget);
    });

    testWidgets('les personnes récentes passent en tête', (tester) async {
      await _poser(tester, (context) {
        ouvrirFeuilleAvecQui(
          context,
          personnes: gens,
          selection: {},
          recentsIds: const ['p3'],
          onChange: (_) {},
        );
        return const SizedBox();
      });
      await _ouvrir(tester);

      expect(find.text('RÉCEMMENT À TABLE AVEC VOUS'), findsOneWidget);
    });

    testWidgets('sans personne à taguer, un mot l\'explique', (tester) async {
      await _poser(tester, (context) {
        ouvrirFeuilleAvecQui(
          context,
          personnes: const [],
          selection: {},
          onChange: (_) {},
        );
        return const SizedBox();
      });
      await _ouvrir(tester);

      expect(find.textContaining('suivez des gens'), findsOneWidget);
    });
  });
}

class _FausseRecherche implements RechercheLieuService {
  _FausseRecherche(this.lieux);

  final List<LieuRestaurant> lieux;

  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async => [
    for (final l in lieux)
      if (normaliserPourRecherche(
        l.nom,
      ).contains(normaliserPourRecherche(texte)))
        l,
  ];

  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async => const [];

  @override
  Future<List<LieuRestaurant>> mesLieuxPersonnels() async => const [];
}
