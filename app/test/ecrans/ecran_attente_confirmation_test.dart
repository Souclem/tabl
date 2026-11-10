import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_attente_confirmation.dart';
import 'package:app/ecrans/ecran_principal.dart';

/// Faux [AuthService] : `connexion` refuse les N premiers appels (e-mail
/// pas encore confirmé), puis réussit — simule la confirmation qui arrive
/// pendant l'attente.
class _FauxAuthService implements AuthService {
  _FauxAuthService({required this.echecsAvantSucces});

  final int echecsAvantSucces;
  int _appels = 0;

  @override
  Future<Utilisateur> connexion({
    required String email,
    required String motDePasse,
  }) async {
    _appels++;
    if (_appels <= echecsAvantSucces) {
      throw const ErreurAuth("Confirme d'abord ton adresse e-mail.");
    }
    return const Utilisateur(
      id: '1',
      email: 'camille@exemple.com',
      pseudo: 'camille',
    );
  }

  @override
  Future<ResultatInscription> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  }) => throw UnimplementedError();

  @override
  Future<Utilisateur?> utilisateurConnecte() => throw UnimplementedError();

  @override
  Future<ResultatConnexionOAuth?> connexionApple() =>
      throw UnimplementedError();

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

  // Invoquée incidemment dès que EcranPrincipal (donc EcranProfil) est
  // monté — pas ce que ces tests vérifient, donc une vraie valeur plutôt
  // qu'un throw.
  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<List<ProfilPublic>> mesRelations() async => [];
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

  // Invoquée incidemment dès que EcranPrincipal (donc EcranFeed) est
  // monté — pas ce que ces tests vérifient, donc une vraie valeur plutôt
  // qu'un throw.
  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) async => [];
  @override
  Future<List<SouvenirFeed>> feed() async => [];
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
  testWidgets(
    'passe automatiquement sur EcranPrincipal dès que la connexion réussit',
    (tester) async {
      final authService = _FauxAuthService(echecsAvantSucces: 2);

      await tester.pumpWidget(
        MaterialApp(
          home: EcranAttenteConfirmation(
            authService: authService,
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
            email: 'camille@exemple.com',
            motDePasse: 'motdepasse123',
          ),
        ),
      );

      expect(find.text('Vérifie ta boîte mail'), findsOneWidget);
      expect(find.byType(EcranPrincipal), findsNothing);

      // Deux tics du minuteur (15 s chacun) : toujours pas confirmé.
      await tester.pump(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      expect(find.byType(EcranPrincipal), findsNothing);

      // Troisième tic : la fausse connexion réussit.
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();

      expect(find.byType(EcranPrincipal), findsOneWidget);
    },
  );

  testWidgets('le bouton "Vérifier maintenant" déclenche une vérification '
      'immédiate', (tester) async {
    final authService = _FauxAuthService(echecsAvantSucces: 1);

    await tester.pumpWidget(
      MaterialApp(
        home: EcranAttenteConfirmation(
          authService: authService,
          abonnementService: _FauxAbonnementService(),
          souvenirService: _FauxSouvenirService(),
          email: 'camille@exemple.com',
          motDePasse: 'motdepasse123',
        ),
      ),
    );

    // Premier appel (échec) déclenché manuellement, sans attendre le
    // minuteur.
    await tester.tap(find.text('Déjà confirmé ? Vérifier maintenant'));
    await tester.pump();
    expect(find.byType(EcranPrincipal), findsNothing);

    // Deuxième appel manuel : réussit.
    await tester.tap(find.text('Déjà confirmé ? Vérifier maintenant'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(EcranPrincipal), findsOneWidget);
  });

  testWidgets("vérifie au retour dans l'app, sans attendre le minuteur", (
    tester,
  ) async {
    final authService = _FauxAuthService(echecsAvantSucces: 0);

    await tester.pumpWidget(
      MaterialApp(
        home: EcranAttenteConfirmation(
          authService: authService,
          abonnementService: _FauxAbonnementService(),
          souvenirService: _FauxSouvenirService(),
          email: 'camille@exemple.com',
          motDePasse: 'motdepasse123',
        ),
      ),
    );
    expect(find.byType(EcranPrincipal), findsNothing);

    // Parti dans sa boîte mail, puis revenu.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byType(EcranPrincipal), findsOneWidget);
  });
}
