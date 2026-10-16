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
  _FauxSouvenirService({this.erreur = false, this.tablesEnEchec = const []});

  final bool erreur;

  /// Identifiants de Table que [publier] doit signaler en échec
  /// d'association (règle 51) — le souvenir reste publié malgré tout.
  final List<String> tablesEnEchec;

  final List<Map<String, Object?>> appelsPublier = [];
  final List<Map<String, Object?>> appelsBrouillon = [];
  final List<Map<String, Object?>> appelsModifierPartage = [];

  @override
  Future<String> enregistrerBrouillon({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appelsBrouillon.add({
      'nomRestaurant': nomRestaurant,
      'ville': ville,
      'photo': photo,
    });
    return 'brouillon-1';
  }

  @override
  Future<List<String>> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    List<String> impressions = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    bool partagerAvecCercle = true,
    List<String> tableIds = const [],
  }) async {
    if (erreur) throw Exception('erreur réseau');
    appelsPublier.add({
      'nomRestaurant': nomRestaurant,
      'ville': ville,
      'photo': photo,
      'emotion': emotion,
      'legende': legende,
      'amisTaguesIds': amisTaguesIds,
      'impressions': impressions,
      'boissonTexte': boissonTexte,
      'boissonPhoto': boissonPhoto,
      'partagerAvecCercle': partagerAvecCercle,
      'tableIds': tableIds,
    });
    return tableIds.where(tablesEnEchec.contains).toList();
  }

  @override
  Future<({bool partagerAvecCercle, List<String> tableIds})> partageActuel(
    String souvenirId,
  ) => throw UnimplementedError();

  @override
  Future<List<String>> modifierPartage(
    String souvenirId, {
    required bool partagerAvecCercle,
    required List<String> tableIds,
  }) async {
    appelsModifierPartage.add({
      'souvenirId': souvenirId,
      'partagerAvecCercle': partagerAvecCercle,
      'tableIds': tableIds,
    });
    return const [];
  }

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
  _FauxAbonnementService({this.amis = const []});

  final List<ProfilPublic> amis;

  @override
  Future<List<ProfilPublic>> mesAmis() async => amis;

  @override
  Future<List<ProfilPublic>> rechercher(String requete) =>
      throw UnimplementedError();
  @override
  Future<void> suivre(String suiviId) => throw UnimplementedError();
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
  Future<List<MessageOrganisation>> messagesOrganisation(String propositionId) =>
      throw UnimplementedError();
  @override
  Future<void> envoyerMessageOrganisation(String propositionId, String contenu) =>
      throw UnimplementedError();
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

/// Pousse EcranPublier sur une pile de navigation réelle (pour que
/// `Navigator.pop()` ait un écran en dessous, comme en vrai — poussé
/// depuis EcranPrincipal).
Future<void> _ouvrirEcranPublier(
  WidgetTester tester,
  SouvenirService service, {
  AbonnementService? abonnementService,
  TableService? tableService,
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
                  abonnementService: abonnementService ?? _FauxAbonnementService(),
                  tableService: tableService,
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

  testWidgets('choisir une émotion active "Garder ce moment."', (
    tester,
  ) async {
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
      // Partage avec le cercle par défaut.
      expect(appel['partagerAvecCercle'], isTrue);

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

  testWidgets('visibilité "Garder pour moi" transmise à la publication', (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    await _ouvrirEcranPublier(tester, service);
    await _avancerJusquauFinaliser(tester);

    await tester.tap(find.text('🙂'));
    await tester.ensureVisible(find.text('Garder pour moi'));
    await tester.tap(find.text('Garder pour moi'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Garder ce moment.'));
    await tester.tap(find.text('Garder ce moment.'));
    await tester.pumpAndSettle();

    expect(service.appelsPublier.single['partagerAvecCercle'], isFalse);
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
    final abonnementService = _FauxAbonnementService(
      amis: const [
        ProfilPublic(
          id: 'ami-1',
          pseudo: 'sarah',
          statut: StatutAbonnement.abonne,
        ),
      ],
    );
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
    'sélectionner une Table l\'inclut dans la publication et le résumé '
    '(megaprompt Bloc 5)',
    (tester) async {
      final service = _FauxSouvenirService();
      final tableService = _FauxTableService(
        tables: const [
          ResumeTable(
            id: 'table-1',
            nom: 'Marbella',
            nombreMembres: 3,
            etatTexte: 'Rien de nouveau',
            actionRequise: false,
          ),
        ],
      );
      await _ouvrirEcranPublier(tester, service, tableService: tableService);
      await _avancerJusquauFinaliser(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🙂'));
      await tester.pumpAndSettle();
      // Par défaut (cercle, aucune Table) : jamais de jargon "audience".
      expect(find.text('Visible par votre cercle.'), findsOneWidget);

      await tester.ensureVisible(find.text('Marbella'));
      await tester.tap(find.text('Marbella'));
      await tester.pumpAndSettle();

      // Règle 13 : le résumé nomme la Table, jamais "audience"/"grant".
      expect(
        find.text('Visible par votre cercle et les membres de Marbella.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Garder ce moment.'));
      await tester.tap(find.text('Garder ce moment.'));
      await tester.pumpAndSettle();

      expect(service.appelsPublier.single['tableIds'], ['table-1']);
    },
  );

  testWidgets(
    'Table + "Garder pour moi" : résumé jamais "Personnel" (règle 14)',
    (tester) async {
      final service = _FauxSouvenirService();
      final tableService = _FauxTableService(
        tables: const [
          ResumeTable(
            id: 'table-1',
            nom: 'Famille',
            nombreMembres: 4,
            etatTexte: 'Rien de nouveau',
            actionRequise: false,
          ),
        ],
      );
      await _ouvrirEcranPublier(tester, service, tableService: tableService);
      await _avancerJusquauFinaliser(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🙂'));
      await tester.ensureVisible(find.text('Garder pour moi'));
      await tester.tap(find.text('Garder pour moi'));
      await tester.ensureVisible(find.text('Famille'));
      await tester.tap(find.text('Famille'));
      await tester.pumpAndSettle();

      expect(
        find.text('Visible uniquement par les membres de Famille.'),
        findsOneWidget,
      );
      expect(find.textContaining('Personnel'), findsNothing);
    },
  );

  testWidgets(
    'échec d\'association à une Table : la publication réussit malgré tout '
    '(règle 51)',
    (tester) async {
      final service = _FauxSouvenirService(tablesEnEchec: const ['table-1']);
      final tableService = _FauxTableService(
        tables: const [
          ResumeTable(
            id: 'table-1',
            nom: 'Marbella',
            nombreMembres: 3,
            etatTexte: 'Rien de nouveau',
            actionRequise: false,
          ),
        ],
      );
      await _ouvrirEcranPublier(tester, service, tableService: tableService);
      await _avancerJusquauFinaliser(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('🙂'));
      await tester.ensureVisible(find.text('Marbella'));
      await tester.tap(find.text('Marbella'));
      await tester.pumpAndSettle();
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
}
