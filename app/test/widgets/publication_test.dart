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
    await tester.pumpWidget(_publication(ContextePublication.feed));

    expect(find.text('martin'), findsOneWidget);
    expect(find.text('20 août'), findsOneWidget);
    expect(find.byTooltip('Enregistrer'), findsOneWidget);
    expect(find.byTooltip('Options'), findsNothing);
  });

  testWidgets('Feed, son propre moment : le menu d\'options aussi', (
    tester,
  ) async {
    var options = 0;
    await tester.pumpWidget(
      _publication(ContextePublication.feed, onOptions: () => options++),
    );

    expect(find.text('martin'), findsOneWidget);
    await tester.tap(find.byTooltip('Options'));
    expect(options, 1);
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

  testWidgets('Les photos d\'un moment défilent du doigt, dans le Feed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              TablPublication(
                contexte: ContextePublication.feed,
                auteurPseudo: 'martin',
                dateLisible: '20 août',
                photoUrl: 'https://exemple.com/1.jpg',
                autresPhotosUrls: const [
                  'https://exemple.com/2.jpg',
                  'https://exemple.com/3.jpg',
                ],
                restaurantNom: 'Le Comptoir',
                ville: 'Paris',
                jaiReagi: false,
                libelleReactions: "Personne n'a encore aimé",
                onReagir: () {},
                onCommenter: () {},
                onOuvrirLieu: () {},
                onEnregistrer: () {},
              ),
            ],
          ),
        ),
      ),
    );
    int page() => tester
        .widget<TablIndicateurPage>(find.byType(TablIndicateurPage))
        .index;
    expect(page(), 0);
    // On voit qu'il y en a plusieurs.
    expect(find.text('1/3'), findsOneWidget);

    // Le dégradé posé sur la photo ne doit pas retenir le doigt.
    final photo = find.byType(PageView);
    await tester.fling(photo, const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(page(), 1);

    await tester.fling(photo, const Offset(-300, 0), 1200);
    await tester.pumpAndSettle();
    expect(page(), 2);
    expect(find.text('3/3'), findsOneWidget);
  });
}
