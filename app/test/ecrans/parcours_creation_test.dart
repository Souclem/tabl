import 'dart:io';

import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/ecrans/ecran_finalisation.dart';
import 'package:app/ecrans/parcours_creation.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'parcours_simule.dart';

/// La file d'envoi, simulée : la publication réussit aussitôt.
class _FauxEnvois implements EnvoiPublications {
  _FauxEnvois(this.brouillons);

  @override
  final BrouillonsLocaux brouillons;
  final List<String> envoyes = [];

  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    envoyes.add(brouillonId);
    return const ResultatEnvoi(StatutEnvoi.publie);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late Directory racine;
  late BrouillonsLocaux brouillons;
  late _FauxEnvois envois;
  late FausseCamera camera;
  late DateTime maintenant;
  var compteur = 0;
  ResultatCloche? resultat;
  var termine = false;

  setUp(() {
    racine = Directory.systemTemp.createTempSync('parcours_creation_test');
    maintenant = DateTime(2026, 11, 8, 12, 30);
    compteur = 0;
    brouillons = BrouillonsLocaux(
      racine,
      maintenant: () => maintenant,
      genererId: () => 'id${++compteur}',
    );
    envois = _FauxEnvois(brouillons);
    camera = FausseCamera(octetsPhoto: pngTest, maintenant: () => maintenant);
    resultat = null;
    termine = false;
  });

  tearDown(() => racine.deleteSync(recursive: true));

  /// Le Fil, d'où part le parcours, sur une vraie pile.
  Future<void> demarrer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  resultat = await ParcoursCreation.ouvrir(
                    context,
                    souvenirService: FauxSouvenirService(),
                    abonnementService: FauxAbonnementService(),
                    camera: camera,
                    envois: envois,
                    rechercheLieuService: FausseRechercheLieu(),
                    positionService: PositionFixe(),
                    maintenant: () => maintenant,
                  );
                  termine = true;
                },
                child: const Text('Fil'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fil'));
    await attendreAffichage(tester, find.byType(EcranCamera));
  }

  /// Le parcours a rendu la main au Fil ; les transitions (en temps simulé)
  /// se terminent ensuite.
  Future<void> attendreRetourAuFil(WidgetTester tester) async {
    await attendreJusque(tester, () => termine, attendu: 'le retour au Fil');
    await attendre(tester, tours: 10);
  }

  /// Une photo prise, puis « Continuer » (le restaurant est proposé d'après
  /// la position).
  Future<void> prendreUnePhotoEtContinuer(WidgetTester tester) async {
    await tester.tap(find.byType(DeclencheurCamera));
    await attendreAffichage(tester, find.text('Continuer · 1'));
    await tester.tap(find.text('Continuer · 1'));
    await attendreAffichage(tester, find.byType(EcranFinalisation));
    await attendreAffichage(tester, find.text('Le Comptoir'));
  }

  testWidgets('« + » ouvre la caméra', (tester) async {
    await demarrer(tester);

    expect(find.byType(EcranCamera), findsOneWidget);
    expect(find.byType(EcranFinalisation), findsNothing);
  });

  testWidgets('Continuer remplace la caméra par la finalisation', (
    tester,
  ) async {
    await demarrer(tester);
    await prendreUnePhotoEtContinuer(tester);

    expect(find.byType(EcranFinalisation), findsOneWidget);
    expect(find.byType(EcranCamera), findsNothing);
    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(termine, isFalse);
  });

  testWidgets('finalisation → cloche → résultat rendu au Fil', (tester) async {
    await demarrer(tester);
    await prendreUnePhotoEtContinuer(tester);

    await tester.tap(find.text('🤩'));
    await attendre(tester, tours: 4);
    await tester.tap(find.text('Publier'));
    await attendreRetourAuFil(tester);

    expect(envois.envoyes, ['id1']);
    expect(termine, isTrue);
    expect(resultat!.issue, IssueCloche.publie);
    expect(find.byType(EcranCloche), findsNothing);
    expect(find.byType(EcranFinalisation), findsNothing);
    expect(find.byType(EcranCamera), findsNothing);
    expect(find.text('Fil'), findsOneWidget);
  });

  testWidgets('« Plus tard » revient au Fil, sans résultat', (tester) async {
    await demarrer(tester);
    await prendreUnePhotoEtContinuer(tester);

    await tester.tap(find.text('Plus tard'));
    await attendreRetourAuFil(tester);

    expect(termine, isTrue);
    expect(resultat, isNull);
    expect(find.byType(EcranCamera), findsNothing);
    expect(find.text('Fil'), findsOneWidget);
    expect(envois.envoyes, isEmpty);
    expect(await tester.runAsync(brouillons.lister), hasLength(1));
  });

  testWidgets('fermer la caméra revient au Fil, sans résultat', (tester) async {
    await demarrer(tester);

    await tester.tap(find.byTooltip('Fermer : le brouillon est gardé'));
    await attendreRetourAuFil(tester);

    expect(termine, isTrue);
    expect(resultat, isNull);
    expect(find.text('Fil'), findsOneWidget);
  });

  testWidgets('« Reprendre des photos » rouvre la caméra', (tester) async {
    await demarrer(tester);
    await prendreUnePhotoEtContinuer(tester);
    // Plus aucune photo à publier : le bouton propose les photos.
    await tester.runAsync(
      () => brouillons.mettreAJour(
        'id1',
        (b) => b.copieAvec(horsPublicationIds: {b.photos.single.id}),
      ),
    );
    await tester.tap(find.text('Plus tard'));
    await attendreRetourAuFil(tester);

    await tester.tap(find.text('Fil'));
    await attendreAffichage(tester, find.textContaining('Continuer'));
    await tester.tap(find.textContaining('Continuer'));
    await attendreAffichage(tester, find.text('Choisir les photos'));

    await tester.tap(find.text('Choisir les photos'));
    await attendreAffichage(tester, find.text('Photos du moment'));

    await tester.tap(find.text('Reprendre des photos'));
    await attendreJusque(
      tester,
      () => find.byType(EcranFinalisation).evaluate().isEmpty,
      attendu: 'la caméra à la place de la finalisation',
    );
    await attendre(tester, tours: 10);

    expect(find.byType(EcranCamera), findsOneWidget);
    expect(find.byType(EcranFinalisation), findsNothing);
  });
}
