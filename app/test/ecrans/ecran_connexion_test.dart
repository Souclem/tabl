import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_accueil.dart';
import 'package:app/ecrans/ecran_connexion.dart';

class _FauxAuthService implements AuthService {
  int appelsApple = 0;

  @override
  Future<Utilisateur> connexion({
    required String email,
    required String motDePasse,
  }) => throw UnimplementedError();

  @override
  Future<ResultatInscription> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  }) => throw UnimplementedError();

  @override
  Future<Utilisateur?> utilisateurConnecte() => throw UnimplementedError();

  @override
  Future<ResultatConnexionOAuth?> connexionApple() async {
    appelsApple++;
    // Comme une connexion annulée : l'écran ne fait rien de plus.
    return null;
  }

  @override
  Future<ResultatConnexionOAuth?> connexionGoogle() =>
      throw UnimplementedError();

  @override
  Future<Utilisateur> completerProfil({
    required String id,
    required String email,
    required String pseudo,
  }) => throw UnimplementedError();

  @override
  Future<void> deconnexion() => throw UnimplementedError();

  @override
  Future<void> supprimerCompte() => throw UnimplementedError();
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
  Future<List<ProfilPublic>> rechercher(String requete) =>
      throw UnimplementedError();

  @override
  Future<StatutAbonnement> suivre(String suiviId) => throw UnimplementedError();

  @override
  Future<void> arreterDeSuivre(String suiviId) => throw UnimplementedError();

  @override
  Future<List<DemandeAbonnement>> demandesRecues() =>
      throw UnimplementedError();

  @override
  Future<void> accepterDemande(String suiveurId) => throw UnimplementedError();

  @override
  Future<void> refuserDemande(String suiveurId) => throw UnimplementedError();

  @override
  Future<int> nombreDemandesEnAttente() => throw UnimplementedError();

  @override
  Future<List<ProfilPublic>> mesRelations() => throw UnimplementedError();
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<SouvenirFeed?> souvenir(String souvenirId) => throw UnimplementedError();
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
  Future<List<SouvenirFeed>> souvenirsDuRestaurant(String restaurantId) async => [];

  @override
  Future<void> basculerEnvie(
    String restaurantId, {
    required bool envie,
  }) async {}

  @override
  Future<List<String>> publier({
    required LieuRestaurant lieu,
    required List<Uint8List> photos,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    Map<String, int> notes = const {},
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> impressions = const [],
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
  Future<MomentModifiable> momentModifiable(String souvenirId) =>
      throw UnimplementedError();

  @override
  Future<List<String>> modifier(String souvenirId, MomentModifiable moment) =>
      throw UnimplementedError();

  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('racine (aucune route en dessous) : le bouton retour amène sur '
      "l'accueil au lieu de vider le Navigator", (tester) async {
    final authService = _FauxAuthService();

    // EcranConnexion posé directement comme unique route — exactement
    // ce que fait EcranDemarrage pour un utilisateur qui revient
    // (onboarding déjà vu, voir main.dart).
    await tester.pumpWidget(
      MaterialApp(
        home: EcranConnexion(
          authService: authService,
          abonnementService: _FauxAbonnementService(),
          souvenirService: _FauxSouvenirService(),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    // `pump` à durée fixe : EcranAccueil a un fond qui respire en
    // boucle, une animation qui ne s'arrête jamais et ferait échouer
    // `pumpAndSettle`.
    await tester.pump(const Duration(milliseconds: 1200));

    // Le Navigator n'est pas vidé : on atterrit sur l'accueil.
    expect(find.byType(EcranAccueil), findsOneWidget);
  });

  group('Continuer avec Apple', () {
    Future<_FauxAuthService> ouvrir(WidgetTester tester) async {
      final authService = _FauxAuthService();
      await tester.pumpWidget(
        MaterialApp(
          home: EcranConnexion(
            authService: authService,
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
          ),
        ),
      );
      return authService;
    }

    testWidgets('sur iPhone, le bouton lance la connexion Apple', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final authService = await ouvrir(tester);

      await tester.tap(find.text('Continuer avec Apple'));
      await tester.pump();

      expect(authService.appelsApple, 1);
      expect(find.text('Bientôt disponible.'), findsNothing);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets("sur Android, il n'est pas proposé", (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await ouvrir(tester);

      expect(find.text('Continuer avec Apple'), findsNothing);
      expect(find.text('Continuer avec Google'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
