import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> afficher(
    WidgetTester tester, {
    required int photos,
    required VoidCallback onDeclencher,
    bool actif = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: DeclencheurCamera(
            nombrePhotos: photos,
            actif: actif,
            onDeclencher: onDeclencher,
          ),
        ),
      ),
    ),
  );

  testWidgets('toucher déclenche', (tester) async {
    var declenchements = 0;
    await afficher(tester, photos: 0, onDeclencher: () => declenchements++);

    await tester.tap(find.byType(DeclencheurCamera));
    await tester.pump(const Duration(seconds: 1));

    expect(declenchements, 1);
  });

  testWidgets('grisé : ne déclenche pas', (tester) async {
    var declenchements = 0;
    await afficher(
      tester,
      photos: 0,
      actif: false,
      onDeclencher: () => declenchements++,
    );

    await tester.tap(find.byType(DeclencheurCamera));
    await tester.pump(const Duration(seconds: 1));

    expect(declenchements, 0);
  });

  testWidgets('au-delà de dix photos, le déclencheur reste utilisable', (
    tester,
  ) async {
    var declenchements = 0;
    await afficher(tester, photos: 12, onDeclencher: () => declenchements++);

    await tester.tap(find.byType(DeclencheurCamera));
    await tester.pump(const Duration(seconds: 1));

    expect(declenchements, 1);
  });

  testWidgets('annoncé comme « Prendre une photo »', (tester) async {
    final semantique = tester.ensureSemantics();
    await afficher(tester, photos: 3, onDeclencher: () {});

    expect(find.bySemanticsLabel('Prendre une photo'), findsOneWidget);
    semantique.dispose();
  });
}
