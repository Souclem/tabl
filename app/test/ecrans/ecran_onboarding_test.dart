import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_accueil.dart';
import 'package:app/ecrans/ecran_onboarding.dart';

/// Faux [AuthService] : aucune méthode n'est appelée dans ces tests, les
/// écrans se contentent de le recevoir en paramètre.
class _FauxAuthService implements AuthService {
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

/// Faux [AbonnementService] : aucune méthode n'est appelée dans ces
/// tests, les écrans se contentent de le recevoir en paramètre.
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

/// Faux [EtatOnboarding] en mémoire, pour tester sans `shared_preferences`.
class _FauxEtatOnboarding implements EtatOnboarding {
  _FauxEtatOnboarding({bool dejaVu = false}) : _vu = dejaVu;

  bool _vu;

  @override
  Future<bool> aDejaVuOnboarding() async => _vu;

  @override
  Future<void> marquerOnboardingVu() async => _vu = true;
}

void main() {
  Future<void> swiperVersEtapeSuivante(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
  }

  group('EcranOnboarding — parcours complet (US1)', () {
    testWidgets(
      'affiche les 5 étapes dans l\'ordre puis amène sur EcranAccueil',
      (tester) async {
        final etatOnboarding = _FauxEtatOnboarding();

        await tester.pumpWidget(
          MaterialApp(
            home: EcranOnboarding(
              authService: _FauxAuthService(),
              abonnementService: _FauxAbonnementService(),
              souvenirService: _FauxSouvenirService(),
              etatOnboarding: etatOnboarding,
            ),
          ),
        );

        expect(find.text('Bienvenue'), findsOneWidget);

        await swiperVersEtapeSuivante(tester);
        expect(find.text('Profil'), findsOneWidget);

        await swiperVersEtapeSuivante(tester);
        expect(find.text('Feed'), findsOneWidget);

        await swiperVersEtapeSuivante(tester);
        expect(find.text('Réseau privé entre amis'), findsOneWidget);

        await swiperVersEtapeSuivante(tester);
        expect(find.text('Publication d\'un souvenir'), findsOneWidget);

        // Dernière étape : le bouton s'appelle "Commencer" mais déclenche
        // la même action que "Passer" (arrivée sur l'accueil).
        // `pump` à durée fixe plutôt que `pumpAndSettle` : EcranAccueil a un
        // fond qui respire en boucle, une animation qui ne s'arrête jamais.
        await tester.tap(find.text('Commencer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1200));

        expect(find.byType(EcranAccueil), findsOneWidget);
        expect(await etatOnboarding.aDejaVuOnboarding(), isTrue);
      },
    );

    testWidgets('retour depuis l\'accueil ramène à la première étape, pas à la '
        'dernière vue avant "Commencer"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EcranOnboarding(
            authService: _FauxAuthService(),
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
            etatOnboarding: _FauxEtatOnboarding(),
          ),
        ),
      );

      for (var i = 0; i < 4; i++) {
        await swiperVersEtapeSuivante(tester);
      }
      expect(find.text('Publication d\'un souvenir'), findsOneWidget);

      await tester.tap(find.text('Commencer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(EcranAccueil), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Bienvenue'), findsOneWidget);
      expect(find.text('Publication d\'un souvenir'), findsNothing);
    });
  });

  group('EcranOnboarding — pas de bouton "Passer"', () {
    testWidgets(
      'aucun bouton sur les étapes intermédiaires, seul "Commencer" existe '
      'sur la dernière',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: EcranOnboarding(
              authService: _FauxAuthService(),
              abonnementService: _FauxAbonnementService(),
              souvenirService: _FauxSouvenirService(),
              etatOnboarding: _FauxEtatOnboarding(),
            ),
          ),
        );

        expect(find.text('Passer'), findsNothing);
        expect(find.text('Commencer'), findsNothing);

        for (var i = 0; i < 3; i++) {
          await swiperVersEtapeSuivante(tester);
          expect(find.text('Passer'), findsNothing);
          expect(find.text('Commencer'), findsNothing);
        }

        await swiperVersEtapeSuivante(tester);
        expect(find.text('Publication d\'un souvenir'), findsOneWidget);
        expect(find.text('Commencer'), findsOneWidget);
      },
    );
  });
}
