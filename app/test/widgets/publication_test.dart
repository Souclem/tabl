import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/widgets.dart';

Widget _publication(
  ContextePublication contexte, {
  VoidCallback? onOptions,
  VoidCallback? onEnregistrer,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TablPublication(
          contexte: contexte,
          auteurPseudo: 'martin',
          dateLisible: '20 août',
          photoUrl: null,
          restaurantNom: 'Le Comptoir',
          ville: 'Paris',
          jaiReagi: false,
          libelleReactions: "Personne n'a encore aimé",
          onReagir: () {},
          onCommenter: () {},
          onOuvrirLieu: () {},
          onEnregistrer: onEnregistrer ?? () {},
          onOptions: onOptions,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Feed : auteur et "Enregistrer" visibles, pas de menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      _publication(ContextePublication.feed, onOptions: () {}),
    );

    expect(find.text('martin'), findsOneWidget);
    expect(find.text('20 août'), findsOneWidget);
    expect(find.byTooltip('Enregistrer'), findsOneWidget);
    expect(find.byTooltip('Options'), findsNothing);
  });

  testWidgets('Profil perso : ni auteur ni "Enregistrer", menu d\'options', (
    tester,
  ) async {
    var options = 0;
    await tester.pumpWidget(
      _publication(ContextePublication.profilPerso, onOptions: () => options++),
    );

    expect(find.text('martin'), findsNothing);
    expect(find.text('20 août'), findsOneWidget);
    expect(find.byTooltip('Enregistrer'), findsNothing);
    expect(find.byTooltip('Commenter'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Options'));
    await tester.tap(find.byTooltip('Options'));
    expect(options, 1);
  });

  testWidgets('Profil de quelqu\'un d\'autre : "Enregistrer" sans auteur ni menu', (
    tester,
  ) async {
    var enregistrements = 0;
    await tester.pumpWidget(
      _publication(
        ContextePublication.profilAutre,
        onOptions: () {},
        onEnregistrer: () => enregistrements++,
      ),
    );

    expect(find.text('martin'), findsNothing);
    expect(find.byTooltip('Options'), findsNothing);

    await tester.ensureVisible(find.byTooltip('Enregistrer'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Enregistrer'));
    expect(enregistrements, 1);
  });
}
