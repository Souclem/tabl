import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_import_souvenirs.dart';

/// Photos JPEG de 8 × 8 pixels avec leurs métadonnées : deux du même
/// dîner (3 novembre 2023, 20 h 41 et 20 h 58, au même endroit), une
/// d'un déjeuner (10 février 2024, 12 h 30, à Bruxelles).
final _diner1 = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QESRXhpZgAATU0AKgAAAAgAAwEyAAIAAAAUAAAA'
  'ModpAAQAAAABAAAARoglAAQAAAABAAAApAAAAAAyMDIzOjExOjAzIDIwOjQxOjEyAAAE'
  'kAMAAgAAABQAAAB8kAQAAgAAABQAAACQoAIABAAAAAEAAAAIoAMABAAAAAEAAAAIAAAA'
  'ADIwMjM6MTE6MDMgMjA6NDE6MTIAMjAyMzoxMTowMyAyMDo0MToxMgAABAABAAIAAAAC'
  'TgAAAAACAAUAAAADAAAA2gADAAIAAAACVwAAAAAEAAUAAAADAAAA8gAAAAAAAAAyAAAA'
  'AQAAACYAAAABAAATtgAAAGQAAAAFAAAAAQAAACIAAAABAAATYgAAAGT/7QA4UGhvdG9z'
  'aG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AA'
  'EQgACAAIAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//E'
  'ALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHw'
  'JDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0'
  'dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS'
  '09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAAB'
  'AgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKB'
  'CBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZX'
  'WFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2'
  't7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgIC'
  'AwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8P'
  'Dw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A8k8c+Bt3'
  'mRyR89jjrXlH/Cvv+mdfV/jz/WN9f615lX4phcVPkWp+54rB0+d6H//Z',
);
final _diner2 = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QESRXhpZgAATU0AKgAAAAgAAwEyAAIAAAAUAAAA'
  'ModpAAQAAAABAAAARoglAAQAAAABAAAApAAAAAAyMDIzOjExOjAzIDIwOjU4OjQwAAAE'
  'kAMAAgAAABQAAAB8kAQAAgAAABQAAACQoAIABAAAAAEAAAAIoAMABAAAAAEAAAAIAAAA'
  'ADIwMjM6MTE6MDMgMjA6NTg6NDAAMjAyMzoxMTowMyAyMDo1ODo0MAAABAABAAIAAAAC'
  'TgAAAAACAAUAAAADAAAA2gADAAIAAAACVwAAAAAEAAUAAAADAAAA8gAAAAAAAAAyAAAA'
  'AQAAACYAAAABAAATwQAAAGQAAAAFAAAAAQAAACIAAAABAAATVAAAAGT/7QA4UGhvdG9z'
  'aG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AA'
  'EQgACAAIAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//E'
  'ALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHw'
  'JDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0'
  'dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS'
  '09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAAB'
  'AgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKB'
  'CBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZX'
  'WFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2'
  't7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgIC'
  'AwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8P'
  'Dw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A+WPGHg/d'
  'vR057GvNf+EI/wBj9K+lPGX+tb61wFfplehHmPYlFXP/2Q==',
);
final _dejeuner = base64Decode(
  '/9j/4AAQSkZJRgABAQAASABIAAD/4QESRXhpZgAATU0AKgAAAAgAAwEyAAIAAAAUAAAA'
  'ModpAAQAAAABAAAARoglAAQAAAABAAAApAAAAAAyMDI0OjAyOjEwIDEyOjMwOjA1AAAE'
  'kAMAAgAAABQAAAB8kAQAAgAAABQAAACQoAIABAAAAAEAAAAIoAMABAAAAAEAAAAIAAAA'
  'ADIwMjQ6MDI6MTAgMTI6MzA6MDUAMjAyNDowMjoxMCAxMjozMDowNQAABAABAAIAAAAC'
  'TgAAAAACAAUAAAADAAAA2gADAAIAAAACRQAAAAAEAAUAAAADAAAA8gAAAAAAAAAyAAAA'
  'AQAAADIAAAABAAASzAAAAGQAAAAEAAAAAQAAABUAAAABAAADhAAAAGT/7QA4UGhvdG9z'
  'aG9wIDMuMAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AA'
  'EQgACAAIAwEiAAIRAQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//E'
  'ALUQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHw'
  'JDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0'
  'dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS'
  '09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMBAQEBAQEBAQEAAAAAAAAB'
  'AgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYSQVEHYXETIjKB'
  'CBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNUVVZX'
  'WFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2'
  't7i5usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgIC'
  'AwICAwUDAwMFBgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8P'
  'Dw8PDw8PD//bAEMBAgICBAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ'
  'EBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A8V8b+CN3'
  'mRyR884OOteVf8IB/wBM/wBK+qfHf+sb6/1rzWv2LE4WHO9D8rw+InyLU//Z',
);

