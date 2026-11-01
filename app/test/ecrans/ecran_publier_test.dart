import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_publier.dart';

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

  @override
  Future<void> basculerEnvie(
    String restaurantId, {
    required bool envie,
  }) async {}

  _FauxSouvenirService({
    this.erreur = false,
    this.tablesEnEchec = const [],
    this.momentAModifier,
  });

  /// Ce que [momentModifiable] renvoie.
  final MomentModifiable? momentAModifier;
  final List<({String id, MomentModifiable moment})> appelsModifier = [];

  final bool erreur;

  /// Identifiants de Table que [publier] doit signaler en échec
  /// d'association (règle 51) — le souvenir reste publié malgré tout.
  final List<String> tablesEnEchec;

  final List<Map<String, Object?>> appelsPublier = [];
  final List<Map<String, Object?>> appelsBrouillon = [];

  @override
  Future<String> enregistrerBrouillon({
    required LieuRestaurant lieu,
    required Uint8List photo,
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appelsBrouillon.add({
      'nomRestaurant': lieu.nom,
      'ville': lieu.ville,
      'lieu': lieu,
      'photo': photo,
    });
    return 'brouillon-1';
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
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appelsPublier.add({
      'nomRestaurant': lieu.nom,
      'ville': lieu.ville,
      'lieu': lieu,
      'photos': photos,
      'emotion': emotion,
      'legende': legende,
      'amisTaguesIds': amisTaguesIds,
      'impressions': impressions,
      'boissonTexte': boissonTexte,
      'boissonPhoto': boissonPhoto,
      'audience': audience,
    });
    return audience.tableIds.where(tablesEnEchec.contains).toList();
  }

  @override
  Future<({AudienceSouvenir audience, Set<String> amisTaguesIds})>
  audienceActuelle(String souvenirId) => throw UnimplementedError();

  @override
  Future<List<String>> modifierAudience(
    String souvenirId,
    AudienceSouvenir audience,
  ) => throw UnimplementedError();

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> feed() => throw UnimplementedError();
  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) =>
      throw UnimplementedError();

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) =>
      throw UnimplementedError();

  @override
  Future<void> commenter(
    String souvenirId,
    String texte, {
    String? parentId,
  }) => throw UnimplementedError();

  @override
  Future<void> basculerJaimeCommentaire(
    String commentaireId, {
    required bool aimer,
  }) => throw UnimplementedError();

  @override
  Future<MomentModifiable> momentModifiable(String souvenirId) async =>
      momentAModifier!;

  @override
  Future<List<String>> modifier(
    String souvenirId,
    MomentModifiable moment,
  ) async {
    if (erreur) throw Exception('erreur réseau');
    appelsModifier.add((id: souvenirId, moment: moment));
    return const [];
  }

  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
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

  _FauxAbonnementService({this.amis = const []});

  final List<ProfilPublic> amis;

  @override
  Future<List<ProfilPublic>> mesRelations() async => amis;

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

/// Faux [TableService] minimal : seul `mesTables` est exercé par le
/// composer (megaprompt Bloc 5, règle 19 — Tables où l'utilisateur a
/// une adhésion active), le reste n'a pas de rôle dans ces tests.
class _FauxTableService implements TableService {
  @override
  Future<Map<String, Set<String>>> membresActifsParTable(
    List<String> tableIds,
  ) async => {for (final id in tableIds) id: <String>{}};

  _FauxTableService({this.tables = const []});

  final List<ResumeTable> tables;

  @override
  Future<List<ResumeTable>> mesTables() async => tables;

