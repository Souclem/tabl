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
}

/// Faux [AbonnementService] : aucune méthode n'est appelée dans ces
/// tests, les écrans se contentent de le recevoir en paramètre.
class _FauxAbonnementService implements AbonnementService {
  @override
  Future<List<ProfilPublic>> rechercher(String requete) =>
      throw UnimplementedError();

  @override
  Future<void> suivre(String suiviId) => throw UnimplementedError();

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
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    String? legende,
  }) => throw UnimplementedError();

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
