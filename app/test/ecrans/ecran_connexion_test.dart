import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_accueil.dart';
import 'package:app/ecrans/ecran_connexion.dart';

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
    required Uint8List photo,
    required Emotion emotion,
    String? legende,
    List<String> amisTaguesIds = const [],
    String? boissonTexte,
    Uint8List? boissonPhoto,
    AudienceSouvenir audience = AudienceSouvenir.toutLeMonde,
    List<String> impressions = const [],
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
  Future<void> commenter(String souvenirId, String texte) =>
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
}
