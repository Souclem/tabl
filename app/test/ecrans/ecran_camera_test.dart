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
    Brouillon? brouillon,
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
            brouillon: brouillon,
            maintenant: () => maintenant,
            choisirPhotos: choisirPhotos ?? (_) async => const [],
            surContinuer: continues.add,
          ),
        ),
      ),
    );
    await attendre(tester);
  }

  /// Une photo gardée sur le téléphone, dans [dans] ou un nouveau
  /// brouillon ; rend le brouillon.
  Future<Brouillon> deposer(WidgetTester tester, {Brouillon? dans}) async {
    final b = await tester.runAsync(
      () => brouillons.ajouterPhoto(
        octets: _png,
        priseLe: maintenant,
        brouillonId: dans?.id,
      ),
    );
    return b!;
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
    await terminer(tester);
  });

  testWidgets('une photo : gardée dans le brouillon, Continuer · 1', (
    tester,
  ) async {
    await ouvrir(tester);

    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    expect(camera.photosPrises, hasLength(1));
    final liste = await gardes(tester, photos: 1);
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
    final liste = await gardes(tester, photos: 2);
    await attendre(tester);

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

  testWidgets('au-delà de dix photos, « Continuer » refuse et dit pourquoi', (
    tester,
  ) async {
    var repris = await deposer(tester);
    for (var i = 1; i < 13; i++) {
      repris = await deposer(tester, dans: repris);
    }
    await ouvrir(tester, brouillon: repris);

    final bouton = tester.widget<BoutonContinuerCamera>(
      find.byType(BoutonContinuerCamera),
    );
    expect(bouton.grise, isTrue);
    await tester.tap(find.text('Continuer · 13'));
    await tester.pump();

    expect(continues, isEmpty);
    expect(find.text(libelleTropDePhotos(13)), findsOneWidget);
    expect(
      tester
          .widget<BoutonContinuerCamera>(find.byType(BoutonContinuerCamera))
          .refus,
      1,
    );
    await terminer(tester);
  });

  testWidgets('ouverte sur un brouillon : ses photos, les nouvelles '
      's\'y ajoutent, même des heures plus tard', (tester) async {
    final repris = await deposer(tester);
    maintenant = maintenant.add(const Duration(hours: 5));
    await ouvrir(tester, brouillon: repris);

    expect(find.text('Continuer · 1'), findsOneWidget);
    expect(find.text('Importer'), findsNothing);

    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester, photos: 2);
    expect(liste, hasLength(1));
    expect(liste.single.id, repris.id);
    expect(liste.single.photos, hasLength(2));
    expect(find.text('Continuer · 2'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('nouveau moment à côté d\'un brouillon : il reste à part', (
    tester,
  ) async {
    final autre = await deposer(tester);
    await ouvrir(tester);

    expect(find.text('Importer'), findsOneWidget);
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    final liste = await gardes(tester, photos: 2);
    expect(liste, hasLength(2));
    expect(liste.firstWhere((b) => b.id == autre.id).photos, hasLength(1));
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
    final liste = await gardes(tester, photos: 2);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(2));
    expect(find.text('Continuer · 2'), findsOneWidget);
    await terminer(tester);
  });

  testWidgets('importer une deuxième fois : les photos se cumulent', (
    tester,
  ) async {
    var appel = 0;
    await ouvrir(
      tester,
      choisirPhotos: (restant) async {
        appel++;
        return appel == 1
            ? [_png, Uint8List.fromList(_png), Uint8List.fromList(_png)]
            : [Uint8List.fromList(_png)];
      },
    );

    await tester.tap(find.text('Importer'));
    await attendre(tester);
    await gardes(tester, photos: 3);
    expect(find.text('Continuer · 3'), findsOneWidget);

    // Plus tard (une photo sans date prend l'heure de l'import) : avant,
    // la quatrième partait dans un autre brouillon et les trois premières
    // disparaissaient de la caméra.
    maintenant = maintenant.add(const Duration(hours: 4));
    await tester.tap(find.byType(PilePhotosCamera));
    await attendre(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(EventailPhotosCamera),
        matching: find.text('Importer'),
      ),
    );
    await attendre(tester);

    final liste = await gardes(tester, photos: 4);
    expect(liste, hasLength(1));
    expect(liste.single.photos, hasLength(4));
    expect(find.text('Continuer · 4'), findsOneWidget);
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

  testWidgets('éventail : × retire la photo, « Annuler » la remet', (
    tester,
  ) async {
    final b = await deposer(tester);
    await ouvrir(tester, brouillon: await deposer(tester, dans: b));

    await tester.tap(find.byType(PilePhotosCamera));
    await attendre(tester);
    expect(find.byType(EventailPhotosCamera), findsOneWidget);
    expect(find.text('Importer'), findsOneWidget);

    await tester.tap(
      find
          .descendant(
            of: find.byType(EventailPhotosCamera),
            matching: find.byIcon(Icons.close_rounded),
          )
          .first,
    );
    await attendreQue(tester, find.text('Photo supprimée'));

    expect(find.text('Photo supprimée'), findsOneWidget);
    var liste = await gardes(tester, photos: 1);
    expect(liste.single.photos, hasLength(1));

    await tester.tap(find.text('Annuler'));
    await attendre(tester);

    liste = await gardes(tester, photos: 2);
    expect(liste.single.photos, hasLength(2));
    await terminer(tester);
  });

  testWidgets('éventail : une photo glissée à une autre place change '
      'l\'ordre du brouillon', (tester) async {
    var b = await deposer(tester);
    b = await deposer(tester, dans: b);
    b = await deposer(tester, dans: b);
    final ids = [for (final p in b.photos) p.id];
    await ouvrir(tester, brouillon: b);

    await tester.tap(find.byType(PilePhotosCamera));
    await attendre(tester);
    // Dans l'ordre de publication : la première en haut de l'arc.
    final premiere = find.byKey(ValueKey(ids.first));
    final derniere = tester.getCenter(find.byKey(ValueKey(ids.last)));
    final geste = await tester.startGesture(tester.getCenter(premiere));
    await tester.pump(delaiSaisieEventail + const Duration(milliseconds: 40));
    await geste.moveTo(derniere);
    await tester.pump(const Duration(milliseconds: 50));
    await geste.up();
    await attendre(tester);

    final relu = await tester.runAsync(() => brouillons.charger(b.id));
    expect([for (final p in relu!.photos) p.id], [ids[1], ids[2], ids[0]]);
    await terminer(tester);
  });

  testWidgets('fermer garde le brouillon', (tester) async {
    await ouvrir(tester);
    await tester.tap(find.byType(DeclencheurCamera));
    await attendre(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump(const Duration(milliseconds: 300));

    final liste = await gardes(tester, photos: 1);
    expect(liste, hasLength(1));
    await terminer(tester);
  });
}

/// Le contenu du téléphone, relu jusqu'à ce qu'il contienne au moins
/// [photos] photos (limite 10 s). Les écritures se font hors horloge
/// simulée : on alterne attente réelle et rendu, sans jamais bloquer dessus.
Future<List<Brouillon>> gardes(WidgetTester tester, {int photos = 0}) async {
  final fin = DateTime.now().add(const Duration(seconds: 10));
  var lus = <Brouillon>[];
  while (true) {
    List<Brouillon>? relus;
    unawaited(brouillons.lister().then((v) => relus = v));
    while (relus == null && DateTime.now().isBefore(fin)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    lus = relus ?? lus;
    final total = lus.fold<int>(0, (somme, b) => somme + b.photos.length);
    if (relus == null || total >= photos || DateTime.now().isAfter(fin)) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
  return lus;
}

/// Laisse l'écran rendre ce qui est en cours.
Future<void> attendreQue(WidgetTester tester, Finder finder) async {
  final fin = DateTime.now().add(const Duration(seconds: 10));
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(fin)) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
}

Future<void> attendre(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 400));
}
