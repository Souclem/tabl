import 'dart:async';

import 'package:app/ecrans/ecran_cloche.dart';
import 'package:app/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class _FauxEnvois implements EnvoiPublications {
  final essais = <Completer<ResultatEnvoi>>[];
  final progressions = <void Function(int, int)?>[];
  EtatReel etat = EtatReel.enCours;

  @override
  Future<ResultatEnvoi> envoyer(
    String brouillonId, {
    void Function(int envoyees, int total)? surProgression,
  }) {
    progressions.add(surProgression);
    final c = Completer<ResultatEnvoi>();
    essais.add(c);
    return c.future;
  }

  @override
  Future<void> detacher(String brouillonId) async {}
  @override
  Future<EtatReel> etatReel(String brouillonId) async => etat;
  @override
  Future<bool> mettreEnAttente(String brouillonId) async => true;
  @override
  Future<bool> garderEnBrouillon(String brouillonId) async => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pomper(WidgetTester t, int ms) async {
  for (var i = 0; i < ms; i += 16) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _capture(WidgetTester t, String nom) async {
  await _pomper(t, 500);
  debugPrint('CAPTURE:$nom');
  await Future<void>.delayed(const Duration(seconds: 2));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cloche : suspension, réessai, arrière-plan', (tester) async {
    final envois = _FauxEnvois();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push<ResultatCloche>(
                MaterialPageRoute(
                  builder: (_) => EcranCloche(
                    brouillonId: 'b1',
                    envois: envois,
                    pauseFinale: const Duration(milliseconds: 200),
                    delaiSuspendu: const Duration(seconds: 6),
                  ),
                ),
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await _pomper(tester, 400);

    envois.progressions.last!(1, 3);
    await _capture(tester, 'cloche_en_cours');

    await _pomper(tester, 6500);
    await _capture(tester, 'cloche_suspendue_echec');

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await _capture(tester, 'cloche_reessai');

    envois.etat = EtatReel.echec;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await _pomper(tester, 200);
    await _capture(tester, 'cloche_retour_echec');
  });
}
