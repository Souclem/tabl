import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/ecrans/ecran_finalisation.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

final _octets = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  final List<Map<String, Object?>> appelsPublier = [];
  final List<({String id, MomentModifiable moment})> appelsModifier = [];
  MomentModifiable? momentAModifier;

  @override
  Future<List<String>> publier({
    required LieuRestaurant lieu,
    required List<Uint8List> photos,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    Map<String, int> notes = const {},
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> empreintes = const [],
  }) async {
    appelsPublier.add({
      'lieu': lieu,
      'photos': photos,
      'emotion': emotion,
      'legende': legende,
      'amisTaguesIds': amisTaguesIds,
      'impressions': impressions,
      'notes': notes,
      'audience': audience,
    });
    return const [];
  }

  @override
  Future<MomentModifiable> momentModifiable(String souvenirId) async =>
      momentAModifier!;

  @override
  Future<List<String>> modifier(
    String souvenirId,
    MomentModifiable moment,
  ) async {
    appelsModifier.add((id: souvenirId, moment: moment));
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FauxAbonnementService implements AbonnementService {
  _FauxAbonnementService({this.suivis = const []});

  /// Ceux que je suis : chez qui l'on peut avoir mangé.
  final List<ProfilPublic> suivis;

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async =>
      (abonnes: const <ProfilPublic>[], abonnements: suivis);

  @override
  Future<bool> monProfilEstPrive() async => false;

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<List<ProfilPublic>> mesRelations() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Des brouillons en mémoire : pas de fichier, mais les mêmes appels.
class _FauxBrouillons implements BrouillonsLocaux {
  _FauxBrouillons(this.brouillon);

  Brouillon brouillon;
  final List<String> supprimes = [];

  @override
  ImageProvider imagePhoto(String brouillonId, String photoId) =>
      MemoryImage(_octets);

  @override
  Future<Uint8List> octetsPhoto(String brouillonId, String photoId) async =>
      _octets;

  @override
  Future<Brouillon?> charger(String id) async => brouillon;

  @override
  Future<Brouillon?> mettreAJour(
    String id,
    Brouillon Function(Brouillon actuel) transformation,
  ) async => brouillon = transformation(brouillon);

  @override
  Future<void> supprimerBrouillon(String id) async => supprimes.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// La file d'envoi, simulée : la publication réussit aussitôt et garde le
/// brouillon tel que la cloche l'aurait lu.
class _FauxEnvois implements EnvoiPublications {
  _FauxEnvois(this._brouillons);

  final _FauxBrouillons _brouillons;
  final List<Brouillon> envoyes = [];
  ResultatEnvoi resultat = const ResultatEnvoi(StatutEnvoi.publie);

  /// Quand il est posé, l'envoi attend : le test le termine à la main.
  Completer<ResultatEnvoi>? attente;

  @override
  BrouillonsLocaux get brouillons => _brouillons;

  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) async {
    envoyes.add(_brouillons.brouillon);
    return attente?.future ?? resultat;
  }

  @override
  Future<bool> garderEnBrouillon(String brouillonId) async {
    if (attente case final a? when !a.isCompleted) {
      a.complete(const ResultatEnvoi(StatutEnvoi.annule));
    }
    return true;
  }

  @override
  Future<bool> mettreEnAttente(String brouillonId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _PositionFixe implements PositionService {
  const _PositionFixe(this.position);

  final Coordonnees position;

  @override
  Future<Coordonnees?> positionActuelle() async => position;
}

const _comptoir = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
  latitude: 50.6327,
  longitude: 5.5799,
);

Brouillon _brouillon({
  bool photo = true,
  LieuRestaurant? lieu,
  Emotion? emotion,
  Map<String, int> etoiles = const {},
}) => Brouillon(
  id: 'b1',
  creeLe: DateTime(2026, 8, 20, 12, 30),
  modifieLe: DateTime(2026, 8, 20, 12, 30),
  priseLe: DateTime(2026, 8, 20, 12, 30),
  photos: [
    if (photo) PhotoBrouillon(id: 'p1', priseLe: DateTime(2026, 8, 20, 12, 30)),
  ],
  lieu: lieu,
  emotion: emotion,
  etoiles: etoiles,
);

final _publie = SouvenirFeed(
  id: 'm1',
  photoUrl: 'https://exemple.com/1.jpg',
  legende: 'Onze petites assiettes.',
  restaurantNom: 'Le Comptoir',
  ville: 'Liège',
  moment: 'soir',
  dateVisite: DateTime(2026, 8, 19),
  auteurPseudo: 'moi',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
  estAMoi: true,
);

/// Ce que l'écran a rendu en se fermant, et la file d'envoi qu'il a vue.
class _Ouverture {
  _Ouverture(this.service, this.envois);

  final _FauxSouvenirService service;
  final _FauxEnvois? envois;
  Object? rendu;
  bool ferme = false;
}

/// Pousse l'écran sur une vraie pile : `Navigator.pop` a un écran dessous.
Future<_Ouverture> _ouvrir(
  WidgetTester tester, {
  _FauxBrouillons? brouillons,
  SouvenirFeed? aModifier,
  MomentModifiable? moment,
  VoidCallback? reprendrePhotos,
  List<ProfilPublic> suivis = const [],
  PositionService? positionService,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final service = _FauxSouvenirService()..momentAModifier = moment;
  final envois = aModifier == null && brouillons != null
      ? _FauxEnvois(brouillons)
      : null;
  final ouverture = _Ouverture(service, envois);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            ouverture.rendu = await Navigator.of(context).push<Object>(
              MaterialPageRoute<Object>(
                builder: (_) => EcranFinalisation(
                  souvenirService: service,
                  abonnementService: _FauxAbonnementService(suivis: suivis),
                  positionService: positionService,
                  brouillons: aModifier == null ? brouillons : null,
                  brouillon: aModifier == null ? brouillons?.brouillon : null,
                  envois: envois,
                  aModifier: aModifier,
                  reprendrePhotos: reprendrePhotos,
                  maintenant: () => DateTime(2026, 8, 20, 14),
                ),
              ),
            );
            ouverture.ferme = true;
          },
          child: const Text('ouvrir'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('ouvrir'));
  await tester.pumpAndSettle();
  return ouverture;
}

/// La cloche tourne sur un ticker : on avance image par image plutôt que
/// d'attendre un calme qui ne vient pas.
Future<void> _laisserPublier(WidgetTester tester) async {
  for (var t = 0; t < 2500; t += 50) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

TablBoutonPrincipalFinalisation _principal(WidgetTester tester) =>
    tester.widget<TablBoutonPrincipalFinalisation>(
      find.byType(TablBoutonPrincipalFinalisation),
    );

void main() {
  testWidgets('affiche le lieu, la date et la légende dans l\'en-tête', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      brouillons: _FauxBrouillons(_brouillon(lieu: _comptoir)),
    );

    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(find.text('Aujourd’hui · déjeuner · 12 h 30'), findsOneWidget);
    expect(find.text('Plus tard'), findsOneWidget);
  });

  testWidgets('est toujours sombre', (tester) async {
    await _ouvrir(
      tester,
      brouillons: _FauxBrouillons(_brouillon(lieu: _comptoir)),
    );

    final contexte = tester.element(find.byType(TablSelecteurEmotion));
    expect(Theme.of(contexte).brightness, Brightness.dark);
  });

  group('bouton principal', () {
    testWidgets('l\'appareil photo, en haut, ramène à la caméra', (
      tester,
    ) async {
      var reprises = 0;
      await _ouvrir(
        tester,
        brouillons: _FauxBrouillons(_brouillon(lieu: _comptoir)),
        reprendrePhotos: () => reprises++,
      );

      expect(find.text('Choisir les photos'), findsNothing);
      await tester.tap(find.byTooltip('Reprendre des photos'));
      await tester.pump();
      expect(reprises, 1);
    });

    testWidgets('en modification, pas d\'appareil photo', (tester) async {
      await _ouvrir(
        tester,
        aModifier: _publie,
        moment: const MomentModifiable(
          lieu: _comptoir,
          emotion: Emotion.satisfait,
        ),
      );

      expect(find.byTooltip('Reprendre des photos'), findsNothing);
    });

    testWidgets('sans lieu : « Où étiez-vous ? », et « Publier » reste grisé', (
      tester,
    ) async {
      final ouverture = await _ouvrir(
        tester,
        brouillons: _FauxBrouillons(_brouillon()),
      );

      expect(find.text('Où étiez-vous ?'), findsOneWidget);
      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();
      expect(_principal(tester).grise, isTrue);

      // « Publier » ne choisit pas le lieu : il ne fait que publier.
      await tester.tap(find.text('Publier'));
      await tester.pump();
      expect(find.text('Où et quand'), findsNothing);
      expect(ouverture.envois!.envoyes, isEmpty);
      await tester.pump(const Duration(seconds: 2));

      // Le lieu se choisit en haut.
      await tester.tap(find.text('Où étiez-vous ?'));
      await tester.pumpAndSettle();
      expect(find.text('Où et quand'), findsOneWidget);
    });

    testWidgets('avec photos et lieu : « Publier », grisé sans émotion', (
      tester,
    ) async {
      final ouverture = await _ouvrir(
        tester,
        brouillons: _FauxBrouillons(_brouillon(lieu: _comptoir)),
      );

      expect(find.text('Publier'), findsOneWidget);
      expect(_principal(tester).grise, isTrue);

      await tester.tap(find.text('Publier'));
      await tester.pump();

      expect(ouverture.envois!.envoyes, isEmpty);
      // La rangée d'émotions rappelle ce qui manque : tous les noms.
      expect(find.text('Déçu'), findsOneWidget);
      expect(find.text('Exceptionnel'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('choisir une émotion le dégrise et l\'écrit au brouillon', (
      tester,
    ) async {
      final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
      await _ouvrir(tester, brouillons: brouillons);

      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();

      expect(_principal(tester).grise, isFalse);
      expect(brouillons.brouillon.emotion, Emotion.satisfait);
    });
  });

  testWidgets('publie : écrit le brouillon, ouvre la cloche, se ferme dessus', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    final ouverture = await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('🤩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un mot').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Onze assiettes');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(EcranCloche), findsOneWidget);
    await _laisserPublier(tester);

    final envoye = ouverture.envois!.envoyes.single;
    expect(envoye.lieu, _comptoir);
    expect(envoye.emotion, Emotion.inoubliable);
    expect(envoye.legende, 'Onze assiettes');
    expect(envoye.audience.mode, ModeAudience.toutLeMonde);
    expect(ouverture.ferme, isTrue);
    expect((ouverture.rendu! as ResultatCloche).issue, IssueCloche.publie);
    expect(find.byType(EcranFinalisation), findsNothing);
    expect(find.byType(EcranCloche), findsNothing);
  });

  testWidgets('un lieu seulement proposé est écrit avant la cloche', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    final ouverture = await _ouvrir(tester, brouillons: brouillons);
    // Un brouillon relu sans lieu : seul l'écran le connaît.
    brouillons.brouillon = brouillons.brouillon.copieAvec(lieu: () => null);

    await tester.tap(find.text('🙂'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await _laisserPublier(tester);

    expect(ouverture.envois!.envoyes.single.lieu, _comptoir);
  });

  testWidgets('« Où et quand » : le repas choisi est écrit au brouillon', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('Le Comptoir'));
    await tester.pumpAndSettle();
    expect(find.text('Où et quand'), findsOneWidget);
    await tester.tap(find.text('Dîner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(brouillons.brouillon.priseLe, DateTime(2026, 8, 20, 20));
    expect(brouillons.brouillon.lieu, _comptoir);
    expect(find.textContaining('dîner'), findsOneWidget);
  });

  group('hors restaurant', () {
    const emma = ProfilPublic(
      id: 'emma',
      pseudo: 'emma',
      statut: StatutAbonnement.abonne,
    );

    Future<void> versLaMaison(WidgetTester tester) async {
      await tester.tap(find.text('Le Comptoir'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Pas au restaurant'));
      await tester.pumpAndSettle();
    }

    testWidgets('« Chez moi » : « Chez vous » en haut, jamais de position', (
      tester,
    ) async {
      final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
      await _ouvrir(tester, brouillons: brouillons);

      await versLaMaison(tester);
      await tester.tap(find.text('Chez moi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Chez vous'), findsOneWidget);
      final lieu = brouillons.brouillon.lieu!;
      expect(lieu.genre, GenreLieu.domicile);
      expect(lieu.latitude, isNull);
      expect(lieu.longitude, isNull);
    });

    testWidgets(
      'chez une personne suivie : cochée d\'office dans « Avec qui »',
      (tester) async {
        final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
        await _ouvrir(tester, brouillons: brouillons, suivis: [emma]);

        await versLaMaison(tester);
        await tester.tap(find.bySemanticsLabel('Chez emma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Chez emma'), findsOneWidget);
        expect(brouillons.brouillon.lieu!.hoteId, 'emma');
        expect(brouillons.brouillon.avecQuiIds, {'emma'});

        // Plus chez elle : elle n'est plus cochée d'office.
        await tester.tap(find.text('Chez emma'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chez moi'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        expect(brouillons.brouillon.avecQuiIds, isEmpty);
      },
    );
  });

  testWidgets(
    'un restaurant ajouté à la main n\'a jamais la position du téléphone',
    (tester) async {
      final brouillons = _FauxBrouillons(_brouillon());
      final ouverture = await _ouvrir(
        tester,
        brouillons: brouillons,
        // Là où l'on est (peut-être chez soi) : pour trier, jamais gardé.
        positionService: _PositionFixe((latitude: 50.64, longitude: 5.58)),
      );

      await tester.tap(find.text('Où étiez-vous ?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pas dans Tabl ?'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nom du restaurant'),
        'Le Truck',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Ville'), 'Gand');
      await tester.tap(find.text('Ajouter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publier'));
      await _laisserPublier(tester);

      final lieu = ouverture.envois!.envoyes.single.lieu!;
      expect(lieu.nom, 'Le Truck');
      expect(lieu.latitude, isNull);
      expect(lieu.longitude, isNull);
    },
  );

  group('Ajouter un mot', () {
    testWidgets('s\'écrit au brouillon et s\'affiche entre « »', (
      tester,
    ) async {
      final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
      await _ouvrir(tester, brouillons: brouillons);

      await tester.tap(find.text('Ajouter un mot').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Onze assiettes');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(brouillons.brouillon.legende, 'Onze assiettes');
      expect(find.text('« Onze assiettes »'), findsOneWidget);
    });

    testWidgets('compte les caractères dès 250 et refuse au-delà de 300', (
      tester,
    ) async {
      final brouillons = _FauxBrouillons(
        _brouillon(lieu: _comptoir, emotion: Emotion.satisfait),
      );
      final ouverture = await _ouvrir(tester, brouillons: brouillons);

      await tester.tap(find.text('Ajouter un mot').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'a' * 249);
      await tester.pump();
      expect(find.textContaining(' / 300'), findsNothing);

      await tester.enterText(find.byType(TextField), 'a' * 270);
      await tester.pump();
      expect(find.text('270 / 300'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'a' * 301);
      await tester.pump();
      expect(find.text('301 / 300'), findsOneWidget);
      expect(find.text('300 caractères maximum.'), findsWidgets);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();
      expect(ouverture.envois!.envoyes, isEmpty);
    });
  });

  testWidgets('« Ce qui ressort » : un plat écrit puis noté, cinq au plus', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('Ce qui ressort').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Risotto');
    await tester.pump();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Risotto'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('etoile-plat:Risotto-5')));
    await tester.pump();

    // Un deuxième, écrit sans toucher « Ajouter » : gardé à la fermeture.
    await tester.enterText(find.byType(TextField), 'Tiramisu');
    await tester.pump();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(brouillons.brouillon.etoiles, {
      'plat:Risotto': 5,
      'plat:Tiramisu': 0,
    });

    // Trois de plus : le champ laisse place à la limite.
    await tester.tap(find.text('Ce qui ressort').first);
    await tester.pumpAndSettle();
    for (final nom in ['Pain', 'Vin', 'Café']) {
      await tester.enterText(find.byType(TextField), nom);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
    }
    expect(find.text(libelleLimitePlats), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    '« Ce qui ressort » : étoiles facultatives, écrites au brouillon',
    (tester) async {
      final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
      await _ouvrir(tester, brouillons: brouillons);

      await tester.tap(find.text('Ce qui ressort').first);
      await tester.pumpAndSettle();
      expect(find.text('La cuisine'), findsOneWidget);
      expect(find.text('Qualité-prix'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('etoile-cuisine-4')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('etoile-service-2')));
      await tester.pump();
      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();

      expect(brouillons.brouillon.etoiles, {'cuisine': 4, 'service': 2});
    },
  );

  testWidgets('publie avec les étoiles du brouillon, vides sinon', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(
      _brouillon(
        lieu: _comptoir,
        emotion: Emotion.inoubliable,
        etoiles: {'cuisine': 4, 'service': 2},
      ),
    );
    final ouverture = await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('Publier'));
    await _laisserPublier(tester);

    expect(ouverture.envois!.envoyes.single.etoiles, {
      'cuisine': 4,
      'service': 2,
    });
  });

  testWidgets('publie sans étoiles : notes vides', (tester) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    final ouverture = await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('🤩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await _laisserPublier(tester);

    expect(ouverture.envois!.envoyes.single.etoiles, isEmpty);
  });

  group('modification d\'un moment publié', () {
    const moment = MomentModifiable(
      lieu: _comptoir,
      emotion: Emotion.satisfait,
      legende: 'Onze petites assiettes.',
    );

    testWidgets('« Enregistrer », sans « Ce qui ressort » ni « Plus tard »', (
      tester,
    ) async {
      await _ouvrir(tester, aModifier: _publie, moment: moment);

      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Hier · dîner'), findsOneWidget);
      expect(find.text('Ce qui ressort'), findsNothing);
      expect(find.text('Plus tard'), findsNothing);
      expect(_principal(tester).grise, isFalse);
    });

    testWidgets('enregistre les changements sans toucher aux photos', (
      tester,
    ) async {
      final ouverture = await _ouvrir(
        tester,
        aModifier: _publie,
        moment: moment,
      );

      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(ouverture.service.appelsModifier, hasLength(1));
      expect(ouverture.service.appelsModifier.single.id, 'm1');
      expect(
        ouverture.service.appelsModifier.single.moment.emotion,
        Emotion.inoubliable,
      );
      expect(ouverture.service.appelsPublier, isEmpty);
      expect(find.byType(EcranFinalisation), findsNothing);
    });

    testWidgets('renvoie les étoiles du moment telles quelles', (tester) async {
      const notees = MomentModifiable(
        lieu: _comptoir,
        emotion: Emotion.satisfait,
        notes: {'cuisine': 5},
      );
      final ouverture = await _ouvrir(
        tester,
        aModifier: _publie,
        moment: notees,
      );

      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      expect(ouverture.service.appelsModifier.single.moment.notes, {
        'cuisine': 5,
      });
    });

    testWidgets('fermer après un changement demande confirmation', (
      tester,
    ) async {
      await _ouvrir(tester, aModifier: _publie, moment: moment);

      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();
      expect(find.byType(EcranFinalisation), findsNothing);
    });
  });

  testWidgets('« Plus tard » ferme sans rien perdre', (tester) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('🙂'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranFinalisation), findsNothing);
    expect(brouillons.supprimes, isEmpty);
    expect(brouillons.brouillon.emotion, Emotion.satisfait);
  });
}
