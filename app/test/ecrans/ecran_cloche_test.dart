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
  final appelsDetacher = <String>[];
  final appelsEtat = <String>[];

  /// Ce que l'envoi relit au retour de l'arrière-plan.
  EtatReel etat = EtatReel.enCours;

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
  Future<void> detacher(String brouillonId) async {
    appelsDetacher.add(brouillonId);
  }

  @override
  Future<EtatReel> etatReel(String brouillonId) async {
    appelsEtat.add(brouillonId);
    return etat;
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
  Future<void> ouvrir(
    WidgetTester tester, {
    Duration delaiSuspendu = delaiEnvoiSuspendu,
  }) async {
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
                      delaiSuspendu: delaiSuspendu,
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

  /// La publication est en route : aucun bouton, rien à toucher.
  void rienAToucher() => expect(
    find.descendant(
      of: find.byType(EcranCloche),
      matching: find.bySubtype<ButtonStyleButton>(),
    ),
    findsNothing,
  );

  Future<void> horsLigne(WidgetTester tester) async {
    envois.essai.reponse.complete(
      const ResultatEnvoi(
        StatutEnvoi.echec,
        erreur: SocketException('Network is unreachable'),
      ),
    );
    await pomper(tester, 100);
  }

  setUp(() => envois = _FauxEnvois());

  testWidgets('au départ : « À table », 0 %, ni Modifier ni Annuler', (
    tester,
  ) async {
    await ouvrir(tester);

    expect(find.byType(EcranCloche), findsOneWidget);
    expect(find.text('À table'), findsOneWidget);
    expect(pourcentage(tester), 0);
    expect(find.text('Modifier'), findsNothing);
    rienAToucher();
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
    rienAToucher();

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
    rienAToucher();
    expect(pourcentage(tester), lessThanOrEqualTo(30));
  });

  testWidgets('pendant « Garder en brouillon », les boutons sont grisés', (
    tester,
  ) async {
    envois.fermetureLente = Completer<void>();
    await ouvrir(tester);
    await horsLigne(tester);

    await appuyer(tester, 'Garder en brouillon');
    await pomper(tester, 50);

    expect(
      tester.widget<ButtonStyleButton>(bouton('Garder en brouillon')).enabled,
      isFalse,
    );
    expect(
      tester
          .widget<ButtonStyleButton>(bouton('Envoyer dès que possible'))
          .enabled,
      isFalse,
    );
    await tester.tap(bouton('Garder en brouillon'));
    expect(envois.appelsGarder, hasLength(1));

    envois.fermetureLente!.complete();
    await pomper(tester, 100);
    expect(resultat!.issue, IssueCloche.brouillonGarde);
  });

  testWidgets('gardé trop tard : déjà publié, la cloche le dit puis se ferme', (
    tester,
  ) async {
    envois.annulationPossible = false;
    await ouvrir(tester);
    await horsLigne(tester);

    await appuyer(tester, 'Garder en brouillon');
    await pomper(tester, 100);

    expect(
      find.text(
        'Ce moment était déjà publié : il n\'a pas pu rester en brouillon.',
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

    await appuyer(tester, 'Réessayer');
    await tester.pump();
    expect(envois.essais, hasLength(2));
    expect(pourcentage(tester), 0);
    expect(find.textContaining('n\'a pas abouti'), findsNothing);
    rienAToucher();

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

  group('envoi suspendu (délai maximal)', () {
    const delai = Duration(seconds: 5);

    testWidgets('le délai par défaut est de 45 s', (tester) async {
      expect(delaiEnvoiSuspendu, const Duration(seconds: 45));
    });

    testWidgets('sans progression : échec, boutons prévus, brouillon gardé', (
      tester,
    ) async {
      await ouvrir(tester, delaiSuspendu: delai);
      envois.essai.surProgression!(0, 2);

      await pomper(tester, 4500);
      rienAToucher();
      expect(find.textContaining('n\'a pas abouti'), findsNothing);

      await pomper(tester, 1500);
      expect(find.textContaining('n\'a pas abouti'), findsOneWidget);
      expect(bouton('Garder en brouillon'), findsOneWidget);
      expect(bouton('Réessayer'), findsOneWidget);
      expect(envois.appelsDetacher, ['b1']);
      expect(ferme, isFalse);
    });

    testWidgets('une photo qui part relance le compte', (tester) async {
      await ouvrir(tester, delaiSuspendu: delai);
      envois.essai.surProgression!(0, 3);
      await pomper(tester, 4000);

      envois.essai.surProgression!(1, 3);
      await pomper(tester, 4000);
      envois.essai.surProgression!(2, 3);
      await pomper(tester, 4000);

      expect(envois.appelsDetacher, isEmpty);
      rienAToucher();

      await pomper(tester, 2000);
      expect(envois.appelsDetacher, ['b1']);
      expect(bouton('Réessayer'), findsOneWidget);
    });

    testWidgets('la validation qui ne répond pas est suspendue aussi', (
      tester,
    ) async {
      await ouvrir(tester, delaiSuspendu: delai);
      envois.essai.surProgression!(2, 2);
      await pomper(tester, 3000);
      expect(find.byType(EcranCloche), findsOneWidget);
      expect(find.text('Réessayer'), findsNothing);

      await pomper(tester, 5000);

      expect(envois.appelsDetacher, ['b1']);
      expect(bouton('Réessayer'), findsOneWidget);
    });

    testWidgets('Réessayer repart, et l\'ancien essai lâché ne parle plus', (
      tester,
    ) async {
      await ouvrir(tester, delaiSuspendu: delai);
      final ancien = envois.essai;
      await pomper(tester, 5500);
      await appuyer(tester, 'Réessayer');
      await tester.pump();
      expect(envois.essais, hasLength(2));

      ancien.reponse.complete(const ResultatEnvoi(StatutEnvoi.annule));
      await pomper(tester, 500);
      expect(ferme, isFalse);
      rienAToucher();

      envois.essai.surProgression!(2, 2);
      envois.essai.reponse.complete(const ResultatEnvoi(StatutEnvoi.publie));
      await pomper(tester, 5000);
      expect(resultat!.issue, IssueCloche.publie);
    });

    testWidgets('Garder en brouillon après la suspension', (tester) async {
      await ouvrir(tester, delaiSuspendu: delai);
      await pomper(tester, 5500);

      await appuyer(tester, 'Garder en brouillon');
      await pomper(tester, 100);

      expect(envois.appelsGarder, ['b1']);
      expect(resultat!.issue, IssueCloche.brouillonGarde);
    });

    testWidgets('l\'ancien essai lâché qui publie quand même : publié', (
      tester,
    ) async {
      await ouvrir(tester, delaiSuspendu: delai);
      final ancien = envois.essai;
      await pomper(tester, 5500);
      expect(bouton('Réessayer'), findsOneWidget);

      ancien.reponse.complete(const ResultatEnvoi(StatutEnvoi.publie));
      await pomper(tester, 3000);

      expect(ferme, isTrue);
      expect(resultat!.issue, IssueCloche.publie);
    });
  });

  group('arrière-plan', () {
    const delai = Duration(seconds: 5);

    Future<void> mettreEnPause(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
    }

    Future<void> reprendre(WidgetTester tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
    }

    testWidgets('la mise en pause ne touche pas à l\'envoi', (tester) async {
      await ouvrir(tester);

      await mettreEnPause(tester);
      await pomper(tester, 500);

      expect(envois.appelsGarder, isEmpty);
      expect(envois.appelsAttente, isEmpty);
      expect(envois.appelsDetacher, isEmpty);
      rienAToucher();
    });

    testWidgets('le temps passé dehors n\'est pas une suspension', (
      tester,
    ) async {
      await ouvrir(tester, delaiSuspendu: delai);
      envois.essai.surProgression!(0, 2);
      await pomper(tester, 1000);

      await mettreEnPause(tester);
      await tester.pump(const Duration(minutes: 2));
      await reprendre(tester);
      await pomper(tester, 1000);

      expect(envois.appelsEtat, ['b1']);
      expect(envois.appelsDetacher, isEmpty);
      rienAToucher();

      await pomper(tester, 5000);
      expect(envois.appelsDetacher, ['b1']);
    });

    testWidgets('retour : l\'envoi tourne encore, rien ne change', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.essai.surProgression!(1, 2);
      await pomper(tester, 2000);
      final avant = pourcentage(tester);

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 100);

      expect(envois.appelsEtat, ['b1']);
      expect(pourcentage(tester), greaterThanOrEqualTo(avant));
      rienAToucher();
      expect(ferme, isFalse);
    });

    testWidgets('retour : le moment s\'est publié pendant l\'absence', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.etat = EtatReel.publie;

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 5000);

      expect(ferme, isTrue);
      expect(resultat!.issue, IssueCloche.publie);
    });

    testWidgets('retour : l\'envoi a échoué pendant l\'absence', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.etat = EtatReel.echec;

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 100);

      expect(find.textContaining('n\'a pas abouti'), findsOneWidget);
      expect(bouton('Réessayer'), findsOneWidget);
      expect(bouton('Garder en brouillon'), findsOneWidget);
    });

    testWidgets('retour : l\'envoi a été coupé, mis en attente', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.etat = EtatReel.coupe;

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 200);

      expect(envois.appelsAttente, ['b1']);
      expect(ferme, isTrue);
      expect(resultat!.issue, IssueCloche.enAttente);
    });

    testWidgets('retour : brouillon disparu, la cloche se referme', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.etat = EtatReel.introuvable;

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 200);

      expect(ferme, isTrue);
      expect(resultat!.issue, IssueCloche.annule);
    });

    testWidgets('retour : un envoi déjà conclu n\'est pas relu', (
      tester,
    ) async {
      await ouvrir(tester);
      envois.essai.reponse.complete(
        ResultatEnvoi(StatutEnvoi.echec, erreur: StateError('refusé')),
      );
      await pomper(tester, 100);
      envois.etat = EtatReel.coupe;

      await mettreEnPause(tester);
      await reprendre(tester);
      await pomper(tester, 100);

      expect(envois.appelsEtat, isEmpty);
      expect(envois.appelsAttente, isEmpty);
      expect(bouton('Réessayer'), findsOneWidget);
    });
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
