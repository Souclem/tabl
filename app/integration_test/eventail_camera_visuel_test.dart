import 'dart:convert';
import 'dart:io';

import 'package:app/ecrans/ecran_camera.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

Future<void> _pause(WidgetTester t, String nom) async {
  await t.pump(const Duration(milliseconds: 400));
  debugPrint('CAPTURE:$nom');
  await Future<void>.delayed(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('éventail caméra', (tester) async {
    final racine = Directory.systemTemp.createTempSync('cam_eventail');
    final maintenant = DateTime.now();
    final brouillons = BrouillonsLocaux(racine, maintenant: () => maintenant);
    final camera = FausseCamera(
      octetsPhoto: _png,
      maintenant: () => maintenant,
    );
    final brouillon = await tester.runAsync(() async {
      Brouillon? b;
      for (var i = 0; i < 4; i++) {
        b = await brouillons.ajouterPhoto(
          octets: _png,
          priseLe: maintenant,
          brouillonId: b?.id,
        );
      }
      return b;
    });
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
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await _pause(tester, 'eventail_0_pile');

    await tester.tap(find.byType(PilePhotosCamera));
    await tester.pump(const Duration(seconds: 1));
    await _pause(tester, 'eventail_1_ouvert');

    final photo = find
        .descendant(
          of: find.byType(EventailPhotosCamera),
          matching: find.byType(Image),
        )
        .first;
    final g = await tester.startGesture(tester.getCenter(photo));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveBy(const Offset(60, 200));
    await tester.pump(const Duration(milliseconds: 200));
    await g.moveTo(tester.getCenter(find.text('Supprimer')));
    await tester.pump(const Duration(milliseconds: 300));
    await _pause(tester, 'eventail_2_glisser');
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));
    await _pause(tester, 'eventail_3_toast');
    await tester.pump(const Duration(seconds: 2));
    await _pause(tester, 'eventail_4_apres');
    expect(find.text('Photo supprimée'), findsOneWidget);
  });
}
