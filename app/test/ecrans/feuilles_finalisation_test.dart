import 'dart:io';
import 'dart:typed_data';

import 'package:app/ecrans/feuille_avec_qui.dart';
import 'package:app/ecrans/feuille_ou_et_quand.dart';
import 'package:app/ecrans/feuille_photos_moment.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
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
    Future<void> ouvrir(
      WidgetTester tester, {
      required LieuRestaurant? lieu,
      bool confirme = false,
      String? moment = 'midi',
      List<List<LieuRestaurant>> proches = const [],
      void Function(ResultatOuEtQuand?)? surResultat,
    }) async {
      await _poser(tester, (context) {
        ouvrirFeuilleOuEtQuand(
          context,
          lieu: lieu,
          lieuConfirme: confirme,
          moment: moment,
          endroits: const [(latitude: 50.6, longitude: 5.5)],
          prochesParEndroit: proches,
          repere: RepereDistance.photo,
          rechercheLieuService: null,
          positionService: null,
        ).then((r) => surResultat?.call(r));
        return const SizedBox();
      });
      await _ouvrir(tester);
    }

    testWidgets('« Oui » confirme le lieu proposé', (tester) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(tester, lieu: comptoir, surResultat: (r) => resultat = r);

      expect(find.text('Étiez-vous chez Le Comptoir ?'), findsOneWidget);
      await tester.tap(find.text('Oui'));
      await tester.pumpAndSettle();

      expect(resultat!.lieu, comptoir);
      expect(resultat!.lieuConfirme, isTrue);
      expect(resultat!.moment, 'midi');
    });

    testWidgets('« Non » efface la proposition et laisse choisir', (
      tester,
    ) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        proches: [
          [chezZoe],
        ],
        surResultat: (r) => resultat = r,
      );

      await tester.tap(find.text('Non'));
      await tester.pumpAndSettle();
      expect(find.text('Étiez-vous chez Le Comptoir ?'), findsNothing);

      await tester.tap(find.text('Chez Zoé'));
      await tester.pumpAndSettle();
      expect(resultat!.lieu, chezZoe);
      expect(resultat!.lieuConfirme, isTrue);
    });

    testWidgets('Midi / Soir se choisit puis se valide', (tester) async {
      ResultatOuEtQuand? resultat;
      await ouvrir(
        tester,
        lieu: comptoir,
        confirme: true,
        surResultat: (r) => resultat = r,
      );

      await tester.tap(find.text('Soir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(resultat!.moment, 'soir');
      expect(resultat!.lieu, comptoir);
      expect(resultat!.lieuConfirme, isTrue);
    });

    testWidgets('un moment publié n\'offre pas « Quand »', (tester) async {
      await ouvrir(tester, lieu: comptoir, confirme: true, moment: null);

      expect(find.text('QUAND'), findsNothing);
      expect(find.text('Midi'), findsNothing);
    });

    testWidgets('« Créer un lieu personnel » ouvre la saisie du nom', (
      tester,
    ) async {
      await ouvrir(tester, lieu: null);

      await tester.tap(find.text('Créer un lieu personnel'));
      await tester.pumpAndSettle();

      expect(find.text('Chez Zoé'), findsNothing);
      expect(find.byType(TextField), findsWidgets);
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
      expect(find.text('Valider · 2'), findsOneWidget);

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

  group('Photos du moment', () {
    late Directory racine;
    late BrouillonsLocaux brouillons;
    late Brouillon brouillon;

    Future<void> creer(WidgetTester tester, int nombre) async {
      await tester.runAsync(() async {
        racine = Directory.systemTemp.createTempSync('feuille_photos_test');
        var n = 0;
        brouillons = BrouillonsLocaux(racine, genererId: () => 'id${++n}');
        for (var i = 0; i < nombre; i++) {
          brouillon = await brouillons.ajouterPhoto(
            octets: Uint8List.fromList([i, i + 1]),
            priseLe: DateTime(2026, 11, 8, 12, 30),
          );
        }
      });
      addTearDown(() => racine.deleteSync(recursive: true));
    }

    Future<bool?> ouvrir(WidgetTester tester, {bool reprise = true}) async {
      bool? reprendre;
      await _poser(tester, (context) {
        ouvrirFeuillePhotos(
          context,
          brouillons: brouillons,
          brouillon: brouillon,
          peutReprendre: reprise,
        ).then((r) => reprendre = r);
        return const SizedBox();
      });
      await _ouvrir(tester);
      return reprendre;
    }

    Future<void> geste(WidgetTester tester, Finder cible) async {
      await tester.runAsync(() async {
        await tester.tap(cible);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
    }

    testWidgets('la première photo est la couverture', (tester) async {
      await creer(tester, 3);
      await ouvrir(tester);

      expect(find.text('Couverture'), findsOneWidget);
      expect(find.text('Photo 2'), findsOneWidget);
      expect(find.text('Photo 3'), findsOneWidget);
      expect(find.text('3 / 10 à publier'), findsOneWidget);
    });

    testWidgets('retirer de la publication garde la photo et l\'écrit', (
      tester,
    ) async {
      await creer(tester, 3);
      await ouvrir(tester);

      await geste(tester, find.byTooltip('Retirer de la publication').at(1));

      expect(find.text('2 / 10 à publier'), findsOneWidget);
      expect(find.text('Pas dans la publication'), findsOneWidget);
      final relu = await tester.runAsync(
        () => brouillons.charger(brouillon.id),
      );
      expect(relu!.photos, hasLength(3));
      expect(relu.horsPublicationIds, {brouillon.photos[1].id});

      await geste(tester, find.byTooltip('Remettre dans la publication'));
      expect(find.text('3 / 10 à publier'), findsOneWidget);
    });

    testWidgets('supprimer propose d\'annuler', (tester) async {
      await creer(tester, 3);
      await ouvrir(tester);

      await geste(tester, find.byTooltip('Supprimer la photo').first);

      expect(
        find.text('Photo supprimée · récupérable 30 jours'),
        findsOneWidget,
      );
      expect(find.text('2 / 10 à publier'), findsOneWidget);

      await geste(tester, find.text('Annuler'));
      expect(find.text('3 / 10 à publier'), findsOneWidget);
      expect(find.text('Photo supprimée · récupérable 30 jours'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('plus de dix photos : il faut en retirer pour valider', (
      tester,
    ) async {
      await creer(tester, 12);
      await ouvrir(tester);
      await tester.pump();

      expect(
        find.text(
          'Un moment garde 10 photos au plus : retirez-en 2 de la publication.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TablBouton>(find.widgetWithText(TablBouton, 'Valider'))
            .onPresse,
        isNull,
      );

      await geste(tester, find.byTooltip('Retirer de la publication').first);
      await geste(tester, find.byTooltip('Retirer de la publication').first);

      expect(find.text('10 / 10 à publier'), findsOneWidget);
      expect(
        tester
            .widget<TablBouton>(find.widgetWithText(TablBouton, 'Valider'))
            .onPresse,
        isNotNull,
      );
    });

    testWidgets('« Reprendre des photos » ferme la feuille avec true', (
      tester,
    ) async {
      await creer(tester, 2);
      bool? reprendre;
      await _poser(tester, (context) {
        ouvrirFeuillePhotos(
          context,
          brouillons: brouillons,
          brouillon: brouillon,
          peutReprendre: true,
        ).then((r) => reprendre = r);
        return const SizedBox();
      });
      await _ouvrir(tester);

      await tester.tap(find.text('Reprendre des photos'));
      await tester.pumpAndSettle();

      expect(reprendre, isTrue);
    });

    testWidgets('sans reprise possible, le bouton n\'est pas proposé', (
      tester,
    ) async {
      await creer(tester, 2);
      await ouvrir(tester, reprise: false);

      expect(find.text('Reprendre des photos'), findsNothing);
    });
  });
}
