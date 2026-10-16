import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_connexion.dart';
import 'package:app/ecrans/ecran_onboarding.dart';
import 'package:app/ecrans/ecran_principal.dart';
import 'package:app/main.dart';

class _FauxAuthService implements AuthService {
  _FauxAuthService({this._utilisateurConnecte});

  final Utilisateur? _utilisateurConnecte;

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
  Future<Utilisateur?> utilisateurConnecte() async => _utilisateurConnecte;

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

  // Invoquée incidemment dès que EcranPrincipal (donc EcranProfil) est
  // monté — pas ce que ces tests vérifient, donc une vraie valeur plutôt
  // qu'un throw.
  @override
  Future<int> nombreDemandesEnAttente() async => 0;

  @override
  Future<List<ProfilPublic>> mesAmis() async => [];
}

class _FauxSouvenirService implements SouvenirService {
  @override
  Future<List<String>> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    bool partagerAvecCercle = true,
    List<String> impressions = const [],
    List<String> tableIds = const [],
  }) => throw UnimplementedError();

  @override
  Future<String> enregistrerBrouillon({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
  }) => throw UnimplementedError();

  @override
  Future<({bool partagerAvecCercle, List<String> tableIds})> partageActuel(
    String souvenirId,
  ) => throw UnimplementedError();

  @override
  Future<List<String>> modifierPartage(
    String souvenirId, {
    required bool partagerAvecCercle,
    required List<String> tableIds,
  }) => throw UnimplementedError();


  // Invoquée incidemment dès que EcranPrincipal (donc EcranFeed) est
  // monté — pas ce que ces tests vérifient, donc une vraie valeur plutôt
  // qu'un throw.
  @override
  Future<List<SouvenirFeed>> feed() async => [];
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

class _FauxEtatOnboarding implements EtatOnboarding {
  _FauxEtatOnboarding({required bool dejaVu}) : _vu = dejaVu;

  bool _vu;

  @override
  Future<bool> aDejaVuOnboarding() async => _vu;

  @override
  Future<void> marquerOnboardingVu() async => _vu = true;
}

void main() {
  testWidgets(
    'EcranDemarrage affiche EcranOnboarding quand le parcours n\'a jamais été vu',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EcranDemarrage(
            authService: _FauxAuthService(),
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
            etatOnboarding: _FauxEtatOnboarding(dejaVu: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EcranOnboarding), findsOneWidget);
      expect(find.byType(EcranConnexion), findsNothing);
    },
  );

  testWidgets(
    'EcranDemarrage affiche EcranConnexion quand le parcours a déjà été vu',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EcranDemarrage(
            authService: _FauxAuthService(),
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
            etatOnboarding: _FauxEtatOnboarding(dejaVu: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EcranConnexion), findsOneWidget);
      expect(find.byType(EcranOnboarding), findsNothing);
    },
  );

  testWidgets(
    'EcranDemarrage affiche EcranPrincipal quand une session valide existe '
    'déjà',
    (tester) async {
      const utilisateur = Utilisateur(
        id: '1',
        email: 'camille@exemple.com',
        pseudo: 'camille',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranDemarrage(
            authService: _FauxAuthService(utilisateurConnecte: utilisateur),
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
            etatOnboarding: _FauxEtatOnboarding(dejaVu: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EcranPrincipal), findsOneWidget);
      expect(find.byType(EcranConnexion), findsNothing);
    },
  );
}