  @override
  Future<List<ResumeTable>> mesInvitations() => throw UnimplementedError();
  @override
  Future<GroupeTable> creer({
    required String nom,
    String? emoji,
    List<String> membresInvitesIds = const [],
  }) => throw UnimplementedError();
  @override
  Future<GroupeTable> table(String tableId) => throw UnimplementedError();
  @override
  Future<void> accepterInvitation(String tableId) => throw UnimplementedError();
  @override
  Future<void> refuserInvitation(String tableId) => throw UnimplementedError();
  @override
  Future<void> inviter(String tableId, String profilId) =>
      throw UnimplementedError();
  @override
  Future<void> quitter(String tableId) => throw UnimplementedError();
  @override
  Future<void> retirerMembre(String tableId, String profilId) =>
      throw UnimplementedError();
  @override
  Future<void> renommer(String tableId, String nom) =>
      throw UnimplementedError();
  @override
  Future<void> supprimer(String tableId) => throw UnimplementedError();
  @override
  Future<
    ({
      List<ExperienceHistoireTable> experiences,
      List<RecurrenceTable> laOuOnRevient,
    })
  >
  histoire(String tableId) => throw UnimplementedError();
  @override
  Future<List<PropositionTable>> propositions(String tableId) =>
      throw UnimplementedError();
  @override
  Future<({PropositionTable proposition, bool dejaExistante})> proposer({
    required String tableId,
    required String nomRestaurant,
    required String ville,
  }) => throw UnimplementedError();
  @override
  Future<void> repondreProposition(String propositionId, {required bool go}) =>
      throw UnimplementedError();
  @override
  Future<List<DecouverteTable>> decouvertes(String tableId) =>
      throw UnimplementedError();
  @override
  Future<DetailProposition> detailProposition(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<void> definirDatesCandidates(
    String propositionId,
    List<DateTime> datesLocales,
  ) => throw UnimplementedError();
  @override
  Future<void> soumettreDisponibilites(
    String propositionId,
    List<String> dateCandidateIds,
  ) => throw UnimplementedError();
  @override
  Future<void> confirmerDate({
    required String propositionId,
    required String dateCandidateId,
    required String fuseauHoraire,
  }) => throw UnimplementedError();
  @override
  Future<void> ajouterHeure(String propositionId, String heure) =>
      throw UnimplementedError();
  @override
  Future<void> replanifier(String propositionId) => throw UnimplementedError();
  @override
  Future<void> annulerProposition(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<List<MessageOrganisation>> messagesOrganisation(
    String propositionId,
  ) => throw UnimplementedError();
  @override
  Future<void> envoyerMessageOrganisation(
    String propositionId,
    String contenu,
  ) => throw UnimplementedError();
  @override
  Future<void> supprimerMessageOrganisation(String messageId) =>
      throw UnimplementedError();
}

// Un vrai PNG 1×1 valide (pas des octets arbitraires) : Image.memory
// décode réellement le contenu dans les tests, un contenu invalide fait
// planter le codec de manière asynchrone.
final _octetsPhoto = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

/// Faux annuaire : [proches] autour de n'importe quel endroit, et [lieux]
/// dont le nom contient le texte tapé.
class _FausseRechercheLieu implements RechercheLieuService {
  _FausseRechercheLieu({this.lieux = const [], this.proches = const []});

  final List<LieuRestaurant> lieux;
  final List<LieuRestaurant> proches;
  final List<({double latitude, double longitude})> autourDe = [];

  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async {
    final t = texte.toLowerCase();
    return lieux.where((l) => l.nom.toLowerCase().contains(t)).toList();
  }

  @override
  Future<List<LieuRestaurant>> lieuxProches({
    required double latitude,
    required double longitude,
    double rayonM = 250,
    int limite = 8,
  }) async {
    autourDe.add((latitude: latitude, longitude: longitude));
    return proches;
  }

  @override
  Future<List<LieuRestaurant>> mesLieuxPersonnels() async => const [];
}

class _FaussePosition implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.6326, longitude: 5.5797);
}

const _comptoir = LieuRestaurant(
  fsqPlaceId: 'fsq-comptoir',
  nom: 'Le Comptoir',
  ville: 'Liège',
  latitude: 50.6327,
  longitude: 5.5799,
  distanceM: 42,
);