/// Une image sans métadonnées : rien ne dit de quel repas elle est.
final _sansRien = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService({this.empreintes = const {}});

  final Set<String> empreintes;
  final List<NouveauSouvenir> ajoutes = [];

  @override
  Future<Set<String>> empreintesImportees() async => empreintes;

  @override
  Future<List<String>> ajouterSouvenir(NouveauSouvenir souvenir) async {
    ajoutes.add(souvenir);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  @override
  Future<CompteursProfil> compteurs(String profilId) =>
      throw UnimplementedError();

  @override
  Future<String> definirPhotoProfil(Uint8List photo) =>
      throw UnimplementedError();
  @override
  Future<ProfilVisite> profil(String id) => throw UnimplementedError();

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async =>
      (abonnes: <ProfilPublic>[], abonnements: <ProfilPublic>[]);

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<bool> monProfilEstPrive() async => true;

  @override
  Future<void> definirProfilPrive(bool prive) async {}

  @override
  Future<List<ProfilPublic>> mesRelations() async => const [];

  @override
  Future<List<ProfilPublic>> rechercher(String requete) =>
      throw UnimplementedError();
  @override
  Future<StatutAbonnement> suivre(String suiviId) => throw UnimplementedError();
  @override
  Future<void> arreterDeSuivre(String suiviId) => throw UnimplementedError();
  @override
  Future<List<DemandeAbonnement>> demandesRecues() async => [];
  @override
  Future<void> accepterDemande(String suiveurId) => throw UnimplementedError();
  @override
  Future<void> refuserDemande(String suiveurId) => throw UnimplementedError();
  @override
  Future<int> nombreDemandesEnAttente() async => 0;
}

class _FausseRechercheLieu implements RechercheLieuService {
  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async => const [];

  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async => [if (latitude > 50.8) _laMaison else _comoEnCasa];
}

const _comoEnCasa = LieuRestaurant(
  fsqPlaceId: 'fsq-como',
  nom: 'Como en Casa',
  ville: 'Liège',
  distanceM: 40,
);

const _laMaison = LieuRestaurant(
  fsqPlaceId: 'fsq-maison',
  nom: 'La Maison',
  ville: 'Bruxelles',
  distanceM: 20,
);

