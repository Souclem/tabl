import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'package:app/ecrans/feuille_commentaires.dart';

/// Faux [SouvenirService] à état contrôlable : écrire, supprimer ou
/// aimer un commentaire change vraiment ce que [commentaires] renvoie,
/// comme le ferait le vrai service.
class _FauxSouvenirService implements SouvenirService {
  @override
  Future<void> retirerMonNomDuLieu(String restaurantId) async {}

  _FauxSouvenirService({
    List<Commentaire> commentaires = const [],
    this.erreurChargement = false,
    this.erreurEnvoi = false,
    this.erreurJaime = false,
  }) : _commentaires = List.of(commentaires);

  List<Commentaire> _commentaires;
  final bool erreurChargement;
  final bool erreurEnvoi;
  final bool erreurJaime;

  final List<({String texte, String? parentId})> envois = [];
  final List<({String id, bool aimer})> jaimes = [];
  final List<String> suppressions = [];

  @override
  Future<List<Commentaire>> commentaires(String souvenirId) async {
    if (erreurChargement) throw Exception('erreur réseau');
    return List.of(_commentaires);
  }

  @override
  Future<void> commenter(
    String souvenirId,
    String texte, {
    String? parentId,
  }) async {
    if (erreurEnvoi) throw Exception('erreur réseau');
    envois.add((texte: texte, parentId: parentId));
    _commentaires = [
      ..._commentaires,
      Commentaire(
        id: 'nouveau-${_commentaires.length}',
        texte: texte,
        creeLe: DateTime(2026, 8, 21),
        auteurPseudo: 'moi',
        estLeMien: true,
        parentId: parentId,
      ),
    ];
  }

  @override
  Future<void> basculerJaimeCommentaire(
    String commentaireId, {
    required bool aimer,
  }) async {
    if (erreurJaime) throw Exception('erreur réseau');
    jaimes.add((id: commentaireId, aimer: aimer));
  }

