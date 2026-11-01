import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_abonnes.dart';
import 'package:app/ecrans/ecran_commentaires.dart';
import 'package:app/ecrans/ecran_creer_instant.dart';
import 'package:app/ecrans/ecran_feed.dart';
import 'package:app/ecrans/ecran_profil_autre.dart';
import 'package:app/ecrans/ecran_viewer_instants.dart';

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<SouvenirFeed?> souvenir(String souvenirId) =>
      throw UnimplementedError();
  @override
  Future<Set<String>> empreintesImportees() => throw UnimplementedError();
  @override
  Future<void> supprimer(String souvenirId) => throw UnimplementedError();
  @override
  Future<List<String>> ajouterSouvenir(NouveauSouvenir souvenir) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> mesMomentsAvec(String profilId) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async =>
      [];

  final List<(String, bool)> appelsEnvie = [];

  @override
  Future<void> basculerEnvie(String restaurantId, {required bool envie}) async {
    appelsEnvie.add((restaurantId, envie));
  }

  _FauxSouvenirService({
    this.souvenirs = const [],
    this.erreur = false,
    this.erreurReaction = false,
  });

  final List<SouvenirFeed> souvenirs;
  final bool erreur;
  final bool erreurReaction;

  final List<(String, bool)> appelsReaction = [];

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async =>
      souvenirs.where((s) => s.estAMoi).toList();
  @override
  Future<List<SouvenirFeed>> feed() async {
    if (erreur) throw Exception('erreur réseau');
    return souvenirs;
  }

  @override
  Future<void> basculerReaction(
    String souvenirId, {
    required bool reagir,
  }) async {
    if (erreurReaction) throw Exception('erreur réseau');
    appelsReaction.add((souvenirId, reagir));
  }

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
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> empreintes = const [],
  }) => throw UnimplementedError();

  @override
  Future<String> enregistrerBrouillon({
    required LieuRestaurant lieu,
    required Uint8List photo,
  }) => throw UnimplementedError();

  @override
  Future<({AudienceSouvenir audience, Set<String> amisTaguesIds})>
  audienceActuelle(String souvenirId) => throw UnimplementedError();

  @override
  Future<List<String>> modifierAudience(
    String souvenirId,
    AudienceSouvenir audience,
  ) => throw UnimplementedError();

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) async => [];

  @override
  Future<void> commenter(String souvenirId, String texte) =>
      throw UnimplementedError();

  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
}

/// Faux [AbonnementService] : aucune méthode n'est appelée tant qu'on ne
/// tape pas sur "Trouver des personnes".
class _FauxNotificationService implements NotificationService {
  final List<NotificationTabl> notifications = [];
  int appels = 0;

  @override
  Future<({List<NotificationTabl> notifications, DateTime? vuesLe})>
  mesNotifications() async {
    appels++;
    return (notifications: [...notifications], vuesLe: null);
  }

  @override
  Future<void> marquerVues(DateTime moment) async {}
}

class _FauxAbonnementService implements AbonnementService {
  _FauxAbonnementService({this.abonnements = const []});

  final List<ProfilPublic> abonnements;

  @override
  Future<CompteursProfil> compteurs(String profilId) =>
      throw UnimplementedError();

  @override
  Future<String> definirPhotoProfil(Uint8List photo) =>
      throw UnimplementedError();
  @override
  Future<ProfilVisite> profil(String id) async => ProfilVisite(
    id: id,
    pseudo: 'martin',
    estPrive: true,
    statut: StatutAbonnement.aucun,
  );

  @override
  Future<({List<ProfilPublic> abonnes, List<ProfilPublic> abonnements})>
  abonnesEtAbonnements() async =>
      (abonnes: <ProfilPublic>[], abonnements: abonnements);

  @override
  Future<Set<String>> mesAbonnesIds() async => {};

  @override
  Future<bool> monProfilEstPrive() async => true;

  @override
  Future<void> definirProfilPrive(bool prive) async {}

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

  @override
  Future<List<ProfilPublic>> mesRelations() async => [];
}

