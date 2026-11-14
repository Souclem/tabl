import 'dart:convert';
import 'dart:io';

import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pause(WidgetTester t, String nom) async {
  await t.pump(const Duration(milliseconds: 300));
  debugPrint('CAPTURE:$nom');
  await Future<void>.delayed(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('écran caméra', (tester) async {
    final racine = Directory.systemTemp.createTempSync('cam_visuel');
    var maintenant = DateTime.now();
    final brouillons = BrouillonsLocaux(racine, maintenant: () => maintenant);
    final camera = FausseCamera(
      octetsPhoto: _png,
      maintenant: () => maintenant,
    );

    Future<void> ouvrir({Brouillon? brouillon}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EcranCamera(
            camera: camera,
            brouillons: brouillons,
            brouillon: brouillon,
            maintenant: () => maintenant,
            choisirPhotos: (_) async => const [],
            surContinuer: (_) {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await ouvrir();
    await _pause(tester, 'camera_vide');

    // Un brouillon repris dans « Brouillons » : ses photos sont là.
    final repris = await tester.runAsync(() async {
      final b = await brouillons.ajouterPhoto(
        octets: _png,
        priseLe: maintenant,
      );
      return brouillons.ajouterPhoto(
        octets: _png,
        priseLe: maintenant,
        brouillonId: b.id,
      );
    });
    await tester.pumpWidget(const SizedBox());
    await ouvrir(brouillon: repris);
    await _pause(tester, 'camera_deux_photos');
  });
}
