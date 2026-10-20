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
  @override
  Future<List<SouvenirFeed>> mesMomentsAvec(String profilId) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async => [];

  @override
  Future<void> basculerEnvie(
    String restaurantId, {
    required bool envie,
  }) async {}

  _FauxSouvenirService({this.erreur = false, this.tablesEnEchec = const []});

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
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appelsPublier.add({
      'nomRestaurant': lieu.nom,
      'ville': lieu.ville,
      'lieu': lieu,
      'photo': photo,
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
  Future<void> commenter(String souvenirId, String texte) =>
      throw UnimplementedError();

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

/// Faux annuaire : renvoie [lieux] dont le nom contient le texte tapé.
class _FausseRechercheLieu implements RechercheLieuService {
  _FausseRechercheLieu(this.lieux);

  final List<LieuRestaurant> lieux;
  final List<({String texte, double? latitude})> appels = [];

  @override
  Future<List<LieuRestaurant>> rechercher(
    String texte, {
    double? latitude,
    double? longitude,
  }) async {
    appels.add((texte: texte, latitude: latitude));
    final t = texte.toLowerCase();
    return lieux.where((l) => l.nom.toLowerCase().contains(t)).toList();
  }
}

class _FaussePosition implements PositionService {
  @override
  Future<Coordonnees?> positionActuelle() async =>
      (latitude: 50.6326, longitude: 5.5797);
}

const _comoEnCasa = LieuRestaurant(
  fsqPlaceId: 'fsq-como',
  nom: 'Como en Casa',
  ville: 'Liège',
  adresse: 'Rue Hors-Château 76',
  latitude: 50.6471,
  longitude: 5.5802,
  categories: ['Vegan and Vegetarian Restaurant'],
  distanceM: 1620,
);

/// Pousse EcranPublier sur une pile de navigation réelle (pour que
/// `Navigator.pop()` ait un écran en dessous, comme en vrai — poussé
/// depuis EcranPrincipal).
Future<void> _ouvrirEcranPublier(
  WidgetTester tester,
  SouvenirService service, {
  AbonnementService? abonnementService,
  TableService? tableService,
  RechercheLieuService? rechercheLieuService,
  PositionService? positionService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EcranPublier(
                  souvenirService: service,
                  abonnementService:
                      abonnementService ?? _FauxAbonnementService(),
                  tableService: tableService,
                  rechercheLieuService: rechercheLieuService,
                  positionService: positionService,
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

/// Remplit l'étape Lieu et avance jusqu'à Capturer.
Future<void> _remplirLieu(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'Le Comptoir');
  await tester.enterText(find.byType(TextField).last, 'Paris');
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
}

/// Depuis Capturer : appuie sur le déclencheur, choisit la photothèque
/// dans la feuille proposée.
Future<void> _capturerPhoto(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('bouton-declencheur')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choisir depuis la photothèque'));
  await tester.pumpAndSettle();
}

/// Depuis Lieu : avance jusqu'à l'étape Finaliser (Lieu → Capturer →
/// photo → Brouillon → "Finaliser maintenant").
Future<void> _avancerJusquauFinaliser(WidgetTester tester) async {
  await _remplirLieu(tester);
  await _capturerPhoto(tester);
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finaliser maintenant'));
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

AudienceSouvenir _audiencePubliee(_FauxSouvenirService service) =>
    service.appelsPublier.single['audience']! as AudienceSouvenir;

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

void main() {
  setUp(() {
    ImagePickerPlatform.instance = _FauxImagePickerPlatform(
      octets: _octetsPhoto,
    );
  });

  testWidgets('étape Lieu : champs vides → erreurs, ne passe pas à Capturer', (
    tester,
  ) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());

    expect(find.text('Où êtes-vous ?'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Entre le nom du restaurant.'), findsOneWidget);
    expect(find.text('Entre la ville.'), findsOneWidget);
    expect(find.text('Où êtes-vous ?'), findsOneWidget);
  });

  testWidgets('Lieu rempli → Capturer, "Continuer" désactivé sans photo', (
    tester,
  ) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());
    await _remplirLieu(tester);

    expect(find.text('Le Comptoir'), findsOneWidget);
    expect(find.text('Continuer'), findsNothing);
  });

  testWidgets('capturer une photo affiche "Continuer" vers Brouillon', (
    tester,
  ) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());
    await _remplirLieu(tester);
    await _capturerPhoto(tester);
    await tester.pumpAndSettle();

    expect(find.text('Continuer'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    expect(find.text('Moment enregistré.'), findsOneWidget);
  });

  testWidgets('"Plus tard" enregistre un brouillon et revient en arrière', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(tester, service);
    await _remplirLieu(tester);
    await _capturerPhoto(tester);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();

    expect(service.appelsBrouillon, hasLength(1));
    expect(service.appelsBrouillon.single['nomRestaurant'], 'Le Comptoir');
    expect(service.appelsBrouillon.single['ville'], 'Paris');
    expect(find.byType(EcranPublier), findsNothing);
    expect(
      find.text('Enregistré. Reprenez-le depuis votre profil.'),
      findsOneWidget,
    );
  });

  testWidgets(
    '"Finaliser maintenant" amène sur Finaliser, bouton grisé sans émotion',
    (tester) async {
      await _ouvrirEcranPublier(tester, _FauxSouvenirService());
      await _avancerJusquauFinaliser(tester);

      expect(find.text('Comment c\'était ?'), findsOneWidget);
      final bouton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Garder ce moment.'),
      );
      expect(bouton.onPressed, isNull);
    },
  );

  testWidgets('choisir une émotion active "Garder ce moment."', (tester) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('😍'));
    await tester.pumpAndSettle();

    final bouton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Garder ce moment.'),
    );
    expect(bouton.onPressed, isNotNull);
  });

  testWidgets(
    'parcours complet : publie avec émotion, puis anime et confirme',
    (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEcranPublier(tester, service);
      await _avancerJusquauFinaliser(tester);

      await tester.tap(find.text('🤩'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      expect(service.appelsPublier, hasLength(1));
      final appel = service.appelsPublier.single;
      expect(appel['nomRestaurant'], 'Le Comptoir');
      expect(appel['ville'], 'Paris');
      expect(appel['emotion'], Emotion.inoubliable);
      // "Tout le monde" par défaut.
      expect(
        (appel['audience']! as AudienceSouvenir).mode,
        ModeAudience.toutLeMonde,
      );

      // L'animation de publication (~1,5 s) enchaîne automatiquement.
      expect(find.text('Moment ajouté.'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pumpAndSettle();

      expect(find.text('Moment ajouté.'), findsOneWidget);
      await tester.tap(find.text('Retourner au feed'));
      await tester.pumpAndSettle();

      expect(find.byType(EcranPublier), findsNothing);
    },
  );

  testWidgets('"Seulement…" une personne : transmis à la publication', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(
      tester,
      service,
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('🙂'));
    await tester.pumpAndSettle();
    expect(find.text('Tout le monde'), findsOneWidget);

    await _choisirAudience(tester, 'Seulement…', choix: ['sarah']);
    expect(find.text('Seulement sarah'), findsOneWidget);

    await tester.ensureVisible(find.text('Garder ce moment.'));
    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    final audience = _audiencePubliee(service);
    expect(audience.mode, ModeAudience.seulement);
    expect(audience.personneIds, {'ami-1'});
  });

  testWidgets('"Seulement…" sans rien cocher : impossible d\'enregistrer', (
    tester,
  ) async {
    await _ouvrirEcranPublier(tester, _FauxSouvenirService());
    await _avancerJusquauFinaliser(tester);

    await tester.ensureVisible(find.text('Qui peut voir'));
    await tester.tap(find.text('Qui peut voir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seulement…'));
    await tester.pumpAndSettle();

    final bouton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enregistrer'),
    );
    expect(bouton.onPressed, isNull);
  });

  testWidgets('"Tout le monde sauf…" : la personne exclue est transmise', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(
      tester,
      service,
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('🙂'));
    await _choisirAudience(tester, 'Tout le monde sauf…', choix: ['sarah']);
    expect(find.text('Tout le monde sauf 1 personne'), findsOneWidget);

    await tester.ensureVisible(find.text('Garder ce moment.'));
    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    final audience = _audiencePubliee(service);
    expect(audience.mode, ModeAudience.sauf);
    expect(audience.personneIds, {'ami-1'});
  });

  testWidgets('ami tagué hors audience : avertissement sous "Qui peut voir"', (
    tester,
  ) async {
    // Profil privé et sarah ne fait pas partie des abonnés : "Tout le
    // monde" ne l'inclut pas.
    await _ouvrirEcranPublier(
      tester,
      _FauxSouvenirService(),
      abonnementService: _FauxAbonnementService(amis: const [_sarah]),
    );
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('sarah'));
    await tester.pumpAndSettle();

    expect(find.text('sarah ne verra pas ce moment.'), findsOneWidget);
  });

  testWidgets(
    'sélectionner des impressions ("Ce qui ressort") les inclut à la publication',
    (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEcranPublier(tester, service);
      await _avancerJusquauFinaliser(tester);

      await tester.tap(find.text('🙂'));
      await tester.ensureVisible(find.text('Assiette · Exceptionnelle'));
      await tester.tap(find.text('Assiette · Exceptionnelle'));
      await tester.tap(find.text('Service · Attentionné'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      expect(service.appelsPublier.single['impressions'], [
        'Assiette · Exceptionnelle',
        'Service · Attentionné',
      ]);
    },
  );

  testWidgets('taguer un ami l\'inclut dans la publication', (tester) async {
    final service = _FauxSouvenirService();
    final abonnementService = _FauxAbonnementService(amis: const [_sarah]);
    await _ouvrirEcranPublier(
      tester,
      service,
      abonnementService: abonnementService,
    );
    await _avancerJusquauFinaliser(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('🙂'));
    await tester.tap(find.text('sarah'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Garder ce moment.'));
    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    expect(service.appelsPublier.single['amisTaguesIds'], ['ami-1']);
  });

  testWidgets('erreur du service à la publication → message générique', (
    tester,
  ) async {
    final service = _FauxSouvenirService(erreur: true);
    await _ouvrirEcranPublier(tester, service);
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('🙂'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Garder ce moment.'));
    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
    // Toujours sur l'écran de finalisation : pas d'avancée en cas
    // d'échec.
    expect(find.text('Comment c\'était ?'), findsOneWidget);
  });

  testWidgets(
    '"Seulement…" une Table : transmise à la publication (megaprompt Bloc 5)',
    (tester) async {
      final service = _FauxSouvenirService();
      await _ouvrirEcranPublier(
        tester,
        service,
        tableService: _FauxTableService(tables: const [_marbella]),
      );
      await _avancerJusquauFinaliser(tester);

      await tester.tap(find.text('🙂'));
      await _choisirAudience(tester, 'Seulement…', choix: ['Marbella']);
      // Règle 13 : le résumé nomme la Table, jamais "audience"/"grant".
      expect(find.text('Seulement Marbella'), findsOneWidget);

      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      expect(_audiencePubliee(service).tableIds, {'table-1'});
    },
  );

  testWidgets(
    'échec d\'association à une Table : la publication réussit malgré tout '
    '(règle 51)',
    (tester) async {
      final service = _FauxSouvenirService(tablesEnEchec: const ['table-1']);
      await _ouvrirEcranPublier(
        tester,
        service,
        tableService: _FauxTableService(tables: const [_marbella]),
      );
      await _avancerJusquauFinaliser(tester);

      await tester.tap(find.text('🙂'));
      await _choisirAudience(tester, 'Seulement…', choix: ['Marbella']);
      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      expect(
        find.text('Publié, mais impossible de l\'ajouter à cette Table.'),
        findsOneWidget,
      );
      // La publication a bien avancé jusqu'à l'animation malgré l'échec
      // d'association — jamais de ghost post, mais pas non plus un blocage
      // de la publication elle-même pour un problème d'association.
      expect(find.text('Comment c\'était ?'), findsNothing);
    },
  );

  group('recherche du restaurant dans l\'annuaire', () {
    testWidgets('taper affiche les suggestions, un tap passe à la photo', (
      tester,
    ) async {
      final recherche = _FausseRechercheLieu([_comoEnCasa]);
      final service = _FauxSouvenirService();
      await _ouvrirEcranPublier(
        tester,
        service,
        rechercheLieuService: recherche,
        positionService: _FaussePosition(),
      );

      await tester.enterText(find.byType(TextField), 'como');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('Como en Casa'), findsOneWidget);
      expect(
        find.text('Végétarien · Rue Hors-Château 76, Liège · 1,6 km'),
        findsOneWidget,
      );
      // La position du téléphone sert au tri par proximité.
      expect(recherche.appels.last.latitude, 50.6326);

      await tester.tap(find.text('Como en Casa'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bouton-declencheur')), findsOneWidget);

      await _capturerPhoto(tester);
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finaliser maintenant'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      final lieu = service.appelsPublier.single['lieu']! as LieuRestaurant;
      expect(lieu.fsqPlaceId, 'fsq-como');
    });

    testWidgets(
      '"Je ne trouve pas mon restaurant" : saisie à la main, avec la position',
      (tester) async {
        final service = _FauxSouvenirService();
        await _ouvrirEcranPublier(
          tester,
          service,
          rechercheLieuService: _FausseRechercheLieu(const []),
          positionService: _FaussePosition(),
        );

        await tester.enterText(find.byType(TextField), 'Chez K');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('Aucun restaurant trouvé.'), findsOneWidget);

        await tester.tap(find.text('Je ne trouve pas mon restaurant'));
        await tester.pumpAndSettle();

        // Le nom déjà tapé est repris.
        expect(find.text('Chez K'), findsOneWidget);
        await tester.enterText(find.byType(TextField).last, 'Liège');
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();

        await _capturerPhoto(tester);
        await tester.tap(find.text('Continuer'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plus tard'));
        await tester.pumpAndSettle();

        final lieu = service.appelsBrouillon.single['lieu']! as LieuRestaurant;
        expect(lieu.estManuel, isTrue);
        expect(lieu.nom, 'Chez K');
        expect(lieu.latitude, 50.6326);
      },
    );
  });
}
