import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_creer_instant.dart';

/// Même principe que le faux de `ecran_finalisation_test.dart` : jamais de
/// vraie caméra dans les tests.
class _FauxImagePickerPlatform extends ImagePickerPlatform {
  _FauxImagePickerPlatform({this.octetsPhoto});

  final Uint8List? octetsPhoto;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    final o = octetsPhoto;
    if (o == null) return null;
    return XFile.fromData(o, name: 'instant.jpg', mimeType: 'image/jpeg');
  }
}

class _FauxInstantService implements InstantService {
  _FauxInstantService({this.exception});

  final Exception? exception;
  final List<Map<String, Object?>> appelsCreer = [];

  @override
  Future<void> creer({
    required String experienceId,
    required TypeMediaInstant type,
    required Uint8List media,
  }) async {
    final e = exception;
    if (e != null) throw e;
    appelsCreer.add({'experienceId': experienceId, 'type': type, 'media': media});
  }

  @override
  Future<List<InstantAffichable>> instantsDe(String experienceId) async => [];

  @override
  Future<void> marquerVu(String instantId) async {}

  @override
  Future<void> supprimer(String instantId) async {}

  @override
  Future<Map<String, SignalInstants>> signaux(List<String> experienceIds) async =>
      {};
}

// PNG 1×1 valide : le viewer/la prévisualisation décode réellement le
// contenu, un contenu invalide fait planter le codec de manière
// asynchrone (même fixture que `ecran_finalisation_test.dart`).
final _octetsPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

void main() {
  setUp(() {
    ImagePickerPlatform.instance = _FauxImagePickerPlatform(
      octetsPhoto: _octetsPhoto,
    );
  });

  testWidgets('capturer une photo puis "Ajouter" appelle le service et ferme', (
    tester,
  ) async {
    final service = _FauxInstantService();

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCreerInstant(
          instantService: service,
          experienceId: 'exp-1',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tabl_declencheur_instant')));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter'), findsOneWidget);
    expect(find.text('Reprendre'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(service.appelsCreer, hasLength(1));
    expect(service.appelsCreer.single['experienceId'], 'exp-1');
    expect(service.appelsCreer.single['type'], TypeMediaInstant.photo);
  });

  testWidgets('"Reprendre" revient à la vue caméra', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranCreerInstant(
          instantService: _FauxInstantService(),
          experienceId: 'exp-1',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tabl_declencheur_instant')));
    await tester.pumpAndSettle();
    expect(find.text('Reprendre'), findsOneWidget);

    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();

    expect(find.text('Reprendre'), findsNothing);
    expect(find.text('Maintenir pour une vidéo'), findsOneWidget);
  });

  testWidgets('limite atteinte : message dédié, reste sur la prévisualisation', (
    tester,
  ) async {
    final service = _FauxInstantService(
      exception: const LimiteInstantsAtteinteException(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCreerInstant(
          instantService: service,
          experienceId: 'exp-1',
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('tabl_declencheur_instant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();

    expect(
      find.text("Vous avez atteint le maximum d'Instants pour cette expérience."),
      findsOneWidget,
    );
    expect(find.text('Ajouter'), findsOneWidget);
  });
}
