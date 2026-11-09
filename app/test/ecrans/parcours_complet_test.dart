import 'dart:io';

import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/ecrans/ecran_finalisation.dart';
import 'package:app/ecrans/parcours_creation.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../services/depot_publication_simule.dart';
import 'parcours_simule.dart';

/// Le parcours complet, avec la vraie file d'envoi et un serveur en mémoire :
/// caméra → finalisation → cloche → publié, puis les pannes (hors ligne,
/// échec au commit) et la reprise après une fermeture de l'app.
void main() {
  late Directory racine;
  late DepotPublicationSimule depot;
  late FausseCamera camera;
  late DateTime maintenant;
  var compteur = 0;
  ResultatCloche? resultat;
  var termine = false;

  /// L'app qui s'ouvre : brouillons et file relus depuis le dossier du
  /// téléphone, comme après une fermeture.
  ({BrouillonsLocaux brouillons, FileEnvoi file, EnvoiPublications envois})
  ouvrirApp() {
    final brouillons = BrouillonsLocaux(
      racine,
      maintenant: () => maintenant,
      genererId: () => 'id${++compteur}',
    );
    final file = FileEnvoi(racine);
    return (
      brouillons: brouillons,
      file: file,
      envois: EnvoiPublications(
        depot,
        brouillons,
        file,
        maintenant: () => maintenant,
      ),
    );
  }

  setUp(() {
    racine = Directory.systemTemp.createTempSync('parcours_complet_test');
    maintenant = DateTime(2026, 11, 8, 12, 30);
    depot = DepotPublicationSimule();
    camera = FausseCamera(octetsPhoto: pngTest, maintenant: () => maintenant);
    compteur = 0;
    resultat = null;
    termine = false;
  });

  tearDown(() => racine.deleteSync(recursive: true));

  /// Le Fil, d'où part le parcours. Rouvrir le parcours : toucher « Fil ».
  Future<void> ouvrirParcours(
    WidgetTester tester,
    EnvoiPublications envois,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    termine = false;
    await tester.pumpWidget(const SizedBox());
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

  Future<void> continuer(WidgetTester tester) async {
    await attendreAffichage(tester, find.text('Continuer · 1'));
    await tester.tap(find.text('Continuer · 1'));
    await attendreAffichage(tester, find.byType(EcranFinalisation));
  }

  Future<void> prendrePhotoEtContinuer(WidgetTester tester) async {
    await tester.tap(find.byType(DeclencheurCamera));
    await attendreAffichage(tester, find.text('Continuer · 1'));
    await continuer(tester);
  }

  const reseauCoupe = 'Pas de réseau';
  const echecPublication = 'n\'a pas abouti';

  /// Choisit l'émotion puis touche « Publier » : la cloche s'ouvre. Avec
  /// [attend], on attend aussi que la cloche affiche ce message.
  Future<void> publier(WidgetTester tester, {String? attend}) async {
    await tester.tap(find.text('🤩'));
    await attendre(tester, tours: 4);
    await tester.tap(find.text('Publier'));
    await attendreAffichage(tester, find.byType(EcranCloche));
    if (attend != null) {
      await attendreAffichage(tester, find.textContaining(attend));
    }
  }

  Finder bouton(String libelle) => find.ancestor(
    of: find.text(libelle),
    matching: find.bySubtype<ButtonStyleButton>(),
  );

  Future<void> appuyer(WidgetTester tester, String libelle) async {
    await attendreAffichage(tester, bouton(libelle));
    await tester.tap(bouton(libelle));
    await attendre(tester, tours: 4);
  }

  /// Attend que la cloche se soit refermée sur le Fil.
  Future<void> attendreFinCloche(WidgetTester tester) =>
      attendreJusque(tester, () => termine);

  /// Rouvre l'app hors du temps simulé du test : les files d'écriture créées
  /// ici s'exécuteraient sinon dans une zone que personne ne fait avancer.
  Future<
    ({BrouillonsLocaux brouillons, FileEnvoi file, EnvoiPublications envois})
  >
  rouvrirApp(WidgetTester tester) async =>
      (await tester.runAsync(() async => ouvrirApp()))!;

  Future<T> hors<T>(WidgetTester tester, Future<T> Function() action) async {
    final r = await tester.runAsync(action);
    return r as T;
  }

  /// Lit le disque avec une instance neuve, créée hors du temps simulé : les
  /// files d'écriture de l'app que les widgets ont utilisée peuvent attendre
  /// un tour d'horloge simulé qui ne vient pas pendant qu'on lit.
  Future<List<Brouillon>> brouillonsSurDisque(WidgetTester tester) =>
      hors(tester, () => ouvrirApp().brouillons.lister());

  /// Attend que le disque contienne ce que [pret] attend des brouillons.
  Future<void> attendreSurDisque(
    WidgetTester tester,
    bool Function(List<Brouillon>) pret, {
    required String attendu,
  }) async {
    List<Brouillon> liste = const [];
    for (var i = 0; i < 200; i++) {
      liste = await brouillonsSurDisque(tester);
      if (pret(liste)) return;
      await attendre(tester, tours: 2);
    }
    fail('Jamais écrit sur le disque : $attendu. Brouillons : $liste');
  }

  Future<List<EnvoiPublication>> enAttenteSurDisque(WidgetTester tester) =>
      hors(tester, () => ouvrirApp().envois.enAttenteDEnvoi());

  Future<List<EnvoiPublication>> fileSurDisque(WidgetTester tester) =>
      hors(tester, () => ouvrirApp().file.lister());

  /// Ce que l'app laisse si elle est fermée en pleine publication : photos
  /// et ligne `brouillon` sur le serveur, envoi « en cours » dans la file.
  Future<Brouillon> laisserPublicationInterrompue(
    WidgetTester tester,
    ({BrouillonsLocaux brouillons, FileEnvoi file, EnvoiPublications envois})
    app, {
    required bool commitLance,
  }) => hors(tester, () async {
    var b = await app.brouillons.ajouterPhoto(
      octets: pngTest,
      priseLe: maintenant,
    );
    b = (await app.brouillons.mettreAJour(
      b.id,
      (x) => x.copieAvec(
        lieu: () => comptoirTest,
        emotion: () => Emotion.coupDeCoeur,
      ),
    ))!;
    await PublicationEnDeuxTemps(depot).preparer(
      DemandePublication(
        id: b.id,
        lieu: comptoirTest,
        photos: [
          app.brouillons
              .fichierPhoto(b.id, b.photos.single.id)
              .readAsBytesSync(),
        ],
        emotion: Emotion.coupDeCoeur,
        priseLe: b.priseLe,
      ),
    );
    await app.file.ecrire(
      EnvoiPublication(
        brouillonId: b.id,
        auteurId: depot.monId,
        etat: EtatEnvoi.enCours,
        creeLe: maintenant,
        commitLance: commitLance,
      ),
    );
    return b;
  });

  group('publication réussie', () {
    testWidgets('finalisation → cloche → publié, rien ne reste sur le '
        'téléphone', (tester) async {
      final app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      expect(find.byType(EcranFinalisation), findsOneWidget);

      await publier(tester);
      await attendreFinCloche(tester);

      expect(termine, isTrue);
      expect(resultat!.issue, IssueCloche.publie);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes['id1']!['statut'], statutPublie);
      expect(depot.fichiers, hasLength(1));
      expect(await brouillonsSurDisque(tester), isEmpty);
      expect(await enAttenteSurDisque(tester), isEmpty);
      expect(await fileSurDisque(tester), isEmpty);
      expect(find.text('Fil'), findsOneWidget);
    });
  });

  group('hors ligne', () {
    testWidgets('« Garder en brouillon » : le moment reste sur le téléphone, '
        'le serveur ne reçoit rien', (tester) async {
      depot.horsLigne = true;
      final app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: reseauCoupe);

      expect(find.textContaining(reseauCoupe), findsOneWidget);
      expect(bouton('Envoyer dès que possible'), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);

      await appuyer(tester, 'Garder en brouillon');
      await attendreFinCloche(tester);

      expect(termine, isTrue);
      expect(resultat!.issue, IssueCloche.brouillonGarde);
      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
      expect(await brouillonsSurDisque(tester), hasLength(1));
      expect(await enAttenteSurDisque(tester), isEmpty);
    });

    testWidgets('« Envoyer dès que possible » : publié à la réouverture de '
        'l\'app, une seule fois', (tester) async {
      depot.horsLigne = true;
      var app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: reseauCoupe);
      await appuyer(tester, 'Envoyer dès que possible');
      await attendreFinCloche(tester);

      expect(resultat!.issue, IssueCloche.enAttente);
      expect(depot.lignes, isEmpty);
      expect(await brouillonsSurDisque(tester), hasLength(1));
      expect(await enAttenteSurDisque(tester), hasLength(1));

      // L'app est fermée, le réseau revient, l'app se rouvre.
      depot.horsLigne = false;
      app = await rouvrirApp(tester);
      final reprises = await hors(
        tester,
        () => app.envois.reprendre(auLancement: true),
      );

      expect(reprises.map((r) => r.issue), [IssueReprise.publiee]);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes['id1']!['statut'], statutPublie);
      expect(await brouillonsSurDisque(tester), isEmpty);
      expect(await enAttenteSurDisque(tester), isEmpty);
    });

    testWidgets('toujours hors ligne à la réouverture : le moment reste en '
        'attente', (tester) async {
      depot.horsLigne = true;
      var app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: reseauCoupe);
      await appuyer(tester, 'Envoyer dès que possible');
      await attendreFinCloche(tester);

      app = await rouvrirApp(tester);
      final reprises = await hors(
        tester,
        () => app.envois.reprendre(auLancement: true),
      );

      expect(reprises, isEmpty);
      expect(depot.lignes, isEmpty);
      expect(await brouillonsSurDisque(tester), hasLength(1));
      expect(await enAttenteSurDisque(tester), hasLength(1));
    });
  });

  group('échec au commit', () {
    testWidgets('la cloche le dit, « Réessayer » publie sans doublon', (
      tester,
    ) async {
      depot.echecAuCommit = true;
      final app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: echecPublication);

      expect(find.textContaining('n\'a pas abouti'), findsOneWidget);
      expect(find.textContaining('Pas de réseau'), findsNothing);
      expect(bouton('Réessayer'), findsOneWidget);
      expect(bouton('Garder en brouillon'), findsOneWidget);
      expect(depot.lignes['id1']!['statut'], statutBrouillon);
      expect(await brouillonsSurDisque(tester), hasLength(1));

      depot.echecAuCommit = false;
      await appuyer(tester, 'Réessayer');
      await attendreFinCloche(tester);

      expect(termine, isTrue);
      expect(resultat!.issue, IssueCloche.publie);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes['id1']!['statut'], statutPublie);
      expect(depot.fichiers, hasLength(1));
      expect(await brouillonsSurDisque(tester), isEmpty);
    });

    testWidgets('l\'ordre est parti mais la réponse s\'est perdue : '
        '« Réessayer » ne publie pas deux fois', (tester) async {
      depot.reponsePerdueAuCommit = true;
      final app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: echecPublication);

      expect(find.textContaining('n\'a pas abouti'), findsOneWidget);

      depot.reponsePerdueAuCommit = false;
      await appuyer(tester, 'Réessayer');
      await attendreFinCloche(tester);

      expect(termine, isTrue);
      expect(resultat!.issue, IssueCloche.dejaPublie);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes['id1']!['statut'], statutPublie);
      expect(depot.appels.where((a) => a == 'commit'), hasLength(1));
      expect(await brouillonsSurDisque(tester), isEmpty);
    });

    testWidgets('« Garder en brouillon » après l\'échec : le serveur est '
        'nettoyé', (tester) async {
      depot.echecAuCommit = true;
      final app = ouvrirApp();
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await publier(tester, attend: echecPublication);

      await appuyer(tester, 'Garder en brouillon');
      await attendreFinCloche(tester);

      expect(resultat!.issue, IssueCloche.brouillonGarde);
      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
      expect(await brouillonsSurDisque(tester), hasLength(1));
    });
  });

  group('reprise après fermeture', () {
    testWidgets('« Plus tard » : le brouillon est relu avec ses champs et se '
        'publie', (tester) async {
      var app = await rouvrirApp(tester);
      await ouvrirParcours(tester, app.envois);
      await prendrePhotoEtContinuer(tester);
      await tester.tap(find.text('🤩'));
      // L'émotion est écrite en tâche de fond : « Plus tard » n'attend pas
      // cette écriture, le test non plus ne doit pas supposer sa durée.
      await attendreSurDisque(
        tester,
        (liste) => liste.any((b) => b.emotion == Emotion.inoubliable),
        attendu: 'l\'émotion écrite dans le brouillon',
      );
      await tester.tap(find.text('Plus tard'));
      await attendreFinCloche(tester);

      expect(termine, isTrue);
      expect(resultat, isNull);
      expect(depot.lignes, isEmpty);

      // L'app est fermée puis rouverte : tout est relu depuis les fichiers.
      app = await rouvrirApp(tester);
      final brouillons = await brouillonsSurDisque(tester);
      expect(brouillons, hasLength(1));
      expect(brouillons.single.emotion, Emotion.inoubliable);
      // Un lieu seulement proposé n'est écrit qu'à « Publier » : il est
      // reproposé à la réouverture.
      expect(brouillons.single.lieu, isNull);

      await ouvrirParcours(tester, app.envois);
      await attendreAffichage(tester, find.text('Continuer · 1'));
      expect(find.text('Continuer · 1'), findsOneWidget);
      await continuer(tester);

      expect(find.byType(EcranFinalisation), findsOneWidget);
      await attendreAffichage(tester, find.text('Le Comptoir'));
      expect(find.text('Le Comptoir'), findsOneWidget);

      await tester.tap(find.text('Publier'));
      await attendreAffichage(tester, find.byType(EcranCloche));
      await attendreFinCloche(tester);

      expect(resultat!.issue, IssueCloche.publie);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes.values.single['statut'], statutPublie);
      expect(await brouillonsSurDisque(tester), isEmpty);
    });

    testWidgets('publication interrompue avant le commit : rien n\'est '
        'publié, le brouillon est gardé puis republié', (tester) async {
      var app = await rouvrirApp(tester);
      final brouillon = await laisserPublicationInterrompue(
        tester,
        app,
        commitLance: false,
      );
      expect(depot.lignes[brouillon.id]!['statut'], statutBrouillon);

      app = await rouvrirApp(tester);
      final reprises = await hors(
        tester,
        () => app.envois.reprendre(auLancement: true),
      );

      expect(reprises.map((r) => r.issue), [IssueReprise.interrompue]);
      expect(depot.lignes, isEmpty);
      expect(depot.fichiers, isEmpty);
      expect(await brouillonsSurDisque(tester), hasLength(1));
      expect(await fileSurDisque(tester), isEmpty);

      // L'auteur reprend le brouillon et le publie, de bout en bout.
      await ouvrirParcours(tester, app.envois);
      await continuer(tester);
      expect(find.byType(EcranFinalisation), findsOneWidget);
      await tester.tap(find.text('Publier'));
      await attendreAffichage(tester, find.byType(EcranCloche));
      await attendreFinCloche(tester);

      expect(resultat!.issue, IssueCloche.publie);
      expect(depot.lignes, hasLength(1));
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect(await brouillonsSurDisque(tester), isEmpty);
    });

    testWidgets('interrompue après le commit : menée à terme, le brouillon '
        'local est oublié', (tester) async {
      var app = await rouvrirApp(tester);
      final brouillon = await laisserPublicationInterrompue(
        tester,
        app,
        commitLance: true,
      );

      app = await rouvrirApp(tester);
      final reprises = await hors(
        tester,
        () => app.envois.reprendre(auLancement: true),
      );

      expect(reprises.map((r) => r.issue), [IssueReprise.publiee]);
      expect(depot.lignes[brouillon.id]!['statut'], statutPublie);
      expect(depot.lignes, hasLength(1));
      expect(await brouillonsSurDisque(tester), isEmpty);
      expect(await fileSurDisque(tester), isEmpty);
    });
  });
}
