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
  }) async => [_comoEnCasa];
}

const _comoEnCasa = LieuRestaurant(
  fsqPlaceId: 'fsq-como',
  nom: 'Como en Casa',
  ville: 'Liège',
  adresse: 'Rue Hors-Château 76',
  latitude: 50.6471,
  longitude: 5.5802,
);

/// Deux photos de 1 × 1 pixel, différentes pour qu'on les distingue.
final _photoA = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);
final _photoB = Uint8List.fromList([..._photoA]);

/// Ouvre le menu « Comment retrouver vos souvenirs ? » par-dessus un
/// écran témoin, qui note ce que le menu renvoie en se fermant.
Future<List<bool?>> _ouvrirMenu(
  WidgetTester tester,
  _FauxSouvenirService service,
) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final retours = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              retours.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EcranChoixSouvenir(
                      souvenirService: service,
                      abonnementService: _FauxAbonnementService(),
                      rechercheLieuService: _FausseRechercheLieu(),
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

/// Ouvre directement le formulaire, avec un sélecteur de photos factice.
Future<List<bool?>> _ouvrirFormulaire(
  WidgetTester tester,
  _FauxSouvenirService service, {
  List<Uint8List> photos = const [],
}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final retours = <bool?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: TablTheme.sombre(),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              retours.add(
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => EcranAjouterSouvenir(
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

Future<void> _choisirComoEnCasa(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Como');
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Como en Casa'));
  await tester.pumpAndSettle();
}

/// Ouvre les roues du « Quand ? » et valide ce qu'elles proposent : le
/// mois en cours.
Future<void> _validerLaDateProposee(WidgetTester tester) async {
  await tester.tap(find.text('Mois'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Valider').last);
  await tester.pumpAndSettle();
}

TablBouton _boutonAjouter(WidgetTester tester) => tester.widget<TablBouton>(
  find.widgetWithText(TablBouton, 'Ajouter à mon profil'),
);

void main() {
  testWidgets(
    'le menu : un souvenir à la main, l\'import intelligent bientôt',
    (tester) async {
      final service = _FauxSouvenirService();
      final retours = await _ouvrirMenu(tester, service);

      expect(find.text('Comment retrouver vos souvenirs ?'), findsOneWidget);
      expect(
        find.text('Ajouter plusieurs de manière intelligente'),
        findsOneWidget,
      );
      expect(find.text('Bientôt'), findsOneWidget);

      await tester.tap(find.text('Ajouter un souvenir'));
      await tester.pumpAndSettle();
      await _choisirComoEnCasa(tester);
      await _validerLaDateProposee(tester);
      await tester.tap(find.text('Ajouter à mon profil'));
      await tester.pumpAndSettle();

      // Le formulaire et le menu se referment ensemble, sur « ajouté ».
      expect(service.ajoutes, hasLength(1));
      expect(retours, [true]);
      expect(find.text('Comment retrouver vos souvenirs ?'), findsNothing);
    },
  );

  testWidgets('le restaurant et la date suffisent', (tester) async {
    final service = _FauxSouvenirService();
    await _ouvrirFormulaire(tester, service);

    expect(_boutonAjouter(tester).onPresse, isNull);
    await _choisirComoEnCasa(tester);
    expect(_boutonAjouter(tester).onPresse, isNull);
    await _validerLaDateProposee(tester);
    expect(_boutonAjouter(tester).onPresse, isNotNull);

    await tester.tap(find.text('Ajouter à mon profil'));
    await tester.pumpAndSettle();

    final ajoute = service.ajoutes.single;
    final maintenant = DateTime.now();
    expect(ajoute.lieu.nom, 'Como en Casa');
    expect(ajoute.date.annee, maintenant.year);
    expect(ajoute.date.mois, maintenant.month);
    expect(ajoute.date.jour, isNull);
    expect(ajoute.photos, isEmpty);
    expect(ajoute.emotion, isNull);
    expect(ajoute.legende, isNull);
    expect(ajoute.moment, isNull);
  });

  testWidgets('ressenti, mots et moment s\'ajoutent si on veut', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirFormulaire(tester, service);
    await _choisirComoEnCasa(tester);
    await _validerLaDateProposee(tester);

    await tester.tap(find.text('+ Ressenti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😍'));
    await tester.tap(find.text('+ Mots'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'La burrata');
    await tester.tap(find.text('+ Moment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dîner'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter à mon profil'));
    await tester.pumpAndSettle();

    final ajoute = service.ajoutes.single;
    expect(ajoute.emotion, Emotion.coupDeCoeur);
    expect(ajoute.legende, 'La burrata');
    expect(ajoute.moment, 'soir');
  });

  testWidgets('photos : la touchée devient la principale, envoyée en tête', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirFormulaire(tester, service, photos: [_photoA, _photoB]);
    await _choisirComoEnCasa(tester);
    await _validerLaDateProposee(tester);

    await tester.tap(find.text('+ Photos'));
    await tester.pumpAndSettle();
    expect(find.text('2 photos sur 10'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('En faire la photo principale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter à mon profil'));
    await tester.pumpAndSettle();

    final photos = service.ajoutes.single.photos;
    expect(photos, hasLength(2));
    expect(identical(photos.first, _photoB), isTrue);
  });

  testWidgets('restaurant introuvable : nom et ville à la main', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirFormulaire(tester, service);

    await tester.enterText(find.byType(TextField).first, 'Chez Lulu');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je ne trouve pas mon restaurant'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'Namur');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    await _validerLaDateProposee(tester);
    await tester.tap(find.text('Ajouter à mon profil'));
    await tester.pumpAndSettle();

    final lieu = service.ajoutes.single.lieu;
    expect(lieu.nom, 'Chez Lulu');
    expect(lieu.ville, 'Namur');
    // Plus au restaurant : pas la position du téléphone.
    expect(lieu.latitude, isNull);
  });
}