  @override
  Future<void> supprimerCommentaire(String commentaireId) async {
    suppressions.add(commentaireId);
    _commentaires = [
      for (final c in _commentaires)
        if (c.id != commentaireId && c.parentId != commentaireId) c,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Commentaire _commentaire(
  String id, {
  String pseudo = 'camille',
  String? texte,
  String? parentId,
  bool estLeMien = false,
  int jour = 20,
}) => Commentaire(
  id: id,
  texte: texte ?? 'Texte de $id',
  creeLe: DateTime(2026, 8, jour),
  auteurPseudo: pseudo,
  auteurId: '$pseudo-id',
  estLeMien: estLeMien,
  parentId: parentId,
);

final _souvenir = SouvenirFeed(
  id: 's1',
  photoUrl: null,
  legende: null,
  restaurantNom: 'Le Comptoir',
  ville: 'Paris',
  moment: 'soir',
  dateVisite: DateTime(2026, 8, 20),
  auteurPseudo: 'martin',
  nombreReactions: 0,
  jaiReagi: false,
  nombreCommentaires: 0,
);

/// Ouvre la feuille par-dessus un écran, comme le Feed.
Future<List<int>> _ouvrir(
  WidgetTester tester,
  _FauxSouvenirService service,
) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nombres = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ouvrirFeuilleCommentaires(
              context,
              souvenirService: service,
              souvenir: _souvenir,
              onNombre: nombres.add,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return nombres;
}

Future<void> _envoyer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Publier le commentaire'));
  await tester.pumpAndSettle();
}

String _champ(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!.text;

void main() {
  testWidgets('aucun commentaire : on invite à commencer', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService());

    expect(find.byType(TablFeuilleCommentaires), findsOneWidget);
    expect(find.text('Aucun commentaire pour l\'instant.'), findsOneWidget);
  });

  testWidgets('affiche les commentaires ; « Supprimer » sur les siens seuls', (
    tester,
  ) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService(
        commentaires: [
          _commentaire('c1', texte: 'Superbe endroit !'),
          _commentaire('c2', pseudo: 'moi', estLeMien: true, jour: 21),
        ],
      ),
    );

    expect(find.text('2 commentaires'), findsOneWidget);
    expect(find.textContaining('camille'), findsOneWidget);
    expect(find.text('Superbe endroit !'), findsOneWidget);
    expect(find.text('Supprimer'), findsOneWidget);
  });

  testWidgets("écrire un commentaire l'ajoute et vide le champ", (
    tester,
  ) async {
    final service = _FauxSouvenirService();
    final nombres = await _ouvrir(tester, service);

    await tester.enterText(find.byType(TextField), 'Envie d\'y retourner');
    await _envoyer(tester);

    expect(service.envois, [(texte: 'Envie d\'y retourner', parentId: null)]);
    expect(find.text('Envie d\'y retourner'), findsOneWidget);
    expect(_champ(tester), '');
    expect(nombres.last, 1);
  });

  testWidgets('répondre : la réponse va dans le fil, qui se déplie', (
    tester,
  ) async {
    final service = _FauxSouvenirService(commentaires: [_commentaire('c1')]);
    await _ouvrir(tester, service);

    await tester.tap(find.text('Répondre'));
    await tester.pumpAndSettle();
    expect(find.text('En réponse à camille'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Je confirme');
    await _envoyer(tester);

    expect(service.envois, [(texte: 'Je confirme', parentId: 'c1')]);
    expect(find.text('Je confirme'), findsOneWidget);
    expect(find.text('En réponse à camille'), findsNothing);
    expect(find.text('Masquer les réponses'), findsOneWidget);
  });

  testWidgets('répondre à une réponse : même fil, en la nommant', (
    tester,
  ) async {
    final service = _FauxSouvenirService(
      commentaires: [
        _commentaire('c1'),
        _commentaire('r1', pseudo: 'louise', parentId: 'c1', jour: 21),
      ],
    );
    await _ouvrir(tester, service);

    await tester.tap(find.text('Voir la réponse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Répondre').last);
    await tester.pumpAndSettle();

    expect(find.text('En réponse à louise'), findsOneWidget);
    expect(_champ(tester), '@louise ');

    await tester.enterText(find.byType(TextField), '@louise Oui !');
    await _envoyer(tester);

    // Un seul niveau : rattachée au commentaire d'origine.
    expect(service.envois.single.parentId, 'c1');
  });

  testWidgets('les réponses sont repliées, puis se déplient', (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService(
        commentaires: [
          _commentaire('c1'),
          _commentaire('r1', texte: 'Première', parentId: 'c1', jour: 21),
          _commentaire('r2', texte: 'Deuxième', parentId: 'c1', jour: 22),
        ],
      ),
    );

    expect(find.text('Première'), findsNothing);
    await tester.tap(find.text('Voir les 2 réponses'));
    await tester.pumpAndSettle();
    expect(find.text('Première'), findsOneWidget);
    expect(find.text('Deuxième'), findsOneWidget);

    await tester.tap(find.text('Masquer les réponses'));
    await tester.pumpAndSettle();
    expect(find.text('Première'), findsNothing);
  });

  testWidgets("aimer un commentaire se voit tout de suite, et s'annule", (
    tester,
  ) async {
    final service = _FauxSouvenirService(commentaires: [_commentaire('c1')]);
    await _ouvrir(tester, service);

    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pumpAndSettle();
    expect(find.text('1 j\'aime'), findsOneWidget);

    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pumpAndSettle();
    expect(find.text('1 j\'aime'), findsNothing);
    expect(service.jaimes, [(id: 'c1', aimer: true), (id: 'c1', aimer: false)]);
  });

  testWidgets("un j'aime qui échoue revient en arrière", (tester) async {
    await _ouvrir(
      tester,
      _FauxSouvenirService(
        commentaires: [_commentaire('c1')],
        erreurJaime: true,
      ),
    );

    await tester.tap(find.byType(TablBoutonReaction));
    await tester.pumpAndSettle();

    expect(find.text('1 j\'aime'), findsNothing);
    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets('supprimer le sien, sans réponses : tout de suite', (
    tester,
  ) async {
    final service = _FauxSouvenirService(
      commentaires: [
        _commentaire('c1', pseudo: 'moi', texte: 'À moi', estLeMien: true),
      ],
    );
    await _ouvrir(tester, service);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('À moi'), findsNothing);
    expect(service.suppressions, ['c1']);
  });

  testWidgets('supprimer le sien, avec réponses : après confirmation', (
    tester,
  ) async {
    final service = _FauxSouvenirService(
      commentaires: [
        _commentaire('c1', pseudo: 'moi', texte: 'À moi', estLeMien: true),
        _commentaire('r1', parentId: 'c1', jour: 21),
      ],
    );
    await _ouvrir(tester, service);

    await tester.tap(find.text('Supprimer'));
    await tester.pumpAndSettle();
    expect(find.text('Ses réponses partiront avec lui.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Supprimer'));
    await tester.pumpAndSettle();

    expect(find.text('À moi'), findsNothing);
    expect(find.text('Voir la réponse'), findsNothing);
    expect(service.suppressions, ['c1']);
  });

  testWidgets('erreur de chargement → message générique', (tester) async {
    await _ouvrir(tester, _FauxSouvenirService(erreurChargement: true));

    expect(find.text(messageErreurGenerique), findsOneWidget);
  });

  testWidgets("erreur d'envoi → message générique, texte gardé", (
    tester,
  ) async {
    final service = _FauxSouvenirService(erreurEnvoi: true);
    await _ouvrir(tester, service);

    await tester.enterText(find.byType(TextField), 'Ça va planter');
    await _envoyer(tester);

    expect(find.text(messageErreurGenerique), findsOneWidget);
    expect(_champ(tester), 'Ça va planter');
    expect(service.envois, isEmpty);
  });
}