SouvenirFeed _souvenirDeTest({
  String id = '1',
  int nombreReactions = 0,
  bool jaiReagi = false,
  int nombreCommentaires = 0,
  List<PersonneQuiAime> premieresReactions = const [],
  bool estAMoi = false,
  String? restaurantId = 'resto-1',
  String auteurPseudo = 'martin',
  String restaurantNom = 'Le Comptoir',
}) {
  return SouvenirFeed(
    id: id,
    photoUrl: null,
    legende: 'Onze petites assiettes.',
    restaurantNom: restaurantNom,
    ville: 'Paris',
    moment: 'soir',
    dateVisite: DateTime(2026, 8, 20),
    auteurPseudo: auteurPseudo,
    nombreReactions: nombreReactions,
    jaiReagi: jaiReagi,
    nombreCommentaires: nombreCommentaires,
    premieresReactions: premieresReactions,
    estAMoi: estAMoi,
    restaurantId: restaurantId,
    auteurId: estAMoi ? 'moi-id' : '$auteurPseudo-id',
  );
}

class _FauxInstantService implements InstantService {
  _FauxInstantService({this.signauxParId = const {}});

  final Map<String, SignalInstants> signauxParId;

  @override
  Future<Map<String, SignalInstants>> signaux(
    List<String> experienceIds,
  ) async {
    return {
      for (final id in experienceIds)
        id: signauxParId[id] ?? SignalInstants.aucun,
    };
  }

  @override
  Future<void> creer({
    required String experienceId,
    required TypeMediaInstant type,
    required Uint8List media,
  }) async {}

  @override
  Future<List<InstantAffichable>> instantsDe(String experienceId) async => [];

  @override
  Future<void> marquerVu(String instantId) async {}

  @override
  Future<void> supprimer(String instantId) async {}
}

