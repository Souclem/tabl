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

  /// Les brouillons que l'auteur a demandé d'envoyer dès que possible.
  final enAttente = <String>[];

  @override
  Future<List<EnvoiPublication>> enAttenteDEnvoi() async => [
    for (final id in enAttente)
      EnvoiPublication(
        brouillonId: id,
        auteurId: 'moi',
        etat: EtatEnvoi.enAttente,
        creeLe: DateTime(2026, 11, 8),
      ),
  ];

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

  /// Le Fil, d'où part le parcours, sur une vraie pile. [attendu] : ce que
  /// « + » ouvre (la caméra, sans brouillon en cours).
  Future<void> demarrer(WidgetTester tester, {Finder? attendu}) async {
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
    await attendreAffichage(tester, attendu ?? find.byType(EcranCamera));
  }

  /// Un brouillon d'une photo par lieu, déjà sur le téléphone.
  Future<List<Brouillon>> brouillonsEnCours(
    WidgetTester tester,
    List<String> lieux,
  ) async {
    final faits = <Brouillon>[];
    for (final nom in lieux) {
      final b = await tester.runAsync(() async {
        final b = await brouillons.ajouterPhoto(
          octets: pngTest,
          priseLe: maintenant,
        );
        maintenant = maintenant.add(const Duration(minutes: 1));
        return brouillons.mettreAJour(
          b.id,
          (b) => b.copieAvec(
            lieu: () => LieuRestaurant(nom: nom, ville: 'Liège'),
          ),
        );
      });
      faits.add(b!);
    }
    return faits;
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

  testWidgets('l\'appareil photo de la finalisation rouvre la caméra, '
      'puis « Continuer » y revient', (tester) async {
    await demarrer(tester);
    await prendreUnePhotoEtContinuer(tester);

    await tester.tap(find.byTooltip('Reprendre des photos'));
    await attendreJusque(
      tester,
      () => find.byType(EcranFinalisation).evaluate().isEmpty,
      attendu: 'la caméra à la place de la finalisation',
    );
    await attendre(tester, tours: 10);

    expect(find.byType(EcranCamera), findsOneWidget);
    expect(find.byType(EcranFinalisation), findsNothing);
    // Toujours le même brouillon : la photo y est encore.
    expect(find.text('Continuer · 1'), findsOneWidget);

    await tester.tap(find.text('Continuer · 1'));
    await attendreAffichage(tester, find.byType(EcranFinalisation));
    expect(find.text('Publier'), findsOneWidget);
  });

  group('brouillons en cours', () {
    testWidgets('« + » propose la liste, « Nouveau moment » en dernier', (
      tester,
    ) async {
      await brouillonsEnCours(tester, ['Le Comptoir', 'Chez Paul']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      expect(find.byType(EcranCamera), findsNothing);
      expect(find.text('Chez Paul'), findsOneWidget);
      expect(find.text('Le Comptoir'), findsOneWidget);
      expect(find.textContaining('1 photo'), findsNWidgets(2));
      // Le plus récent d'abord, « Nouveau moment » en dernier.
      double y(String t) => tester.getCenter(find.text(t)).dy;
      expect(y('Chez Paul'), lessThan(y('Le Comptoir')));
      expect(y('Le Comptoir'), lessThan(y('Nouveau moment')));
    });

    testWidgets('reprendre un brouillon : la caméra s\'ouvre avec ses photos, '
        'Continuer mène à ce brouillon', (tester) async {
      await brouillonsEnCours(tester, ['Le Comptoir', 'Chez Paul']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      await tester.tap(find.text('Le Comptoir'));
      await attendreAffichage(tester, find.byType(EcranCamera));
      await attendreAffichage(tester, find.text('Continuer · 1'));
      expect(find.text('Importer'), findsNothing);

      await tester.tap(find.text('Continuer · 1'));
      await attendreAffichage(tester, find.byType(EcranFinalisation));
      expect(find.text('Le Comptoir'), findsOneWidget);
      expect(find.text('Chez Paul'), findsNothing);
    });

    testWidgets('« Nouveau moment » : une caméra vide, un brouillon à part', (
      tester,
    ) async {
      await brouillonsEnCours(tester, ['Le Comptoir']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      await tester.tap(find.text('Nouveau moment'));
      await attendreAffichage(tester, find.byType(EcranCamera));
      expect(find.textContaining('Continuer'), findsNothing);

      await tester.tap(find.byType(DeclencheurCamera));
      await attendreAffichage(tester, find.text('Continuer · 1'));
      await attendre(tester);
      expect(await tester.runAsync(brouillons.lister), hasLength(2));
    });

    testWidgets('fermer la liste : rien ne s\'ouvre', (tester) async {
      await brouillonsEnCours(tester, ['Le Comptoir']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      await tester.tapAt(const Offset(200, 40));
      await attendreRetourAuFil(tester);

      expect(resultat, isNull);
      expect(find.byType(EcranCamera), findsNothing);
      expect(find.text('Brouillons'), findsNothing);
    });

    testWidgets('trois brouillons : « Nouveau moment » attend qu\'on en '
        'publie ou supprime un', (tester) async {
      await brouillonsEnCours(tester, ['A', 'B', 'C']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      expect(find.text(libelleLimiteBrouillons), findsOneWidget);
      await tester.tap(find.text('Nouveau moment'));
      await attendre(tester, tours: 6);
      expect(find.byType(EcranCamera), findsNothing);

      // Supprimer B (après confirmation) libère une place.
      // Le plus récent d'abord : C, B, A.
      await tester.tap(find.byTooltip('Supprimer ce brouillon').at(1));
      await attendreAffichage(tester, find.text('Supprimer ce brouillon ?'));
      expect(
        find.text('Sa photo sera effacée de ce téléphone.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Supprimer'));
      await attendreJusque(
        tester,
        () => find.text('B').evaluate().isEmpty,
        attendu: 'B retiré de la liste',
      );

      expect(find.text(libelleLimiteBrouillons), findsNothing);
      final liste = await tester.runAsync(brouillons.lister);
      expect([
        for (final b in liste!) b.lieu!.nom,
      ], unorderedEquals(['A', 'C']));

      await tester.tap(find.text('Nouveau moment'));
      await attendreAffichage(tester, find.byType(EcranCamera));
    });

    testWidgets('au-delà de trois brouillons, les plus anciens sont '
        'effacés', (tester) async {
      await brouillonsEnCours(tester, ['A', 'B', 'C', 'D', 'E']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      expect(find.text('E'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('B'), findsNothing);
      expect(find.text('A'), findsNothing);
      await attendre(tester);
      final liste = await tester.runAsync(brouillons.lister);
      expect([
        for (final b in liste!) b.lieu!.nom,
      ], unorderedEquals(['C', 'D', 'E']));
    });

    testWidgets('brouillons illisibles : pas de nouveau moment, un message', (
      tester,
    ) async {
      // Un dossier des brouillons qu'on ne peut pas lire : la liste échoue.
      final dossier = Directory('${racine.path}/brouillons')..createSync();
      Process.runSync('chmod', ['000', dossier.path]);
      addTearDown(() => Process.runSync('chmod', ['755', dossier.path]));

      await demarrer(tester, attendu: find.text(messageErreurGenerique));

      expect(find.byType(EcranCamera), findsNothing);
      expect(termine, isTrue);
    });

    testWidgets('« Annuler » à la confirmation garde le brouillon', (
      tester,
    ) async {
      await brouillonsEnCours(tester, ['Le Comptoir']);
      await demarrer(tester, attendu: find.text('Brouillons'));

      await tester.tap(find.byTooltip('Supprimer ce brouillon'));
      await attendreAffichage(tester, find.text('Supprimer ce brouillon ?'));
      await tester.tap(find.text('Annuler'));
      await attendre(tester, tours: 6);

      expect(find.text('Le Comptoir'), findsOneWidget);
      expect(await tester.runAsync(brouillons.lister), hasLength(1));
    });

    testWidgets('un brouillon qui attend d\'être envoyé n\'est pas proposé', (
      tester,
    ) async {
      final faits = await brouillonsEnCours(tester, ['Le Comptoir']);
      envois.enAttente.add(faits.single.id);

      await demarrer(tester);

      expect(find.byType(EcranCamera), findsOneWidget);
      expect(find.text('Brouillons'), findsNothing);
    });
  });
}