const _comoEnCasa = LieuRestaurant(
  fsqPlaceId: 'fsq-como',
  nom: 'Como en Casa',
  ville: 'Liège',
  latitude: 50.6471,
  longitude: 5.5802,
  categories: ['Vegan and Vegetarian Restaurant'],
);

const _sarah = ProfilPublic(
  id: 'ami-1',
  pseudo: 'sarah',
  statut: StatutAbonnement.abonne,
);

const _marbella = ResumeTable(
  id: 'table-1',
  nom: 'Marbella',
  nombreMembres: 3,
  etatTexte: 'Rien de nouveau',
  actionRequise: false,
);

/// Pousse EcranPublier sur une pile de navigation réelle (pour que
/// `Navigator.pop()` ait un écran en dessous, comme en vrai — poussé
/// depuis EcranPrincipal). Par défaut : on est au Comptoir, l'appareil
/// photo et la photothèque donnent chacun une photo.
Future<void> _ouvrir(
  WidgetTester tester,
  _FauxSouvenirService service, {
  AbonnementService? abonnementService,
  TableService? tableService,
  RechercheLieuService? rechercheLieuService,
  PositionService? positionService,
  bool sansAnnuaire = false,
  SouvenirFeed? aModifier,
}) async {
  tester.view.physicalSize = const Size(1000, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<bool>(
                builder: (_) => EcranPublier(
                  souvenirService: service,
                  abonnementService:
                      abonnementService ?? _FauxAbonnementService(),
                  tableService: tableService,
                  rechercheLieuService: sansAnnuaire
                      ? null
                      : rechercheLieuService ??
                            _FausseRechercheLieu(proches: const [_comptoir]),
                  positionService: positionService ?? _FaussePosition(),
                  prendrePhoto: () async => _octetsPhoto,
                  choisirPhotos: (restant) async => [_octetsPhoto],
                  aModifier: aModifier,
                ),
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

/// Une photo prise, et « 🙂 » : tout ce qu'il faut pour publier.
Future<void> _photoEtRessenti(WidgetTester tester) async {
  await tester.tap(find.text('Prendre une photo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('🙂'));
  await tester.pumpAndSettle();
}

Future<void> _garder(WidgetTester tester) async {
  await tester.tap(find.text('Garder ce moment.'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

/// Ouvre la feuille "Qui peut voir ?", choisit [mode], coche [choix]
/// (Tables ou personnes) puis valide.
Future<void> _choisirAudience(
  WidgetTester tester,
  String mode, {
  List<String> choix = const [],
}) async {
  await tester.ensureVisible(find.text('Qui peut voir'));
  await tester.tap(find.text('Qui peut voir'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(mode));
  await tester.pumpAndSettle();
  for (final libelle in choix) {
    final puce = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(libelle),
    );
    await tester.ensureVisible(puce);
    await tester.tap(puce);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.text('Enregistrer'));
  await tester.tap(find.text('Enregistrer'));
  await tester.pumpAndSettle();
}

/// Ouvre une ligne d'option ([libelle]), y touche [choix], et valide.
Future<void> _option(
  WidgetTester tester,
  String libelle,
  List<String> choix,
) async {
  await tester.ensureVisible(find.text(libelle));
  await tester.tap(find.text(libelle));
  await tester.pumpAndSettle();
  for (final c in choix) {
    await tester.tap(
      find.descendant(of: find.byType(BottomSheet), matching: find.text(c)),
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Valider'));
  await tester.pumpAndSettle();
}

Map<String, Object?> _publie(_FauxSouvenirService service) =>
    service.appelsPublier.single;

AudienceSouvenir _audiencePubliee(_FauxSouvenirService service) =>
    _publie(service)['audience']! as AudienceSouvenir;

FilledButton _bouton(WidgetTester tester) => tester.widget<FilledButton>(
  find.widgetWithText(FilledButton, 'Garder ce moment.'),
);

void main() {
  testWidgets('à l\'ouverture : la photo d\'abord, le restaurant où l\'on '
      'est déjà proposé', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService());

    expect(find.text('Prendre une photo'), findsOneWidget);
    expect(find.text('Photothèque'), findsOneWidget);
    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(find.text('Liège · à 40 m de vous'), findsOneWidget);
    expect(find.text('Une photo d\'abord.'), findsOneWidget);
    expect(_bouton(tester).onPressed, isNull);
  });

  testWidgets('une photo, un ressenti : le moment est gardé, l\'écran se '
      'referme', (tester) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service);

    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();
    expect(find.text('Comment c\'était ?'), findsWidgets);
    expect(_bouton(tester).onPressed, isNull);

    await tester.tap(find.text('🤩'));
    await tester.pumpAndSettle();
    expect(_bouton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Garder ce moment.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Moment gardé.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final appel = _publie(service);
    expect((appel['lieu']! as LieuRestaurant).fsqPlaceId, 'fsq-comptoir');
    expect(appel['photos'], hasLength(1));
    expect(appel['emotion'], Emotion.inoubliable);
    expect(find.byType(EcranPublier), findsNothing);
  });

  testWidgets('glisser après la dernière photo pour en ajouter une', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service);
    await _photoEtRessenti(tester);

    await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Une autre photo ?'), findsOneWidget);

    await tester.tap(find.text('Photothèque'));
    await tester.pumpAndSettle();
    // La nouvelle photo est affichée, deux vignettes dessous.
    expect(find.text('Une autre photo ?'), findsNothing);
    expect(find.bySemanticsLabel('Photo 2'), findsOneWidget);

    await _garder(tester);
    expect(_publie(service)['photos'], hasLength(2));
  });

  testWidgets('« Changer » : un autre restaurant, cherché dans l\'annuaire', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(
      tester,
      service,
      rechercheLieuService: _FausseRechercheLieu(
        lieux: const [_comoEnCasa],
        proches: const [_comptoir],
      ),
    );
    await _photoEtRessenti(tester);

    await tester.tap(find.text('Changer'));
    await tester.pumpAndSettle();
    expect(find.text('PRÈS DE VOUS'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'como',
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Como en Casa').last);
    await tester.pumpAndSettle();

    expect(find.text('Como en Casa'), findsOneWidget);
    await _garder(tester);
    expect(
      (_publie(service)['lieu']! as LieuRestaurant).fsqPlaceId,
      'fsq-como',
    );
  });

  testWidgets('saisi à la main : il prend la position du téléphone', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service, sansAnnuaire: true);
    expect(find.text('Où êtes-vous ?'), findsWidgets);

    await _photoEtRessenti(tester);
    await tester.tap(find.text('Choisir'));
    await tester.pumpAndSettle();
    final champs = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(champs.first, 'Chez K');
    await tester.enterText(champs.last, 'Liège');
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pumpAndSettle();

    await _garder(tester);
    final lieu = _publie(service)['lieu']! as LieuRestaurant;
    expect(lieu.estManuel, isTrue);
    expect(lieu.nom, 'Chez K');
    expect(lieu.latitude, 50.6326);
  });

  testWidgets('« Avec qui ? » : la personne taguée est transmise', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(
      tester,
      service,
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _photoEtRessenti(tester);

    await _option(tester, 'Avec qui ?', ['sarah']);
    expect(find.text('Avec sarah'), findsOneWidget);
    // Profil privé et sarah n'est pas une abonnée : « Tout le monde » ne
    // l'inclut pas.
    expect(find.text('sarah ne verra pas ce moment.'), findsOneWidget);

    await _garder(tester);
    expect(_publie(service)['amisTaguesIds'], ['ami-1']);
  });

  testWidgets('« Ce qui ressort » et la boisson sont transmis', (tester) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service);
    await _photoEtRessenti(tester);

    await _option(tester, 'Ce qui ressort', [
      'Assiette · Exceptionnelle',
      'Service · Attentionné',
    ]);
    expect(
      find.text('Assiette · Exceptionnelle, Service · Attentionné'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Une boisson ?'));
    await tester.tap(find.text('Une boisson ?'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(TextField),
      ),
      'Un Margaux 2018',
    );
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Un Margaux 2018'), findsOneWidget);

    await _garder(tester);
    expect(_publie(service)['impressions'], [
      'Assiette · Exceptionnelle',
      'Service · Attentionné',
    ]);
    expect(_publie(service)['boissonTexte'], 'Un Margaux 2018');
  });

  testWidgets('"Seulement…" une personne : transmis à la publication', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(
      tester,
      service,
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _photoEtRessenti(tester);
    expect(find.text('Tout le monde'), findsOneWidget);

    await _choisirAudience(tester, 'Seulement…', choix: ['sarah']);
    expect(find.text('Seulement sarah'), findsOneWidget);

    await _garder(tester);
    final audience = _audiencePubliee(service);
    expect(audience.mode, ModeAudience.seulement);
    expect(audience.personneIds, {'ami-1'});
  });

  testWidgets('"Tout le monde sauf…" : la personne exclue est transmise', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(
      tester,
      service,
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _photoEtRessenti(tester);

    await _choisirAudience(tester, 'Tout le monde sauf…', choix: ['sarah']);
    expect(find.text('Tout le monde sauf 1 personne'), findsOneWidget);

    await _garder(tester);
    final audience = _audiencePubliee(service);
    expect(audience.mode, ModeAudience.sauf);
    expect(audience.personneIds, {'ami-1'});
  });

  testWidgets('"Seulement…" une Table : transmise à la publication', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(
      tester,
      service,
      tableService: _FauxTableService(tables: const [_marbella]),
    );
    await _photoEtRessenti(tester);

    await _choisirAudience(tester, 'Seulement…', choix: ['Marbella']);
    expect(find.text('Seulement Marbella'), findsOneWidget);

    await _garder(tester);
    expect(_audiencePubliee(service).tableIds, {'table-1'});
  });

  testWidgets('Table en échec : publié quand même, et on le dit', (
    tester,
  ) async {
    final service = _FauxSouvenirService(tablesEnEchec: const ['table-1']);
    await _ouvrir(
      tester,
      service,
      tableService: _FauxTableService(tables: const [_marbella]),
    );
    await _photoEtRessenti(tester);
    await _choisirAudience(tester, 'Seulement…', choix: ['Marbella']);

    await tester.tap(find.text('Garder ce moment.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      find.text('Publié, mais impossible de le partager avec 1 Table.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(service.appelsPublier, hasLength(1));
    expect(find.byType(EcranPublier), findsNothing);
  });

  testWidgets('erreur du service à la publication → message, on reste', (
    tester,
  ) async {
    await _ouvrir(tester, _FauxSouvenirService(erreur: true));
    await _photoEtRessenti(tester);

    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
    expect(find.text('Moment gardé.'), findsNothing);
    expect(find.byType(EcranPublier), findsOneWidget);
  });

  testWidgets('fermer avec une photo : « Plus tard » garde un brouillon', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service);
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Abandonner ce moment ?'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.byType(EcranPublier), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(service.appelsBrouillon.single['nomRestaurant'], 'Le Comptoir');
    expect(find.byType(EcranPublier), findsNothing);
  });

  testWidgets('fermer avec une photo : « Abandonner » ne garde rien', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrir(tester, service);
    await tester.tap(find.text('Prendre une photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abandonner'));
    await tester.pumpAndSettle();

    expect(service.appelsBrouillon, isEmpty);
    expect(service.appelsPublier, isEmpty);
    expect(find.byType(EcranPublier), findsNothing);
  });

  group('modifier un moment déjà publié', () {
    final publie = SouvenirFeed(
      id: 'm1',
      photoUrl: 'https://exemple.com/1.jpg',
      legende: 'Onze petites assiettes.',
      restaurantNom: 'Le Comptoir',
      ville: 'Liège',
      moment: 'soir',
      dateVisite: DateTime(2026, 8, 20),
      auteurPseudo: 'moi',
      nombreReactions: 0,
      jaiReagi: false,
      nombreCommentaires: 0,
      estAMoi: true,
    );
    const tel = MomentModifiable(
      lieu: LieuRestaurant(
        nom: 'Le Comptoir',
        ville: 'Liège',
        restaurantId: 'resto-1',
      ),
      emotion: Emotion.satisfait,
      legende: 'Onze petites assiettes.',
      amisTaguesIds: {'ami-1'},
      impressions: ['Prix · Correct'],
      boissonTexte: 'Un Margaux 2018',
    );
    final sarah = _FauxAbonnementService(amis: const [_sarah]);

    testWidgets('tout est prérempli ; pas de photo à ajouter, ni de '
        'restaurant proposé', (tester) async {
      final annuaire = _FausseRechercheLieu(proches: const [_comoEnCasa]);
      await _ouvrir(
        tester,
        _FauxSouvenirService(momentAModifier: tel),
        abonnementService: sarah,
        rechercheLieuService: annuaire,
        aModifier: publie,
      );

      expect(find.text('MOMENT · 20 AOÛT'), findsOneWidget);
      expect(find.text('Le Comptoir'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Onze petites assiettes.'),
        findsOneWidget,
      );
      expect(find.text('Avec sarah'), findsOneWidget);
      expect(find.text('Prix · Correct'), findsOneWidget);
      expect(find.text('Un Margaux 2018'), findsOneWidget);
      expect(find.text('Enregistrer'), findsOneWidget);
      expect(find.text('Prendre une photo'), findsNothing);
      expect(find.text('Retirer'), findsNothing);
      expect(annuaire.autourDe, isEmpty);
    });

    testWidgets('« Enregistrer » envoie le moment modifié, et ferme', (
      tester,
    ) async {
      final service = _FauxSouvenirService(momentAModifier: tel);
      await _ouvrir(
        tester,
        service,
        abonnementService: sarah,
        aModifier: publie,
      );

      await tester.tap(find.text('😍'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Onze petites assiettes.'),
        'Douze, finalement.',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();

      final appel = service.appelsModifier.single;
      expect(appel.id, 'm1');
      expect(appel.moment.emotion, Emotion.coupDeCoeur);
      expect(appel.moment.legende, 'Douze, finalement.');
      expect(appel.moment.lieu.restaurantId, 'resto-1');
      expect(appel.moment.amisTaguesIds, {'ami-1'});
      expect(appel.moment.impressions, ['Prix · Correct']);
      expect(appel.moment.boissonTexte, 'Un Margaux 2018');
      expect(find.byType(EcranPublier), findsNothing);
    });

    testWidgets('fermer sans rien changer ne demande rien', (tester) async {
      await _ouvrir(
        tester,
        _FauxSouvenirService(momentAModifier: tel),
        abonnementService: sarah,
        aModifier: publie,
      );

      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();

      expect(find.byType(EcranPublier), findsNothing);
    });

    testWidgets('fermer après un changement demande confirmation', (
      tester,
    ) async {
      final service = _FauxSouvenirService(momentAModifier: tel);
      await _ouvrir(
        tester,
        service,
        abonnementService: sarah,
        aModifier: publie,
      );

      await tester.tap(find.text('😍'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('Abandonner les modifications ?'), findsOneWidget);

      await tester.tap(find.text('Abandonner'));
      await tester.pumpAndSettle();

      expect(find.byType(EcranPublier), findsNothing);
      expect(service.appelsModifier, isEmpty);
    });

    testWidgets('revenir en arrière après avoir tapé du texte demande '
        'confirmation', (tester) async {
      await _ouvrir(
        tester,
        _FauxSouvenirService(momentAModifier: tel),
        abonnementService: sarah,
        aModifier: publie,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Onze petites assiettes.'),
        'Douze.',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Abandonner les modifications ?'), findsOneWidget);
    });
  });
}
