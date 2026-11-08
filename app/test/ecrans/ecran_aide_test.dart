import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_aide.dart';

// Un vrai PNG 1×1 : Image.memory décode réellement les vignettes.
final _capture = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

/// Faux [ImagePickerPlatform] : la photothèque « contient » [nombre]
/// captures, toutes choisies d'un coup.
class _FauxImagePickerPlatform extends ImagePickerPlatform {
  _FauxImagePickerPlatform(this.nombre);

  final int nombre;

  XFile get _fichier =>
      XFile.fromData(_capture, name: 'capture.png', mimeType: 'image/png');

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => _fichier;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async => [for (var i = 0; i < nombre; i++) _fichier];
}

class _FauxRetourService implements RetourService {
  _FauxRetourService({this.erreur = false});

  final bool erreur;
  final List<({TypeRetour type, String texte, int captures})> envoyes = [];

  @override
  Future<void> envoyer({
    required TypeRetour type,
    required String texte,
    List<Uint8List> captures = const [],
  }) async {
    if (erreur) throw Exception('erreur réseau');
    envoyes.add((type: type, texte: texte, captures: captures.length));
  }
}

Future<void> _ouvrir(WidgetTester tester, _FauxRetourService service) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: EcranAide(retourService: service),
    ),
  );
}

bool _envoiPossible(WidgetTester tester) =>
    tester.widget<TablBouton>(find.byType(TablBouton)).onPresse != null;

void main() {
  testWidgets('choisir le type, écrire, envoyer : merci', (tester) async {
    final service = _FauxRetourService();
    await _ouvrir(tester, service);

    expect(find.text('Un bug'), findsOneWidget);
    expect(find.text('Un lieu à corriger'), findsOneWidget);
    // Rien à envoyer tant qu'on n'a ni choisi ni écrit.
    expect(_envoiPossible(tester), isFalse);

    await tester.tap(find.text('Un bug'));
    await tester.pump();
    // Le champ s'adapte au type choisi.
    expect(
      find.text('Que s’est-il passé ? Qu’attendais-tu à la place ?'),
      findsOneWidget,
    );
    expect(_envoiPossible(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'La carte reste blanche.');
    await tester.pump();
    expect(_envoiPossible(tester), isTrue);

    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(service.envoyes.single.type, TypeRetour.bug);
    expect(service.envoyes.single.texte, 'La carte reste blanche.');
    expect(service.envoyes.single.captures, 0);
    expect(find.text('Merci !'), findsOneWidget);
  });

  testWidgets('captures : 3 au plus, et on peut en retirer', (tester) async {
    ImagePickerPlatform.instance = _FauxImagePickerPlatform(5);
    final service = _FauxRetourService();
    await _ouvrir(tester, service);

    await tester.tap(find.byTooltip('Ajouter une capture d’écran'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer la capture'), findsNWidgets(3));
    // Plus de place : la case « Ajouter » disparaît.
    expect(find.byTooltip('Ajouter une capture d’écran'), findsNothing);

    await tester.tap(find.byTooltip('Retirer la capture').first);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Retirer la capture'), findsNWidgets(2));

    await tester.tap(find.text('Une idée'));
    await tester.enterText(find.byType(TextField), 'Un mode sombre plus doux.');
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();
    expect(service.envoyes.single.type, TypeRetour.idee);
    expect(service.envoyes.single.captures, 2);
  });

  testWidgets('échec de l\'envoi : message, et rien n\'est perdu', (
    tester,
  ) async {
    await _ouvrir(tester, _FauxRetourService(erreur: true));

    await tester.tap(find.text('Pas clair'));
    await tester.enterText(find.byType(TextField), 'Comment créer une Table ?');
    await tester.pump();
    await tester.tap(find.text('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
    expect(find.text('Merci !'), findsNothing);
    expect(find.text('Comment créer une Table ?'), findsOneWidget);
  });
}
