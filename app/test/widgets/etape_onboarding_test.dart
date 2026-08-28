import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

void main() {
  Widget enveloppe(Widget enfant) => MaterialApp(home: Scaffold(body: enfant));

  testWidgets('affiche le titre, le texte et le bouton Passer', (tester) async {
    await tester.pumpWidget(
      enveloppe(
        EtapeOnboarding(
          titre: 'Bienvenue',
          texte: 'Découvre Tabl.',
          icone: Icons.restaurant_outlined,
          onPasser: () {},
        ),
      ),
    );

    expect(find.text('Bienvenue'), findsOneWidget);
    expect(find.text('Découvre Tabl.'), findsOneWidget);
    expect(find.text('Passer'), findsOneWidget);
  });

  testWidgets('appelle onPasser au tap sur le bouton Passer', (tester) async {
    var appele = false;

    await tester.pumpWidget(
      enveloppe(
        EtapeOnboarding(
          titre: 'Bienvenue',
          texte: 'Découvre Tabl.',
          icone: Icons.restaurant_outlined,
          onPasser: () => appele = true,
        ),
      ),
    );

    await tester.tap(find.text('Passer'));
    await tester.pump();

    expect(appele, isTrue);
  });

  testWidgets('utilise le libellé personnalisé quand fourni', (tester) async {
    await tester.pumpWidget(
      enveloppe(
        EtapeOnboarding(
          titre: 'Bienvenue',
          texte: 'Découvre Tabl.',
          icone: Icons.restaurant_outlined,
          onPasser: () {},
          libellePasser: 'Ignorer',
        ),
      ),
    );

    expect(find.text('Ignorer'), findsOneWidget);
    expect(find.text('Passer'), findsNothing);
  });

  testWidgets('n\'affiche aucun bouton quand onPasser est absent', (
    tester,
  ) async {
    await tester.pumpWidget(
      enveloppe(
        const EtapeOnboarding(
          titre: 'Profil',
          texte: 'Étape intermédiaire.',
          icone: Icons.person_outline_rounded,
        ),
      ),
    );

    expect(find.byType(TextButton), findsNothing);
  });
}