/// Ouvre l'import par-dessus un écran témoin, qui note ce qu'il renvoie
/// en se fermant (le nombre de souvenirs ajoutés).
Future<List<int?>> _ouvrir(
  WidgetTester tester,
  _FauxSouvenirService service, {
  required List<Uint8List> photos,
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final retours = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              retours.add(
                await Navigator.of(context).push<int>(
                  MaterialPageRoute(
                    builder: (_) => EcranImportSouvenirs(
                      souvenirService: service,
                      abonnementService: _FauxAbonnementService(),
                      rechercheLieuService: _FausseRechercheLieu(),
                      choisirPhotos: (restant) async => photos,
                    ),
                  ),
                ),
              );
            },
            child: const Text('ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return retours;
}

/// De l'accueil à la revue.
Future<void> _choisir(WidgetTester tester) async {
  await tester.tap(find.text('Choisir des photos'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('les photos rangées en repas, le restaurant le plus proche '
      'proposé pour chacun', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService(),
      photos: [_dejeuner, _diner2, _sansRien, _diner1],
    );

    expect(
      find.text('Trois temps, et rien sans votre accord.'),
      findsOneWidget,
    );
    await _choisir(tester);

    expect(find.text('Repas retrouvés'), findsOneWidget);
    expect(find.byType(TablCarteRepas), findsNWidgets(2));
    // Du plus ancien au plus récent.
    expect(find.text('3 NOVEMBRE 2023 · DÎNER'), findsOneWidget);
    expect(find.text('10 FÉVRIER 2024 · DÉJEUNER'), findsOneWidget);
    expect(find.text('Como en Casa'), findsOneWidget);
    expect(find.text('La Maison'), findsOneWidget);
    expect(
      find.text('1 photo sans date ni lieu utilisable a été laissée de côté.'),
      findsOneWidget,
    );
  });

  testWidgets('un repas ajouté, puis le bilan', (tester) async {
    final service = _FauxSouvenirService();
    final retours = await _ouvrir(
      tester,
      service,
      photos: [_diner1, _diner2, _dejeuner],
    );
    await _choisir(tester);

    await tester.tap(find.text('Ajouter ce repas').first);
    await tester.pumpAndSettle();
    // L'écran du souvenir, déjà rempli : le restaurant de la revue.
    expect(find.text('Como en Casa'), findsOneWidget);
    await tester.tap(find.text('Ajouter à mon profil'));
    await tester.pumpAndSettle();

    final ajoute = service.ajoutes.single;
    expect(ajoute.lieu.nom, 'Como en Casa');
    expect(ajoute.photos, hasLength(2));
    expect(ajoute.date.libelle, '3 novembre 2023');
    expect(ajoute.empreintes, hasLength(2));
    expect(find.text('Ajouté'), findsOneWidget);

    await tester.tap(find.text('Terminer · 1 souvenir'));
    await tester.pumpAndSettle();
    expect(find.text('Vos souvenirs ont trouvé leur place.'), findsOneWidget);
    expect(find.text('souvenir ajouté'), findsOneWidget);
    expect(find.text('Novembre 2023'), findsOneWidget);

    await tester.tap(find.text('Voir mes souvenirs'));
    await tester.pumpAndSettle();
    expect(retours, [1]);
  });

  testWidgets('les photos déjà importées sont ignorées', (tester) async {
    final empreinte = (await lireMetadonnees(_dejeuner)).empreinte!;
    await _ouvrir(
      tester,
      _FauxSouvenirService(empreintes: {empreinte}),
      photos: [_diner1, _dejeuner],
    );
    await _choisir(tester);

    expect(find.byType(TablCarteRepas), findsOneWidget);
    expect(find.text('1 photo déjà importée a été ignorée.'), findsOneWidget);
  });

  testWidgets('une photo mise à part devient un repas', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService(), photos: [_diner1, _diner2]);
    await _choisir(tester);
    expect(find.byType(TablCarteRepas), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Photo 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En faire un repas à part'));
    await tester.pumpAndSettle();

    expect(find.byType(TablCarteRepas), findsNWidgets(2));
  });

  testWidgets('aucune photo exploitable : rien n\'est ajouté', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService(), photos: [_sansRien]);
    await _choisir(tester);

    expect(find.text('Aucun repas retrouvé'), findsOneWidget);
    expect(find.text('Choisir d\'autres photos'), findsOneWidget);
  });

  testWidgets('quitter en pleine revue : on prévient, rien n\'est ajouté', (
    tester,
  ) async {
    final retours = await _ouvrir(
      tester,
      _FauxSouvenirService(),
      photos: [_diner1],
    );
    await _choisir(tester);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Quitter l\'importation ?'), findsOneWidget);
    await tester.tap(find.text('Quitter'));
    await tester.pumpAndSettle();

    expect(retours, [0]);
  });
}
