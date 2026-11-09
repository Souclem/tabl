import 'dart:async';
import 'dart:io';

import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un essai d'envoi que le test pilote : la progression des photos, puis le
/// résultat.
class _Essai {
  _Essai(this.surProgression);

  final void Function(int envoyees, int total)? surProgression;
  final reponse = Completer<ResultatEnvoi>();
}

/// Le service d'envoi, simulé : rien ne part, le test décide de ce qui arrive.
class _FauxEnvois implements EnvoiPublications {
  final essais = <_Essai>[];
  final appelsGarder = <String>[];
  final appelsAttente = <String>[];

  /// `false` : le moment s'est publié avant l'annulation.
  bool annulationPossible = true;
  Completer<void>? fermetureLente;

  _Essai get essai => essais.last;

  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) {
    final e = _Essai(surProgression);
    essais.add(e);
    return e.reponse.future;
  }

  @override
  Future<bool> garderEnBrouillon(String brouillonId) async {
    appelsGarder.add(brouillonId);
    await fermetureLente?.future;
    if (annulationPossible && essais.isNotEmpty) {
      if (!essai.reponse.isCompleted) {
        essai.reponse.complete(const ResultatEnvoi(StatutEnvoi.annule));
      }
    }
    return annulationPossible;
  }

  @override
  Future<bool> mettreEnAttente(String brouillonId) async {
    appelsAttente.add(brouillonId);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FauxEnvois envois;
  ResultatCloche? resultat;
  var ferme = false;

  /// Une page d'accueil qui ouvre la cloche et garde ce qu'elle rend.
  Future<void> ouvrir(WidgetTester tester) async {
    resultat = null;
    ferme = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                resultat = await Navigator.of(context).push<ResultatCloche>(
                  MaterialPageRoute(
                    builder: (_) => EcranCloche(
                      brouillonId: 'b1',
                      envois: envois,
                      pauseFinale: const Duration(milliseconds: 200),
                    ),
                  ),
                );
                ferme = true;
              },
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Une image toutes les 16 ms, comme l'écran.
  Future<void> pomper(WidgetTester tester, int millisecondes) async {
    for (var t = 0; t < millisecondes; t += 16) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  int pourcentage(WidgetTester tester) {
    final cloche = tester.widget<TablClochePublication>(
      find.byType(TablClochePublication),
    );
    return int.parse(cloche.pourcentage);
  }

  Finder bouton(String libelle) => find.ancestor(
    of: find.text(libelle),
    matching: find.bySubtype<ButtonStyleButton>(),
  );

  Future<void> appuyer(WidgetTester tester, String libelle) async {
    await tester.tap(bouton(libelle));
    await tester.pump();
  }

  setUp(() => envois = _FauxEnvois());

  testWidgets('au départ : « À table », 0 %, Modifier et Annuler', (
    tester,
  ) async {
    await ouvrir(tester);

    expect(find.byType(EcranCloche), findsOneWidget);
    expect(find.text('À table'), findsOneWidget);
    expect(pourcentage(tester), 0);
    expect(bouton('Modifier'), findsOneWidget);
    expect(bouton('Annuler'), findsOneWidget);
    expect(find.text('Réessayer'), findsNothing);
    expect(envois.essais, hasLength(1));
  });

  testWidgets('le pourcentage suit les photos et reste sous 100 jusqu\'au '
      'serveur', (tester) async {
    await ouvrir(tester);
    envois.essai.surProgression!(0, 2);

    await pomper(tester, 1500);
    final avant = pourcentage(tester);
    expect(avant, inInclusiveRange(10, 30));

    envois.essai.surProgression!(1, 2);
    await pomper(tester, 1500);
    expect(pourcentage(tester), inInclusiveRange(avant, 85));

    envois.essai.surProgression!(2, 2);
    await pomper(tester, 4000);
    expect(pourcentage(tester), inInclusiveRange(90, 99));
    expect(find.text('Modifier'), findsNothing);
    expect(find.text('Annuler'), findsNothing);

    envois.essai.reponse.complete(const ResultatEnvoi(StatutEnvoi.publie));
    await pomper(tester, 800);
    expect(find.byType(EcranCloche), findsNothing);
    expect(ferme, isTrue);
    expect(resultat!.issue, IssueCloche.publie);
  });

  testWidgets('le réseau lent est dit, sans rien interrompre', (tester) async {
    await ouvrir(tester);
    envois.essai.surProgression!(0, 2);

    await pomper(tester, 1500);
    expect(find.text('Le réseau est lent…'), findsNothing);

    await pomper(tester, 1500);
    expect(find.text('Le réseau est lent…'), findsOneWidget);
    expect(bouton('Annuler'), findsOneWidget);
    expect(pourcentage(tester), lessThanOrEqualTo(30));
  });

  testWidgets('Annuler : l\'envoi est défait, la cloche se ferme', (
    tester,
  ) async {
    await ouvrir(tester);
    envois.essai.surProgression!(0, 2);
    await pomper(tester, 500);

    await appuyer(tester, 'Annuler');
    await pomper(tester, 100);

    expect(envois.appelsGarder, ['b1']);
    expect(ferme, isTrue);
    expect(resultat!.issue, IssueCloche.annule);
  });

  testWidgets('Modifier : retour à la finalisation', (tester) async {
    await ouvrir(tester);
    await pomper(tester, 500);

    await appuyer(tester, 'Modifier');
    await pomper(tester, 100);

    expect(resultat!.issue, IssueCloche.modifier);
  });

  testWidgets('pendant l\'annulation, les boutons sont grisés', (tester) async {
    envois.fermetureLente = Completer<void>();
    await ouvrir(tester);
    await pomper(tester, 500);

    await appuyer(tester, 'Annuler');
    await pomper(tester, 50);

    expect(
      tester.widget<ButtonStyleButton>(bouton('Annuler')).enabled,
      isFalse,
    );
    expect(
      tester.widget<ButtonStyleButton>(bouton('Modifier')).enabled,
      isFalse,
    );
    await tester.tap(bouton('Modifier'));
    expect(envois.appelsGarder, hasLength(1));

    envois.fermetureLente!.complete();
    await pomper(tester, 100);
    expect(resultat!.issue, IssueCloche.annule);
  });

  testWidgets('annulation trop tardive : la cloche le dit puis se ferme', (
    tester,
  ) async {
    envois.annulationPossible = false;
    await ouvrir(tester);
    await pomper(tester, 500);

    await appuyer(tester, 'Annuler');
    await pomper(tester, 100);

    expect(
      find.text(
        'Ce moment était déjà publié : l\'annulation est arrivée trop tard.',
      ),
      findsOneWidget,
    );
    expect(ferme, isFalse);
    await pomper(tester, 400);
    expect(resultat!.issue, IssueCloche.dejaPublie);
  });

  testWidgets('hors ligne : Garder en brouillon ou Envoyer dès que possible', (
    tester,
  ) async {
    await ouvrir(tester);
    await pomper(tester, 500);

    envois.essai.reponse.complete(
      const ResultatEnvoi(
        StatutEnvoi.echec,
        erreur: SocketException('Network is unreachable'),
      ),
    );
    await pomper(tester, 100);

    expect(find.textContaining('Pas de réseau'), findsOneWidget);
    expect(bouton('Garder en brouillon'), findsOneWidget);
    expect(bouton('Envoyer dès que possible'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);
    expect(find.text('Réessayer'), findsNothing);

    await appuyer(tester, 'Envoyer dès que possible');
    await pomper(tester, 100);

    expect(envois.appelsAttente, ['b1']);
    expect(resultat!.issue, IssueCloche.enAttente);
  });

  testWidgets('hors ligne : Garder en brouillon', (tester) async {
    await ouvrir(tester);
    envois.essai.reponse.complete(
      const ResultatEnvoi(
        StatutEnvoi.echec,
        erreur: SocketException('Network is unreachable'),
      ),
    );
    await pomper(tester, 100);

    await appuyer(tester, 'Garder en brouillon');
    await pomper(tester, 100);

    expect(envois.appelsGarder, ['b1']);
    expect(resultat!.issue, IssueCloche.brouillonGarde);
  });

  testWidgets('une photo en échec parmi d\'autres (ParallelWaitError) : '
      'toujours hors ligne', (tester) async {
    await ouvrir(tester);
    final Object erreur;
    try {
      await [
        Future<void>.error(const SocketException('Network is unreachable')),
        Future<void>.error(StateError('annulé')),
      ].wait;
      fail('aucune erreur');
    } catch (e) {
      erreur = e;
    }
    expect(erreur, isA<ParallelWaitError<dynamic, dynamic>>());

    envois.essai.reponse.complete(
      ResultatEnvoi(StatutEnvoi.echec, erreur: erreur),
    );
    await pomper(tester, 100);

    expect(find.textContaining('Pas de réseau'), findsOneWidget);
    expect(bouton('Envoyer dès que possible'), findsOneWidget);
  });

  testWidgets('échec : Réessayer repart de zéro puis publie', (tester) async {
    await ouvrir(tester);
    envois.essai.surProgression!(0, 2);
    await pomper(tester, 1500);
    envois.essai.reponse.complete(
      ResultatEnvoi(StatutEnvoi.echec, erreur: StateError('refusé')),
    );
    await pomper(tester, 100);

    expect(find.textContaining('n\'a pas abouti'), findsOneWidget);
    expect(find.textContaining('Pas de réseau'), findsNothing);
    expect(bouton('Garder en brouillon'), findsOneWidget);
    expect(bouton('Réessayer'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);

    await appuyer(tester, 'Réessayer');
    await tester.pump();
    expect(envois.essais, hasLength(2));
    expect(pourcentage(tester), 0);
    expect(find.textContaining('n\'a pas abouti'), findsNothing);
    expect(bouton('Annuler'), findsOneWidget);

    envois.essai.surProgression!(2, 2);
    envois.essai.reponse.complete(const ResultatEnvoi(StatutEnvoi.publie));
    await pomper(tester, 5000);

    expect(ferme, isTrue);
    expect(resultat!.issue, IssueCloche.publie);
  });

  testWidgets('moment déjà publié : la cloche ne prétend pas avoir appliqué '
      'les modifications', (tester) async {
    await ouvrir(tester);
    envois.essai.surProgression!(2, 2);
    envois.essai.reponse.complete(
      const ResultatEnvoi(StatutEnvoi.publie, dejaPublie: true),
    );
    await pomper(tester, 100);

    expect(
      find.text(
        'Ce moment était déjà publié : vos dernières modifications n\'ont '
        'pas été appliquées.',
      ),
      findsOneWidget,
    );
    expect(ferme, isFalse);
    await pomper(tester, 500);
    expect(ferme, isTrue);
    expect(resultat!.issue, IssueCloche.dejaPublie);
  });

  testWidgets('publié, mais une Table n\'a pas suivi : pas de succès muet', (
    tester,
  ) async {
    await ouvrir(tester);
    envois.essai.surProgression!(2, 2);
    envois.essai.reponse.complete(
      const ResultatEnvoi(StatutEnvoi.publie, tablesEnEchec: ['t2']),
    );
    await pomper(tester, 100);

    expect(
      find.text(
        'Publié, mais l\'ajout à l\'une de vos Tables n\'a pas abouti.',
      ),
      findsOneWidget,
    );
    await pomper(tester, 500);
    expect(resultat!.issue, IssueCloche.publie);
    expect(resultat!.tablesEnEchec, ['t2']);
  });

  testWidgets('brouillon incomplet ou disparu : la cloche se referme', (
    tester,
  ) async {
    await ouvrir(tester);
    envois.essai.reponse.complete(const ResultatEnvoi(StatutEnvoi.incomplet));
    await pomper(tester, 100);

    expect(ferme, isTrue);
    expect(resultat!.issue, IssueCloche.modifier);
  });

  testWidgets('le retour du système ne ferme pas la cloche', (tester) async {
    await ouvrir(tester);

    await tester.binding.handlePopRoute();
    await pomper(tester, 100);

    expect(find.byType(EcranCloche), findsOneWidget);
    expect(ferme, isFalse);
  });

  testWidgets('l\'écran est sombre quel que soit le thème', (tester) async {
    await ouvrir(tester);

    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(EcranCloche),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, TablTokens.fond);
  });
}
