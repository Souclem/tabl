import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/ecran_commentaires.dart';

/// Faux [SouvenirService] à état contrôlable : ajouter/supprimer un
/// commentaire modifie réellement la liste renvoyée par [commentaires],
/// comme le ferait le vrai service.
class _FauxSouvenirService implements SouvenirService {
  _FauxSouvenirService({
    List<Commentaire> commentaires = const [],
    this.erreurChargement = false,
    this.erreurEnvoi = false,
  }) : _commentaires = List.of(commentaires);

  List<Commentaire> _commentaires;
  final bool erreurChargement;
  final bool erreurEnvoi;

  final List<String> textesEnvoyes = [];

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) async {
    if (erreurChargement) throw Exception('erreur réseau');
    return List.of(_commentaires);
  }

  @override
  Future<void> commenter(String souvenirId, String texte) async {
    if (erreurEnvoi) throw Exception('erreur réseau');
    textesEnvoyes.add(texte);
    _commentaires = [
      ..._commentaires,
      Commentaire(
        id: 'nouveau-${_commentaires.length}',
        texte: texte,
        creeLe: DateTime.now(),
        auteurPseudo: 'moi',
        estLeMien: true,
      ),
    ];
  }

  @override
  Future<void> supprimerCommentaire(String commentaireId) async {
    _commentaires = _commentaires.where((c) => c.id != commentaireId).toList();
  }

  @override
  Future<void> basculerReaction(String souvenirId, {required bool reagir}) =>
      throw UnimplementedError();

  @override
  Future<List<SouvenirFeed>> souvenirsDe(String auteurId) =>
      throw UnimplementedError();
  @override
  Future<List<SouvenirFeed>> feed() => throw UnimplementedError();

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

}

void main() {
  testWidgets('liste vide : message dédié', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(
          souvenirService: _FauxSouvenirService(),
          souvenirId: 's1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun commentaire pour l\'instant.'), findsOneWidget);
  });

  testWidgets('affiche les commentaires existants', (tester) async {
    final service = _FauxSouvenirService(
      commentaires: [
        Commentaire(
          id: 'c1',
          texte: 'Superbe endroit !',
          creeLe: DateTime(2026, 8, 20),
          auteurPseudo: 'camille',
          estLeMien: false,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(souvenirService: service, souvenirId: 's1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('camille'), findsOneWidget);
    expect(find.text('Superbe endroit !'), findsOneWidget);
    // Pas le mien : pas d'icône de suppression.
    expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
  });

  testWidgets('envoyer un commentaire l\'ajoute à la liste et vide le champ', (
    tester,
  ) async {
    final service = _FauxSouvenirService();

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(souvenirService: service, souvenirId: 's1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Envie d\'y retourner');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(service.textesEnvoyes, ['Envie d\'y retourner']);
    expect(find.text('Envie d\'y retourner'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  testWidgets('supprimer son propre commentaire le retire de la liste', (
    tester,
  ) async {
    final service = _FauxSouvenirService(
      commentaires: [
        Commentaire(
          id: 'c1',
          texte: 'À moi celui-ci',
          creeLe: DateTime(2026, 8, 20),
          auteurPseudo: 'moi',
          estLeMien: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(souvenirService: service, souvenirId: 's1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('À moi celui-ci'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(find.text('À moi celui-ci'), findsNothing);
  });

  testWidgets('erreur de chargement → message générique', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(
          souvenirService: _FauxSouvenirService(erreurChargement: true),
          souvenirId: 's1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets('erreur d\'envoi → message générique, champ conservé', (
    tester,
  ) async {
    final service = _FauxSouvenirService(erreurEnvoi: true);

    await tester.pumpWidget(
      MaterialApp(
        home: EcranCommentaires(souvenirService: service, souvenirId: 's1'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ça va planter');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(find.text(messageErreurGenerique), findsOneWidget);
    expect(service.textesEnvoyes, isEmpty);
  });
}
