import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_ajouter_souvenir.dart';
import 'package:app/ecrans/ecran_choix_souvenir.dart';

/// Seul l'ajout d'un souvenir est exercé ici.
class _FauxSouvenirService implements SouvenirService {
  final List<NouveauSouvenir> ajoutes = [];

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
  Future<List<SuggestionAmi>> suggestions() async => const [];

  @override
  Future<void> ecarterSuggestion(String profilId) async {}

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
  _FausseRechercheLieu({this.proches = const [], this.mesLieux = const []});

  final List<LieuRestaurant> proches;
  final List<LieuRestaurant> mesLieux;
  final List<({double latitude, double longitude})> pointsDemandes = [];

  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async => [_leComptoir];

  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async {
    pointsDemandes.add((latitude: latitude, longitude: longitude));
    return proches;
  }

  @override
  Future<List<LieuRestaurant>> mesLieuxPersonnels() async => mesLieux;
}

const _comoEnCasa = LieuRestaurant(
  fsqPlaceId: 'fsq-como',
  nom: 'Como en Casa',
  ville: 'Liège',
  latitude: 50.6471,
  longitude: 5.5802,
  distanceM: 40,
);

const _amarante = LieuRestaurant(
  fsqPlaceId: 'fsq-amarante',
  nom: 'Amarante',
  ville: 'Liège',
  distanceM: 120,
);

const _leComptoir = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
);

/// Deux images de 1 × 1 pixel, distinctes pour qu'on les reconnaisse.
final _photoA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _photoB = Uint8List.fromList([..._photoA]);

/// Une photo prise chez Como en Casa, le 3 novembre 2023 à 20 h 41.
PhotoChoisie _photoDuDiner(Uint8List octets) => (
  octets: octets,
  metadonnees: MetadonneesPhoto(
    prisLe: DateTime(2023, 11, 3, 20, 41),
    latitude: 50.64735,
    longitude: 5.58045,
  ),
);

