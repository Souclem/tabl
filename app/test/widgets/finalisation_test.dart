import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _poser(WidgetTester tester, Widget enfant) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(body: Center(child: enfant)),
  ),
);

void main() {
  const emojis = ['😞', '😕', '🙂', '😍', '🤩'];
  const noms = ['Déçu', 'Bof', 'Bien', 'J\'adore', 'Exceptionnel'];

  group('TablSelecteurEmotion étendu', () {
    testWidgets('glisser d\'un visage à l\'autre change le choix', (
      tester,
    ) async {
      final choisis = <String>[];
      await _poser(
        tester,
        SizedBox(
          width: 400,
          child: TablSelecteurEmotion(
            emojis: emojis,
            selection: null,
            onSelection: choisis.add,
          ),
        ),
      );

      final depart = tester.getCenter(find.text('😞'));
      final geste = await tester.startGesture(depart);
      await geste.moveTo(tester.getCenter(find.text('🙂')));
      await geste.moveTo(tester.getCenter(find.text('🤩')));
      await geste.up();

      expect(choisis, containsAllInOrder(['🙂', '🤩']));
    });

    testWidgets('montrerNoms affiche tous les noms, sinon le choisi seul', (
      tester,
    ) async {
      Widget selecteur(bool montrer) => SizedBox(
        width: 400,
        child: TablSelecteurEmotion(
          emojis: emojis,
          libelles: noms,
          selection: '🙂',
          montrerNoms: montrer,
          onSelection: (_) {},
        ),
      );
      double opacite(String nom) => tester
          .widget<AnimatedOpacity>(
            find.ancestor(
              of: find.text(nom),
              matching: find.byType(AnimatedOpacity),
            ),
          )
          .opacity;

      await _poser(tester, selecteur(false));
      expect(opacite('Bien'), 1);
      expect(opacite('Déçu'), 0);

      await _poser(tester, selecteur(true));
      expect(opacite('Déçu'), 1);
      expect(opacite('Exceptionnel'), 1);
    });
  });

  group('TablNotesEtoiles', () {
    const lignes = [
      (cle: 'cuisine', libelle: 'La cuisine', note: 3),
      (cle: 'service', libelle: 'Service', note: 0),
    ];

    testWidgets('toucher une étoile donne la note', (tester) async {
      final notes = <String, int>{};
      await _poser(
        tester,
        TablNotesEtoiles(
          lignes: lignes,
          onNote: (cle, note) => notes[cle] = note,
          onEffacer: (_) {},
        ),
      );

      await tester.tap(find.byKey(const ValueKey('etoile-service-5')));
      await tester.tap(find.byKey(const ValueKey('etoile-cuisine-1')));

      expect(notes, {'service': 5, 'cuisine': 1});
    });

    testWidgets('seule une catégorie notée peut être effacée', (tester) async {
      final effacees = <String>[];
      await _poser(
        tester,
        TablNotesEtoiles(
          lignes: lignes,
          onNote: (_, _) {},
          onEffacer: effacees.add,
        ),
      );

      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(effacees, ['cuisine']);
    });
  });

  group('TablBoutonPrincipalFinalisation', () {
    testWidgets('grisé, il reste touchable pour rappeler ce qui manque', (
      tester,
    ) async {
      var touches = 0;
      await _poser(
        tester,
        SizedBox(
          width: 240,
          child: TablBoutonPrincipalFinalisation(
            libelle: 'Publier',
            grise: true,
            onPresse: () => touches++,
          ),
        ),
      );

      await tester.tap(find.text('Publier'));
      expect(touches, 1);
    });

    testWidgets('en cours, il ne réagit plus', (tester) async {
      var touches = 0;
      await _poser(
        tester,
        SizedBox(
          width: 240,
          child: TablBoutonPrincipalFinalisation(
            libelle: 'Publier',
            enCours: true,
            onPresse: () => touches++,
          ),
        ),
      );

      await tester.tap(find.byType(TablBoutonPrincipalFinalisation));
      expect(touches, 0);
    });
  });
}
