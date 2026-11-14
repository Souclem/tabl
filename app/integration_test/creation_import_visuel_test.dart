import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/ecrans/ecran_finalisation.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

const _comptoir = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
  latitude: 50.6327,
  longitude: 5.5799,
);

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<bool> monProfilEstPrive() async => false;
  @override
  Future<Set<String>> mesAbonnesIds() async => {};
  @override
  Future<List<ProfilPublic>> mesRelations() async => const [
    ProfilPublic(id: 'u1', pseudo: 'lea', statut: StatutAbonnement.abonne),
    ProfilPublic(id: 'u2', pseudo: 'marc', statut: StatutAbonnement.abonne),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FausseRechercheLieu implements RechercheLieuService {
  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async => [_comptoir];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PositionFixe implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.63, longitude: 5.57);
}

class _FauxEnvois implements EnvoiPublications {
  _FauxEnvois(this.brouillons);
  @override
  final BrouillonsLocaux brouillons;
  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 6));
    return const ResultatEnvoi(StatutEnvoi.publie);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Future<Uint8List> _image(int i) async {
  const fonds = [0xFFC8553D, 0xFF588157, 0xFFE9B44C, 0xFF3D5A80, 0xFF8E5572];
  final enregistreur = ui.PictureRecorder();
  final toile = ui.Canvas(enregistreur);
  toile.drawRect(
    const Rect.fromLTWH(0, 0, 900, 1200),
    Paint()..color = Color(fonds[i % fonds.length]),
  );
  toile.drawCircle(
    const Offset(450, 600),
    300,
    Paint()..color = const Color(0xFFF5EFE6),
  );
  toile.drawCircle(
    const Offset(450, 600),
    190,
    Paint()..color = Color(fonds[(i + 2) % fonds.length]),
  );
  final image = await enregistreur.endRecording().toImage(900, 1200);
  final octets = await image.toByteData(format: ui.ImageByteFormat.png);
  return octets!.buffer.asUint8List();
}

Future<void> _pause(WidgetTester t, String nom) async {
  await t.pump(const Duration(milliseconds: 500));
  debugPrint('CAPTURE:$nom');
  await Future<void>.delayed(const Duration(seconds: 2));
}

Future<void> _attendre(WidgetTester t, {int tours = 20}) async {
  for (var i = 0; i < tours; i++) {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('création : import, éventail, finalisation, cloche', (
    tester,
  ) async {
    final racine = Directory.systemTemp.createTempSync('creation_import');
    final maintenant = DateTime.now();
    final brouillons = BrouillonsLocaux(racine, maintenant: () => maintenant);
    final camera = FausseCamera(
      octetsPhoto: _png,
      maintenant: () => maintenant,
    );
    final envois = _FauxEnvois(brouillons);
    final photos = <Uint8List>[];
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        photos.add(await _image(i));
      }
    });

    final cle = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: cle,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) => EcranCamera(
                      camera: camera,
                      brouillons: brouillons,
                      positionService: _PositionFixe(),
                      maintenant: () => maintenant,
                      choisirPhotos: (_) async => photos,
                      surContinuer: (b) => cle.currentState!.pushReplacement(
                        MaterialPageRoute<ResultatCloche>(
                          builder: (_) => EcranFinalisation(
                            souvenirService: _FauxSouvenirService(),
                            abonnementService: _FauxAbonnementService(),
                            brouillons: brouillons,
                            brouillon: b,
                            envois: envois,
                            rechercheLieuService: _FausseRechercheLieu(),
                            positionService: _PositionFixe(),
                            maintenant: () => maintenant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('Fil'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fil'));
    await _attendre(tester, tours: 40);
    await _pause(tester, 'creation_1_camera');

    await tester.tap(find.text('Importer'));
    await _attendre(tester, tours: 80);
    await _pause(tester, 'creation_2_pile');

    await tester.tap(find.byType(PilePhotosCamera));
    await _attendre(tester, tours: 30);
    await _pause(tester, 'creation_3_eventail');

    await tester.tapAt(const Offset(20, 120));
    await _attendre(tester, tours: 20);
    await tester.tap(find.textContaining('Continuer'));
    await _attendre(tester, tours: 60);
    await _pause(tester, 'creation_4_finalisation');

    await tester.tap(find.text('🤩'));
    await _attendre(tester, tours: 10);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await _attendre(tester, tours: 20);
    await tester.enterText(find.byType(TextField), 'Le meilleur risotto');
    await _attendre(tester, tours: 10);
    await _pause(tester, 'creation_5_mot');
    await tester.tapAt(const Offset(200, 60));
    await _attendre(tester, tours: 20);

    await tester.tap(find.text('Ce qui ressort'));
    await _attendre(tester, tours: 20);
    await tester.tap(find.byKey(const ValueKey('etoile-ambiance-4')));
    await _attendre(tester, tours: 10);
    await _pause(tester, 'creation_6_ce_qui_ressort');
    await tester.tapAt(const Offset(200, 60));
    await _attendre(tester, tours: 20);

    await tester.tap(find.text('Avec qui'));
    await _attendre(tester, tours: 20);
    await tester.tap(find.text('lea'));
    await _attendre(tester, tours: 10);
    await _pause(tester, 'creation_7_avec_qui');
    await tester.tap(find.textContaining('Valider'));
    await _attendre(tester, tours: 20);

    await tester.tap(find.byType(TablPiluleAudience));
    await _attendre(tester, tours: 20);
    await _pause(tester, 'creation_8_audience');
    await tester.tap(find.text('Enregistrer'));
    await _attendre(tester, tours: 20);

    await tester.tap(find.text('Publier'));
    await _attendre(tester, tours: 10);
    await _pause(tester, 'creation_9_cloche');
  });
}
