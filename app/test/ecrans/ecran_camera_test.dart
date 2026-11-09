import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/ecrans/creation_moment.dart';
import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

late BrouillonsLocaux brouillons;

void main() {
  late Directory racine;
  late DateTime maintenant;
  late int compteur;

  late FausseCamera camera;
  late List<Brouillon> continues;

  setUp(() {
    racine = Directory.systemTemp.createTempSync('ecran_camera_test');
    maintenant = DateTime(2026, 11, 8, 12, 30);
    compteur = 0;
    continues = [];
    brouillons = BrouillonsLocaux(
      racine,
      maintenant: () => maintenant,
      genererId: () => 'id${++compteur}',
    );
    camera = FausseCamera(octetsPhoto: _png, maintenant: () => maintenant);
  });

  tearDown(() => racine.deleteSync(recursive: true));

  Future<void> ouvrir(
    WidgetTester tester, {
    ChoisirPhotos? choisirPhotos,
    bool animations = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: !animations),
          child: EcranCamera(
            camera: camera,
            brouillons: brouillons,
            maintenant: () => maintenant,
            choisirPhotos: choisirPhotos ?? (_) async => const [],
            surContinuer: continues.add,
          ),
        ),
      ),
    );
    await attendre(tester);
  }

  Future<void> deposer(WidgetTester tester) async {
    await tester.runAsync(() async {
      await brouillons.ajouterPhoto(octets: _png, priseLe: maintenant);
    });
  }

  Future<void> terminer(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('sans brouillon : viseur, Importer, pas de Continuer', (
    tester,
  ) async {
    await ouvrir(tester);

    expect(camera.etat.value, EtatCamera.prete);
    expect(find.byKey(const Key('apercu_fausse_camera')), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);
    expect(find.textContaining('Continuer'), findsNothing);
    expect(find.text('Sans photo'), findsNothing);
    expect(find.text('Autre repas'), findsNothing);
    await terminer(tester);
  });

  testWidgets('une photo : gardée dans le brouillon, Continuer · 1', (
    tester,
  ) async {
    await ouvrir(tester);

    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    expect(camera.photosPrises, hasLength(1));
    final liste = await gardes(tester);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(1));
    expect(find.text('Continuer · 1'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);
    await terminer(tester);
  });

  testWidgets('deux photos rapprochées : un seul brouillon', (tester) async {
    await ouvrir(tester);

    await tester.tap(find.byType(DeclencheurCamera));
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(2));
    expect(find.text('Continuer · 2'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('Continuer rend le brouillon prêt à compléter', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    await tester.tap(find.text('Continuer · 1'));
    await attendre(tester);

    expect(continues, hasLength(1));
    expect(continues.single.photos, hasLength(1));
    await terminer(tester);
  });

  testWidgets('bandeau « Suite du repas » puis « Autre repas »', (
    tester,
  ) async {
    await deposer(tester);
    maintenant = maintenant.add(const Duration(minutes: 2));
    await ouvrir(tester);

    expect(find.text('Suite du repas de 12 h 30'), findsOneWidget);
    expect(find.text('Autre repas'), findsOneWidget);
    expect(find.text('Continuer · 1'), findsOneWidget);

    await tester.tap(find.text('Autre repas'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester);
    expect(liste, hasLength(2));
    await terminer(tester);
  });

  testWidgets('retour après 10 min : carte de reprise', (tester) async {
    await deposer(tester);
    maintenant = maintenant.add(const Duration(minutes: 12));
    await ouvrir(tester);

    expect(find.text('Repas en cours'), findsOneWidget);
    expect(find.text('Finaliser'), findsOneWidget);
    expect(find.text('Nouveau moment'), findsOneWidget);
    expect(find.text('Suite du repas de 12 h 30'), findsNothing);

    await tester.tap(find.text('Finaliser'));
    await attendre(tester);
    expect(continues, hasLength(1));
    await terminer(tester);
  });

  testWidgets('« Nouveau moment » sur la carte de reprise : autre brouillon', (
    tester,
  ) async {
    await deposer(tester);
    maintenant = maintenant.add(const Duration(minutes: 12));
    await ouvrir(tester);

    await tester.tap(find.text('Nouveau moment'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester);
    expect(liste, hasLength(2));
    await terminer(tester);
  });

  testWidgets('brouillon de plus de 3 h : « Nouveau repas » proposé', (
    tester,
  ) async {
    await deposer(tester);
    maintenant = maintenant.add(const Duration(hours: 4));
    await ouvrir(tester);

    expect(find.text('Nouveau repas'), findsOneWidget);
    expect(find.text("C'est la suite de 12 h 30"), findsOneWidget);

    await tester.tap(find.text("C'est la suite de 12 h 30"));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(2));
    await terminer(tester);
  });

  testWidgets('Importer : les photos choisies rejoignent le brouillon', (
    tester,
  ) async {
    int? demande;
    await ouvrir(
      tester,
      choisirPhotos: (restant) async {
        demande = restant;
        return [_png, Uint8List.fromList(_png)];
      },
    );

    await tester.tap(find.text('Importer'));
    await attendre(tester);

    expect(demande, nombreMaxPhotosSouvenir);
    final liste = await gardes(tester);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(2));
    expect(find.text('Continuer · 2'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('caméra refusée : message, Importer reste possible', (
    tester,
  ) async {
    camera = FausseCamera(etatAtteint: EtatCamera.refusee);
    await ouvrir(tester);

    expect(find.textContaining('refusé'), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('fermer l\'écran libère la caméra', (tester) async {
    await ouvrir(tester);
    expect(camera.ouverte, isTrue);

    await terminer(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));

    expect(camera.ouverte, isFalse);
  });

  testWidgets('fermer garde le brouillon', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    final liste = await gardes(tester);
    expect(liste, hasLength(1));
    await terminer(tester);
  });
}

/// Le contenu du téléphone, une fois les écritures en cours rangées.
Future<List<Brouillon>> gardes(WidgetTester tester) async {
  List<Brouillon>? lus;
  unawaited(brouillons.lister().then((v) => lus = v));
  for (var i = 0; i < 100 && lus == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return lus!;
}

/// Les écritures sur disque se font hors horloge simulée : on alterne
/// attente réelle et rendu jusqu'à ce que tout soit rangé.
Future<void> attendre(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}
