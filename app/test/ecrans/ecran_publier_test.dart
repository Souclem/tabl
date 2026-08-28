import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_publier.dart';

/// Faux [ImagePickerPlatform] : évite tout appel plateforme réel (aucune
/// caméra/photothèque dans les tests). Renvoie toujours les mêmes octets
/// tant qu'un fichier est "disponible", ou `null` pour simuler une
/// sélection annulée par l'utilisateur.
class _FauxImagePickerPlatform extends ImagePickerPlatform {
  _FauxImagePickerPlatform({this.octets});

  final Uint8List? octets;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    final o = octets;
    if (o == null) return null;
    return XFile.fromData(o, name: 'photo.jpg', mimeType: 'image/jpeg');
  }
}

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService({this.erreur = false});

  final bool erreur;
  final List<Map<String, Object?>> appels = [];

  @override
  Future<void> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    String? legende,
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appels.add({
      'nomRestaurant': nomRestaurant,
      'ville': ville,
      'photo': photo,
      'legende': legende,
    });
  }

  @override
  Future<List<SouvenirFeed>> feed() => throw UnimplementedError();
  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) =>
      throw UnimplementedError();

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) =>
      throw UnimplementedError();

  @override
  Future<void> commenter(String souvenirId, String texte) =>
      throw UnimplementedError();

  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
}

// Un vrai PNG 1×1 valide (pas des octets arbitraires) : Image.memory
// décode réellement le contenu dans les tests, un contenu invalide fait
// planter le codec de manière asynchrone.
final _octetsPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

/// Pousse EcranPublier sur une pile de navigation réelle (pour que
/// `Navigator.pop()` à la publication ait un écran en dessous, comme en
/// vrai — poussé depuis EcranPrincipal).
Future<void> _ouvrirEcranPublier(
  WidgetTester tester,
  SouvenirService service,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EcranPublier(souvenirService: service),
              ),
            ),
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
}

/// Depuis l'étape 1 : choisit une photo (galerie) et avance jusqu'à
/// l'étape 3 (formulaire restaurant), sans rien y remplir.
Future<void> _avancerJusquauFormulaire(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choisir depuis la photothèque'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  expect(find.text('Comment c\'était ?'), findsOneWidget);

  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  expect(find.text('Racontez le souvenir.'), findsOneWidget);
}

void main() {
  setUp(() {
    ImagePickerPlatform.instance = _FauxImagePickerPlatform(
      octets: _octetsPhoto,
    );
  });

  testWidgets('étape 1 : "Continuer" désactivé tant qu\'aucune photo', (
    tester,
  ) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());

    expect(find.text('Capturez ce moment.'), findsOneWidget);
    final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(bouton.onPressed, isNull);
  });

  testWidgets('choisir une photo active "Continuer"', (tester) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Choisir depuis la photothèque'), findsOneWidget);
    expect(find.text('Prendre une photo'), findsOneWidget);

    await tester.tap(find.text('Choisir depuis la photothèque'));
    await tester.pumpAndSettle();

    final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(bouton.onPressed, isNotNull);
  });

  testWidgets('sélection annulée : reste bloqué à l\'étape 1', (tester) async {
    ImagePickerPlatform.instance = _FauxImagePickerPlatform(octets: null);
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir depuis la photothèque'));
    await tester.pumpAndSettle();

    expect(find.text('Capturez ce moment.'), findsOneWidget);
    final bouton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(bouton.onPressed, isNull);
  });

  testWidgets('étape 3 : nom et ville vides → erreurs, rien publié', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(tester, service);
    await _avancerJusquauFormulaire(tester);

    await tester.tap(find.text('Publier ce souvenir'));
    await tester.pumpAndSettle();

    expect(find.text('Entre le nom du restaurant.'), findsOneWidget);
    expect(find.text('Entre la ville.'), findsOneWidget);
    expect(service.appels, isEmpty);
  });

  testWidgets('parcours complet : photo → phrase → restaurant → publication', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(tester, service);
    await _avancerJusquauFormulaire(tester);

    await tester.enterText(find.byType(TextField).first, 'Le Comptoir');
    await tester.enterText(find.byType(TextField).last, 'Paris');
    await tester.tap(find.text('Publier ce souvenir'));
    await tester.pumpAndSettle();

    expect(service.appels, hasLength(1));
    expect(service.appels.single['nomRestaurant'], 'Le Comptoir');
    expect(service.appels.single['ville'], 'Paris');
    // Première phrase présélectionnée par défaut, jamais changée ici.
    expect(service.appels.single['legende'], 'Belle découverte.');
    expect(service.appels.single['photo'], _octetsPhoto);

    // De retour sur l'écran précédent, avec le message de succès.
    expect(find.byType(EcranPublier), findsNothing);
    expect(find.text('Souvenir publié.'), findsOneWidget);
  });

  testWidgets('changer la phrase à l\'étape 2 change la légende publiée', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(tester, service);

    await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choisir depuis la photothèque'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Inoubliable.'));
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Le Comptoir');
    await tester.enterText(find.byType(TextField).last, 'Paris');
    await tester.tap(find.text('Publier ce souvenir'));
    await tester.pumpAndSettle();

    expect(service.appels.single['legende'], 'Inoubliable.');
  });

  testWidgets('erreur du service à la publication → message générique', (
    tester,
  ) async {
    final service = _FauxSouvenirService(erreur: true);
    await _ouvrirEcranPublier(tester, service);
    await _avancerJusquauFormulaire(tester);

    await tester.enterText(find.byType(TextField).first, 'Le Comptoir');
    await tester.enterText(find.byType(TextField).last, 'Paris');
    await tester.tap(find.text('Publier ce souvenir'));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
    // Toujours sur l'écran de publication : pas de pop en cas d'échec.
    expect(find.byType(EcranPublier), findsOneWidget);
  });
}