void _grandEcran(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Ouvre [ecran] par-dessus un écran témoin, qui note ce qu'il renvoie
/// en se fermant.
Future<List<Object?>> _ouvrir(WidgetTester tester, Widget ecran) async {
  _grandEcran(tester);
  final retours = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              retours.add(
                await Navigator.of(
                  context,
                ).push<Object?>(MaterialPageRoute(builder: (_) => ecran)),
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

Future<List<Object?>> _ouvrirMenu(
  WidgetTester tester,
  _FauxSouvenirService service, {
  List<Uint8List> photos = const [],
}) => _ouvrir(
  tester,
  EcranChoixSouvenir(
    souvenirService: service,
    abonnementService: _FauxAbonnementService(),
    rechercheLieuService: _FausseRechercheLieu(),
    choisirPhotos: (restant) async => photos,
  ),
);

Future<List<Object?>> _ouvrirEditeur(
  WidgetTester tester,
  _FauxSouvenirService service, {
  List<PhotoChoisie> photos = const [],
  _FausseRechercheLieu? recherche,
}) => _ouvrir(
  tester,
  EcranAjouterSouvenir(
    souvenirService: service,
    abonnementService: _FauxAbonnementService(),
    photos: photos,
    rechercheLieuService: recherche ?? _FausseRechercheLieu(),
  ),
);

TablBouton _boutonAjouter(WidgetTester tester) => tester.widget<TablBouton>(
  find.widgetWithText(TablBouton, 'Ajouter à mon profil'),
);

Future<void> _ajouter(WidgetTester tester) async {
  await tester.tap(find.text('Ajouter à mon profil'));
  await tester.pumpAndSettle();
}

void main() {
  group('le menu', () {
    testWidgets('les photos d\'abord, ou plusieurs repas d\'un coup', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      await _ouvrirMenu(tester, service, photos: [_photoA]);

      expect(find.text('Comment retrouver vos souvenirs ?'), findsOneWidget);
      expect(
        find.text('Ajouter plusieurs de manière intelligente'),
        findsOneWidget,
      );

      await tester.tap(find.text('Choisir des photos'));
      await tester.pumpAndSettle();

      // La photo choisie, en grand ; sans date ni lieu dedans, rien
      // n'est deviné.
      expect(find.byType(TablApercuPhotos), findsOneWidget);
      expect(find.text('Quel restaurant ?'), findsOneWidget);
      expect(find.text('Quand était-ce ?'), findsOneWidget);
      expect(_boutonAjouter(tester).onPresse, isNull);
    });

    testWidgets(
      '« Ajouter plusieurs de manière intelligente » ouvre l\'import',
      (tester) async {
        await _ouvrirMenu(tester, _FauxSouvenirService());

        await tester.tap(
          find.text('Ajouter plusieurs de manière intelligente'),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Trois temps, et rien sans votre accord.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('sélecteur fermé sans rien choisir : on reste au menu', (
      tester,
    ) async {
      await _ouvrirMenu(tester, _FauxSouvenirService());

      await tester.tap(find.text('Choisir des photos'));
      await tester.pumpAndSettle();

      expect(find.text('Comment retrouver vos souvenirs ?'), findsOneWidget);
    });

    testWidgets('souvenir ajouté : l\'éditeur et le menu se referment', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      final retours = await _ouvrirMenu(tester, service, photos: [_photoA]);

      // Pas de souvenir sans photo : plus d'ajout « à la main ».
      expect(find.text('Pas de photo ? Ajouter à la main'), findsNothing);
      await tester.tap(find.text('Choisir des photos'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quel restaurant ?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'Comptoir',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Le Comptoir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quand était-ce ?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await _ajouter(tester);

      final ajoute = service.ajoutes.single;
      final maintenant = DateTime.now();
      expect(ajoute.lieu.nom, 'Le Comptoir');
      expect(ajoute.date.annee, maintenant.year);
      expect(ajoute.date.mois, maintenant.month);
      expect(ajoute.date.jour, isNull);
      expect(ajoute.photos, [_photoA]);
      expect(retours, [1]);
      expect(find.text('Comment retrouver vos souvenirs ?'), findsNothing);
    });
  });

  group('d\'après les photos', () {
    testWidgets('le restaurant le plus proche, le jour et le moment', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      final recherche = _FausseRechercheLieu(proches: [_comoEnCasa, _amarante]);
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: recherche,
      );

      expect(recherche.pointsDemandes.single.latitude, 50.64735);
      expect(find.text('Como en Casa'), findsOneWidget);
      expect(find.text('Liège · à 40 m de la photo'), findsOneWidget);
      expect(find.text('3 novembre 2023 · Dîner'), findsOneWidget);
      expect(find.text('D\'après vos photos · 20 h 41'), findsOneWidget);

      await _ajouter(tester);

      final ajoute = service.ajoutes.single;
      expect(ajoute.lieu.nom, 'Como en Casa');
      expect(ajoute.date.libelle, '3 novembre 2023');
      expect(ajoute.moment, 'soir');
      expect(ajoute.photos, [_photoA]);
    });

    testWidgets('deux endroits : le resto de la première photo, l\'autre aussi '
        'dans la liste', (tester) async {
      final service = _FauxSouvenirService();
      final recherche = _FausseRechercheLieu(proches: [_comoEnCasa]);
      await _ouvrirEditeur(
        tester,
        service,
        photos: [
          (
            octets: _photoA,
            metadonnees: MetadonneesPhoto(
              prisLe: DateTime(2023, 11, 3, 22),
              latitude: 50.70,
              longitude: 5.60,
            ),
          ),
          _photoDuDiner(_photoB),
        ],
        recherche: recherche,
      );

      // La plus ancienne (20 h 41, chez Como en Casa) d'abord.
      expect(recherche.pointsDemandes.map((p) => p.latitude), [
        50.64735,
        50.70,
      ]);
      expect(find.text('D\'après vos photos · 20 h 41'), findsOneWidget);

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      expect(find.text('PRÈS DE VOS PHOTOS'), findsOneWidget);
      expect(find.text('PRÈS D\'UNE AUTRE PHOTO'), findsOneWidget);
      expect(find.text('Liste'), findsOneWidget);
      expect(find.text('Carte'), findsOneWidget);
    });

    testWidgets('le restaurant proposé se change : les proches d\'abord', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: _FausseRechercheLieu(proches: [_comoEnCasa, _amarante]),
      );

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      expect(find.text('PRÈS DE VOS PHOTOS'), findsOneWidget);
      await tester.tap(find.text('Amarante'));
      await tester.pumpAndSettle();

      expect(find.text('Liège · à 120 m de la photo'), findsOneWidget);
      await _ajouter(tester);
      expect(service.ajoutes.single.lieu.nom, 'Amarante');
    });

    testWidgets('la date proposée se change', (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: _FausseRechercheLieu(proches: [_comoEnCasa]),
      );

      await tester.tap(find.text('3 novembre 2023 · Dîner'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Déjeuner'));
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(find.text('3 novembre 2023 · Déjeuner'), findsOneWidget);
      // Choisie à la main : plus « d'après vos photos ».
      expect(find.text('D\'après vos photos · 20 h 41'), findsNothing);
      await _ajouter(tester);
      expect(service.ajoutes.single.moment, 'midi');
    });

    testWidgets('« Principale » met la photo affichée en tête', (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA), _photoDuDiner(_photoB)],
        recherche: _FausseRechercheLieu(proches: [_comoEnCasa]),
      );

      expect(find.text('Principale'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Photo 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Principale'));
      await tester.pumpAndSettle();
      await _ajouter(tester);

      final photos = service.ajoutes.single.photos;
      expect(identical(photos.first, _photoB), isTrue);
      expect(photos, hasLength(2));
    });

    testWidgets('ressenti et quelques mots, si on veut', (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: _FausseRechercheLieu(proches: [_comoEnCasa]),
      );

      await tester.tap(find.text('😍'));
      await tester.enterText(
        find.descendant(
          of: find.byType(TablChampLegende),
          matching: find.byType(TextField),
        ),
        'La burrata',
      );
      await tester.pumpAndSettle();
      await _ajouter(tester);

      final ajoute = service.ajoutes.single;
      expect(ajoute.emotion, Emotion.coupDeCoeur);
      expect(ajoute.legende, 'La burrata');
    });
  });

  testWidgets('toutes les photos retirées : impossible d\'ajouter', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEditeur(
      tester,
      service,
      photos: [_photoDuDiner(_photoA)],
      recherche: _FausseRechercheLieu(proches: [_comoEnCasa]),
    );
    expect(_boutonAjouter(tester).onPresse, isNotNull);

    await tester.tap(find.text('Retirer'));
    await tester.pumpAndSettle();

    expect(find.text('Ajouter des photos'), findsOneWidget);
    expect(_boutonAjouter(tester).onPresse, isNull);
  });

  group('lieux personnels', () {
    testWidgets('« Créer un lieu personnel » : un nom, jamais d\'adresse', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: _FausseRechercheLieu(proches: [_comoEnCasa]),
      );

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer un lieu personnel'));
      await tester.pumpAndSettle();
      expect(find.text('Liste'), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'Chez mes parents',
      );
      await tester.tap(find.text('Créer ce lieu'));
      await tester.pumpAndSettle();

      expect(find.text('Chez mes parents'), findsOneWidget);
      expect(find.text('Lieu personnel · jamais public'), findsOneWidget);
      await _ajouter(tester);

      final lieu = service.ajoutes.single.lieu;
      expect(lieu.personnel, isTrue);
      expect(lieu.latitude, isNull);
      expect(lieu.ville, isEmpty);
    });

    testWidgets('ses lieux, dans « Mes lieux » et dans la recherche', (
      tester,
    ) async {
      final service = _FauxSouvenirService();
      await _ouvrirEditeur(
        tester,
        service,
        photos: [_photoDuDiner(_photoA)],
        recherche: _FausseRechercheLieu(
          proches: [_comoEnCasa],
          mesLieux: const [
            LieuRestaurant.personnel(
              nom: 'Chez mes parents',
              restaurantId: 'r-parents',
            ),
          ],
        ),
      );

      await tester.tap(find.text('Changer'));
      await tester.pumpAndSettle();
      expect(find.text('MES LIEUX'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(TextField),
        ),
        'parents',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.text('MES LIEUX'), findsOneWidget);
      await tester.tap(find.text('Chez mes parents'));
      await tester.pumpAndSettle();
      await _ajouter(tester);

      expect(service.ajoutes.single.lieu.restaurantId, 'r-parents');
    });
  });

  testWidgets('restaurant introuvable : nom et ville à la main', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEditeur(
      tester,
      service,
      photos: [(octets: _photoA, metadonnees: MetadonneesPhoto.aucune)],
    );

    await tester.tap(find.text('Quel restaurant ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je ne trouve pas mon restaurant'));
    await tester.pumpAndSettle();
    // Les champs de la feuille, pas celui des quelques mots dessous.
    final champs = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(champs.at(0), 'Chez Lulu');
    await tester.enterText(champs.at(1), 'Namur');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(find.text('Chez Lulu'), findsOneWidget);
    await tester.tap(find.text('Quand était-ce ?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await _ajouter(tester);

    final lieu = service.ajoutes.single.lieu;
    expect(lieu.nom, 'Chez Lulu');
    expect(lieu.ville, 'Namur');
    // Plus au restaurant : pas la position du téléphone.
    expect(lieu.latitude, isNull);
  });
}
