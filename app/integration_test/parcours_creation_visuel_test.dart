import 'dart:convert';
import 'dart:io';

import 'package:app/ecrans/parcours_creation.dart';
import 'package:app/widgets/widgets.dart';
import 'package:app/services/services.dart';
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
  Future<List<ProfilPublic>> mesRelations() async => const [];
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

  testWidgets('parcours de création', (tester) async {
    final racine = Directory.systemTemp.createTempSync('parcours_visuel');
    final maintenant = DateTime.now();
    final brouillons = BrouillonsLocaux(racine, maintenant: () => maintenant);
    final camera = FausseCamera(
      octetsPhoto: _png,
      maintenant: () => maintenant,
    );
    final envois = _FauxEnvois(brouillons);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => ParcoursCreation.ouvrir(
                  context,
                  souvenirService: _FauxSouvenirService(),
                  abonnementService: _FauxAbonnementService(),
                  camera: camera,
                  envois: envois,
                  rechercheLieuService: _FausseRechercheLieu(),
                  positionService: _PositionFixe(),
                  maintenant: () => maintenant,
                ),
                child: const Text('Fil'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Fil'));
    await _attendre(tester);
    await _pause(tester, 'parcours_1_camera');

    await tester.tap(find.byType(DeclencheurCamera));
    await _attendre(tester);
    await tester.tap(find.text('Continuer · 1'));
    await _attendre(tester);
    await _pause(tester, 'parcours_2_finalisation');

    await tester.tap(find.text('🤩'));
    await _attendre(tester, tours: 4);
    await tester.tap(find.text('Publier'));
    await _attendre(tester, tours: 10);
    await _pause(tester, 'parcours_3_cloche');
  });
}
