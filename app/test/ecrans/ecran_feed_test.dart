import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_cercle.dart';
import 'package:app/ecrans/ecran_commentaires.dart';
import 'package:app/ecrans/ecran_feed.dart';

class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService({
    this.souvenirs = const [],
    this.erreur = false,
    this.erreurReaction = false,
  });

  final List<SouvenirFeed> souvenirs;
  final bool erreur;
  final bool erreurReaction;

  final List<(String, bool)> appelsReaction = [];

  @override
  Future<List<SouvenirFeed>> feed() async {
    if (erreur) throw Exception('erreur réseau');
    return souvenirs;
  }

  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) async {
    if (erreurReaction) throw Exception('erreur réseau');
    appelsReaction.add((souvenirId, reagir));
  }

  @override
  Future<void> publier({
    required String nomRestaurant,
    required String ville,
    required Uint8List photo,
    String? legende,
  }) => throw UnimplementedError();

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) async => [];

  @override
  Future<void> commenter(String souvenirId, String texte) =>
      throw UnimplementedError();

  @override
  Future<void> supprimerCommentaire(String commentaireId) =>
      throw UnimplementedError();
}

/// Faux [AbonnementService] : aucune méthode n'est appelée tant qu'on ne
/// tape pas sur "Ajouter mes premiers amis".
class _FauxAbonnementService implements AbonnementService {
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

SouvenirFeed _souvenirDeTest({
  String id = '1',
  int nombreReactions = 0,
  bool jaiReagi = false,
  int nombreCommentaires = 0,
}) {
  return SouvenirFeed(
    id: id,
    photoUrl: null,
    legende: 'Inoubliable.',
    restaurantNom: 'Le Comptoir',
    ville: 'Paris',
    moment: 'soir',
    dateVisite: DateTime(2026, 8, 20),
    auteurPseudo: 'martin',
    nombreReactions: nombreReactions,
    jaiReagi: jaiReagi,
    nombreCommentaires: nombreCommentaires,
  );
}

void main() {
  testWidgets('feed vide : état vide avec bouton "Ajouter mes premiers amis"', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Votre table est encore vide.'), findsOneWidget);
    expect(find.text('Ajouter mes premiers amis'), findsOneWidget);
  });

  testWidgets(
    'taper sur "Ajouter mes premiers amis" ouvre l\'écran Cercle',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: _FauxSouvenirService(),
            abonnementService: _FauxAbonnementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ajouter mes premiers amis'));
      await tester.pumpAndSettle();

      expect(find.byType(EcranCercle), findsOneWidget);
    },
  );

  testWidgets('feed rempli : affiche le contenu de chaque souvenir', (
    tester,
  ) async {
    final souvenirs = [_souvenirDeTest(nombreReactions: 3, nombreCommentaires: 2)];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LE COMPTOIR'), findsOneWidget);
    expect(find.text('"Inoubliable."'), findsOneWidget);
    expect(find.textContaining('Paris'), findsOneWidget);
    expect(find.textContaining('Soir'), findsOneWidget);
    expect(find.textContaining('martin'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Votre table est encore vide.'), findsNothing);
  });

  testWidgets('erreur de chargement → message générique affiché', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(erreur: true),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets('réagir met à jour le compteur et appelle le service', (
    tester,
  ) async {
    final service = _FauxSouvenirService(
      souvenirs: [_souvenirDeTest(nombreReactions: 0, jaiReagi: false)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('1'), findsOneWidget);
    expect(service.appelsReaction, [('1', true)]);
  });

  testWidgets('retirer sa réaction décrémente le compteur', (tester) async {
    final service = _FauxSouvenirService(
      souvenirs: [_souvenirDeTest(nombreReactions: 1, jaiReagi: true)],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: service,
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('1'), findsNothing);
    expect(service.appelsReaction, [('1', false)]);
  });

  testWidgets(
    'échec réseau en réagissant : revient à l\'état précédent + message',
    (tester) async {
      final service = _FauxSouvenirService(
        souvenirs: [_souvenirDeTest(nombreReactions: 0, jaiReagi: false)],
        erreurReaction: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: EcranFeed(
            souvenirService: service,
            abonnementService: _FauxAbonnementService(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TablBoutonReaction));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('1'), findsNothing);
      expect(find.text(messageErreurGenerique), findsOneWidget);
    },
  );

  testWidgets('taper sur l\'icône commentaire ouvre EcranCommentaires', (
    tester,
  ) async {
    final souvenirs = [_souvenirDeTest()];

    await tester.pumpWidget(
      MaterialApp(
        home: EcranFeed(
          souvenirService: _FauxSouvenirService(souvenirs: souvenirs),
          abonnementService: _FauxAbonnementService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(EcranCommentaires), findsOneWidget);
  });
}