/// Le Feed n'a plus de hauteur fixe par post (photo + texte + actions) :
/// la fenêtre de test par défaut (600 de haut) laisse les boutons du bas
/// hors-écran pour `tester.tap`. Une surface plus haute évite ça sans
/// dépendre de `ensureVisible` partout.
void _agrandirSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('taper sur l\'auteur ouvre son profil, pas sur le sien', (
    tester,
  ) async {
    _agrandirSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: [_souvenirDeTest()]),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('martin'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranProfilAutre), findsOneWidget);
    expect(find.text('Ce profil est privé'), findsOneWidget);
  });

  testWidgets('son propre nom n\'est pas touchable', (tester) async {
    _agrandirSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(
            souvenirs: [_souvenirDeTest(estAMoi: true, auteurPseudo: 'moi')],
          ),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('moi'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranProfilAutre), findsNothing);
  });

  testWidgets('feed vide : état vide avec bouton "Trouver des personnes"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Votre feed est encore vide.'), findsOneWidget);
    expect(find.text('Trouver des personnes'), findsOneWidget);
  });

  testWidgets('taper sur "Trouver des personnes" ouvre l\'écran Cercle', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trouver des personnes'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranAbonnes), findsOneWidget);
  });

  testWidgets('bouton d\'ajout en haut du Feed : toucher quelqu\'un ouvre '
      'son profil', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(),
          abonnementService: _FauxAbonnementService(
            abonnements: const [
              ProfilPublic(
                id: 'martin-id',
                pseudo: 'martin',
                statut: StatutAbonnement.abonne,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_add_alt_1_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abonnements · 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('martin'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranProfilAutre), findsOneWidget);
  });

  testWidgets('feed rempli : affiche le contenu de chaque souvenir', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final souvenirs = [
      _souvenirDeTest(
        nombreReactions: 3,
        nombreCommentaires: 2,
        premieresReactions: const [
          PersonneQuiAime(pseudo: 'Louise'),
          PersonneQuiAime(pseudo: 'Arthur'),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(find.text('«\u00A0Onze petites assiettes.\u00A0»'), findsOneWidget);
    expect(find.textContaining('Paris'), findsOneWidget);
    expect(find.textContaining('martin'), findsOneWidget);
    // Pas de chiffre brut affiché pour les commentaires (conforme au
    // prototype) : juste le libellé "Commenter".
    expect(find.byTooltip('Commenter'), findsOneWidget);
    // Jamais un chiffre brut mis en avant pour les réactions : une phrase.
    expect(find.text('Louise, Arthur et 1 autre ont aimé'), findsOneWidget);
    expect(find.text('Votre feed est encore vide.'), findsNothing);
    // Ni l'une ni l'autre n'est suivie : aucune tête à côté.
    expect(find.byType(TablBullesPersonnes), findsNothing);
  });

  testWidgets('les amis qui ont aimé : leur tête à côté de « ont aimé »', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final souvenirs = [
      _souvenirDeTest(
        nombreReactions: 5,
        premieresReactions: const [
          PersonneQuiAime(pseudo: 'Louise', suivie: true),
          PersonneQuiAime(pseudo: 'Arthur', suivie: true),
          PersonneQuiAime(pseudo: 'Inconnu'),
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Louise, Arthur, Inconnu et 2 autres ont aimé'),
      findsOneWidget,
    );
    final bulles = tester.widget<TablBullesPersonnes>(
      find.byType(TablBullesPersonnes),
    );
    expect([for (final b in bulles.bulles) b.pseudo], ['Louise', 'Arthur']);
  });

  testWidgets('erreur de chargement → message générique affiché', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(erreur: true),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets('réagir met à jour le libellé et appelle le service', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final service = _FauxSouvenirService(
      souvenirs: [_souvenirDeTest(nombreReactions: 0, jaiReagi: false)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip("J'aime"), findsOneWidget);
    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byTooltip('Aimé'), findsOneWidget);
    expect(find.text('Vous avez aimé'), findsOneWidget);
    expect(service.appelsReaction, [('1', true)]);
  });

  testWidgets('retirer sa réaction revient à "Personne n\'a encore aimé"', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final service = _FauxSouvenirService(
      souvenirs: [_souvenirDeTest(nombreReactions: 1, jaiReagi: true)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vous avez aimé'), findsOneWidget);
    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text("Personne n'a encore aimé"), findsOneWidget);
    expect(service.appelsReaction, [('1', false)]);
  });

  testWidgets(
    'échec réseau en réagissant : revient à l\'état précédent + message',
    (tester) async {
      _agrandirSurface(tester);
      final service = _FauxSouvenirService(
        souvenirs: [_souvenirDeTest(nombreReactions: 0, jaiReagi: false)],
        erreurReaction: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: service,
            abonnementService: _FauxAbonnementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TablBoutonReaction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text("Personne n'a encore aimé"), findsOneWidget);
      expect(find.text(messageErreurGenerique), findsOneWidget);
    },
  );

  testWidgets('taper sur "Commenter" ouvre EcranCommentaires', (tester) async {
    _agrandirSurface(tester);
    final souvenirs = [_souvenirDeTest()];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Commenter'));
    await tester.pumpAndSettle();

    expect(find.byType(EcranCommentaires), findsOneWidget);
  });

  testWidgets(
    '"Enregistrer" ajoute le restaurant aux envies, pour tous ses posts',
    (tester) async {
      _agrandirSurface(tester);
      final service = _FauxSouvenirService(
        souvenirs: [
          _souvenirDeTest(id: '1'),
          _souvenirDeTest(id: '2', auteurPseudo: 'sarah'),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: service,
            abonnementService: _FauxAbonnementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Enregistrer').first);
      await tester.pumpAndSettle();

      expect(service.appelsEnvie, [('resto-1', true)]);
      // L'envie porte sur le lieu : l'autre post du même restaurant suit.
      await tester.scrollUntilVisible(find.byTooltip('Enregistrée').last, 300);
      expect(find.byTooltip('Enregistrer'), findsNothing);
    },
  );

  testWidgets(
    'sans instantService (règle 52) : aucun signal, aucun CTA Instant',
    (tester) async {
      _agrandirSurface(tester);
      final souvenirs = [_souvenirDeTest(estAMoi: true)];

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
            abonnementService: _FauxAbonnementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TablSignalInstants), findsNothing);
      expect(find.byType(TablBoutonAjouterInstant), findsNothing);
      expect(find.byType(TablRaccourciATableMaintenant), findsNothing);
    },
  );

  testWidgets('signal "3 nouveaux Instants" affiché sur le post', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final souvenirs = [_souvenirDeTest()];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
          instantService: _FauxInstantService(
            signauxParId: {
              '1': const SignalInstants(
                total: 3,
                nonVus: 3,
                fenetreCreationOuverte: false,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 nouveaux Instants'), findsOneWidget);
  });

  testWidgets(
    '"+ Instant" visible sur mon propre post si la fenêtre est ouverte, absent sinon',
    (tester) async {
      _agrandirSurface(tester);
      final souvenirs = [
        _souvenirDeTest(id: '1', estAMoi: true),
        _souvenirDeTest(id: '2', estAMoi: false, auteurPseudo: 'sarah'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
            abonnementService: _FauxAbonnementService(),
            instantService: _FauxInstantService(
              signauxParId: {
                '1': const SignalInstants(
                  total: 0,
                  nonVus: 0,
                  fenetreCreationOuverte: true,
                ),
                '2': const SignalInstants(
                  total: 0,
                  nonVus: 0,
                  fenetreCreationOuverte: true,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Un seul CTA : le mien, jamais celui d'un post qui n'est pas le
      // mien même si sa fenêtre est ouverte (règle 3, owner only).
      expect(find.byType(TablBoutonAjouterInstant), findsOneWidget);
    },
  );

  testWidgets('tap sur "+ Instant" ouvre EcranCreerInstant', (tester) async {
    _agrandirSurface(tester);
    final souvenirs = [_souvenirDeTest(estAMoi: true)];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
          instantService: _FauxInstantService(
            signauxParId: {
              '1': const SignalInstants(
                total: 0,
                nonVus: 0,
                fenetreCreationOuverte: true,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TablBoutonAjouterInstant));
    await tester.pumpAndSettle();

    expect(find.byType(EcranCreerInstant), findsOneWidget);
  });

  testWidgets('tap sur le signal ouvre EcranViewerInstants', (tester) async {
    await mockNetworkImagesFor(() async {
      _agrandirSurface(tester);
      final souvenirs = [_souvenirDeTest()];

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
            abonnementService: _FauxAbonnementService(),
            instantService: _FauxInstantService(
              signauxParId: {
                '1': const SignalInstants(
                  total: 1,
                  nonVus: 1,
                  fenetreCreationOuverte: false,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TablSignalInstants));
      await tester.pumpAndSettle();

      expect(find.byType(EcranViewerInstants), findsOneWidget);
    });
  });

  testWidgets(
    '"À table maintenant" apparaît seulement à partir de 2 expériences actives',
    (tester) async {
      _agrandirSurface(tester);
      final unSeul = [_souvenirDeTest(id: '1')];

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: _FauxSouvenirService(souvenirs: unSeul),
            abonnementService: _FauxAbonnementService(),
            instantService: _FauxInstantService(
              signauxParId: {
                '1': const SignalInstants(
                  total: 1,
                  nonVus: 1,
                  fenetreCreationOuverte: false,
                ),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TablRaccourciATableMaintenant), findsNothing);
    },
  );

  testWidgets('"À table maintenant · 2" apparaît avec 2 expériences actives', (
    tester,
  ) async {
    _agrandirSurface(tester);
    final deux = [
      _souvenirDeTest(id: '1', auteurPseudo: 'martin'),
      _souvenirDeTest(id: '2', auteurPseudo: 'sarah'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: deux),
          abonnementService: _FauxAbonnementService(),
          instantService: _FauxInstantService(
            signauxParId: {
              '1': const SignalInstants(
                total: 1,
                nonVus: 1,
                fenetreCreationOuverte: false,
              ),
              '2': const SignalInstants(
                total: 1,
                nonVus: 0,
                fenetreCreationOuverte: false,
              ),
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('À table maintenant · 2'), findsOneWidget);
  });

  testWidgets('la cloche se revérifie quand on revient dans l\'app', (
    tester,
  ) async {
    final notifications = _FauxNotificationService();
    final pastilles = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).shape == BoxShape.circle &&
          (w.decoration! as BoxDecoration).color == TablTokens.primaire,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(),
          abonnementService: _FauxAbonnementService(),
          notificationService: notifications,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(pastilles, findsNothing);

    // Une demande de suivi arrive pendant que l'app est en arrière-plan.
    notifications.notifications.add(
      NotificationTabl(
        type: TypeNotification.demandeSuivi,
        acteur: (id: 'm', pseudo: 'martin', photoUrl: null),
        creeLe: DateTime.now(),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(pastilles, findsOneWidget);

    // Et chaque minute tant qu'elle reste ouverte.
    final avant = notifications.appels;
    await tester.pump(const Duration(minutes: 1));
    expect(notifications.appels, avant + 1);
  });
}
