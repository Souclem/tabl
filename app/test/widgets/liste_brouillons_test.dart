import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<int> poser(WidgetTester tester, {String? limite}) async {
    var nouveaux = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TablListeBrouillons(
            brouillons: const [],
            libelleNouveau: 'Nouveau moment',
            libelleSupprimer: 'Supprimer ce brouillon',
            libelleLimite: limite,
            onReprendre: (_) {},
            onSupprimer: (_) {},
            onNouveau: () => nouveaux++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nouveau moment'));
    await tester.pump();
    return nouveaux;
  }

  double decalage(WidgetTester tester) => tester
      .widget<Transform>(
        find
            .ancestor(
              of: find.text('Nouveau moment'),
              matching: find.byType(Transform),
            )
            .last,
      )
      .transform
      .getTranslation()
      .x;

  testWidgets('possible : « Nouveau moment » commence un moment', (
    tester,
  ) async {
    expect(await poser(tester), 1);
  });

  testWidgets('à la limite : rien ne commence, la ligne tremble et vibre', (
    tester,
  ) async {
    final vibrations = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (appel) async {
        if (appel.method == 'HapticFeedback.vibrate') {
          vibrations.add(appel.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    expect(await poser(tester, limite: 'Trois brouillons au maximum.'), 0);

    await tester.pump(const Duration(milliseconds: 40));
    expect(decalage(tester), isNot(0));
    await tester.pumpAndSettle();
    expect(decalage(tester), moreOrLessEquals(0));
    expect(vibrations, [
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });
}
