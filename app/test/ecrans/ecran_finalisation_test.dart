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
  Future<void> Function(BuildContext context)? ouvrirPhotos,
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
                  abonnementService: _FauxAbonnementService(),
                  brouillons: aModifier == null ? brouillons : null,
                  brouillon: aModifier == null ? brouillons?.brouillon : null,
                  envois: envois,
                  aModifier: aModifier,
                  ouvrirPhotos: ouvrirPhotos,
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
    testWidgets('sans photo : « Choisir les photos » ouvre les photos', (
      tester,
    ) async {
      var ouvertes = 0;
      await _ouvrir(
        tester,
        brouillons: _FauxBrouillons(_brouillon(photo: false)),
        ouvrirPhotos: (_) async => ouvertes++,
      );

      expect(find.text('Choisir les photos'), findsOneWidget);
      expect(_principal(tester).grise, isFalse);

      await tester.tap(find.text('Choisir les photos'));
      await tester.pumpAndSettle();
      expect(ouvertes, 1);
    });

    testWidgets('sans lieu : « Où étiez-vous ? »', (tester) async {
      await _ouvrir(tester, brouillons: _FauxBrouillons(_brouillon()));

      expect(
        find.descendant(
          of: find.byType(TablBoutonPrincipalFinalisation),
          matching: find.text('Où étiez-vous ?'),
        ),
        findsOneWidget,
      );
      expect(_principal(tester).grise, isFalse);
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
    await tester.tap(find.text('Valider'));
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

  testWidgets('« Modifier » dans la cloche ramène à la finalisation', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    final ouverture = await _ouvrir(tester, brouillons: brouillons);
    ouverture.envois!.attente = Completer<ResultatEnvoi>();

    await tester.tap(find.text('🤩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Modifier'));
    await _laisserPublier(tester);

    expect(find.byType(EcranCloche), findsNothing);
    expect(find.byType(EcranFinalisation), findsOneWidget);
    expect(ouverture.ferme, isFalse);
  });

  testWidgets('« Annuler » dans la cloche rend le résultat à l\'appelant', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    final ouverture = await _ouvrir(tester, brouillons: brouillons);
    ouverture.envois!.attente = Completer<ResultatEnvoi>();

    await tester.tap(find.text('🤩'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Publier'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Annuler'));
    await _laisserPublier(tester);

    expect(ouverture.ferme, isTrue);
    expect((ouverture.rendu! as ResultatCloche).issue, IssueCloche.annule);
    expect(brouillons.supprimes, isEmpty);
  });

  testWidgets('les photos retirées de la publication ne comptent pas', (
    tester,
  ) async {
    var ouvertes = 0;
    await _ouvrir(
      tester,
      brouillons: _FauxBrouillons(
        _brouillon(lieu: _comptoir).copieAvec(horsPublicationIds: {'p1'}),
      ),
      ouvrirPhotos: (_) async => ouvertes++,
    );

    expect(find.text('Choisir les photos'), findsOneWidget);
    await tester.tap(find.text('Choisir les photos'));
    await tester.pumpAndSettle();
    expect(ouvertes, 1);
  });

  testWidgets('« Où et quand » : le repas choisi est écrit au brouillon', (
    tester,
  ) async {
    final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
    await _ouvrir(tester, brouillons: brouillons);

    await tester.tap(find.text('Le Comptoir'));
    await tester.pumpAndSettle();
    expect(find.text('Où et quand'), findsOneWidget);
    await tester.tap(find.text('Soir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();

    expect(brouillons.brouillon.priseLe, DateTime(2026, 8, 20, 20));
    expect(brouillons.brouillon.lieu, _comptoir);
    expect(find.textContaining('dîner'), findsOneWidget);
  });

  group('Ajouter un mot', () {
    testWidgets('s\'écrit au brouillon et s\'affiche entre « »', (
      tester,
    ) async {
      final brouillons = _FauxBrouillons(_brouillon(lieu: _comptoir));
      await _ouvrir(tester, brouillons: brouillons);

      await tester.tap(find.text('Ajouter un mot').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Onze assiettes');
      await tester.tap(find.text('Valider'));
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

      await tester.tap(find.text('Valider'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publier'));
      await tester.pumpAndSettle();
      expect(ouverture.envois!.envoyes, isEmpty);
    });
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
