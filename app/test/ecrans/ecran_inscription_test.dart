import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

import 'package:app/ecrans/ecran_attente_confirmation.dart';
import 'package:app/ecrans/ecran_inscription.dart';
import 'package:app/ecrans/ecran_principal.dart';

class _FauxAuthService implements AuthService {
  _FauxAuthService(this.resultat);

  final ResultatInscription resultat;

  @override
  Future<Utilisateur> connexion({
    required String email,
    required String motDePasse,
  }) => throw const ErreurAuth("Confirme d'abord ton adresse e-mail.");

  @override
  Future<ResultatInscription> inscription({
    required String email,
    required String motDePasse,
    required String pseudo,
  }) async => resultat;

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

void main() {
  Future<void> remplirEtSoumettre(WidgetTester tester) async {
    final champs = find.byType(TextField);
    await tester.enterText(champs.at(0), 'camille');
    await tester.enterText(champs.at(1), 'camille@exemple.com');
    await tester.enterText(champs.at(2), 'motdepasse123');
    await tester.enterText(champs.at(3), 'motdepasse123');
    await tester.pump();
    await tester.ensureVisible(find.text('Créer mon compte'));
    await tester.tap(find.text('Créer mon compte'));
    await tester.pump();
    // `pump` à durée fixe plutôt que `pumpAndSettle` : la destination
    // (EcranAttenteConfirmation) a un minuteur périodique, une animation
    // qui ne s'arrête jamais et ferait échouer `pumpAndSettle`.
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets(
    'InscriptionEnAttenteConfirmation amène sur EcranAttenteConfirmation',
    (tester) async {
      final authService = _FauxAuthService(
        const InscriptionEnAttenteConfirmation(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranInscription(
            authService: authService,
            abonnementService: _FauxAbonnementService(),
            souvenirService: _FauxSouvenirService(),
          ),
        ),
      );

      await remplirEtSoumettre(tester);

      expect(find.byType(EcranAttenteConfirmation), findsOneWidget);
    },
  );

  testWidgets('InscriptionReussie amène directement sur EcranPrincipal', (
    tester,
  ) async {
    final authService = _FauxAuthService(
      const InscriptionReussie(
        Utilisateur(id: '1', email: 'camille@exemple.com', pseudo: 'camille'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranInscription(
          authService: authService,
          abonnementService: _FauxAbonnementService(),
          souvenirService: _FauxSouvenirService(),
        ),
      ),
    );

    await remplirEtSoumettre(tester);

    expect(find.byType(EcranPrincipal), findsOneWidget);
  });
}
