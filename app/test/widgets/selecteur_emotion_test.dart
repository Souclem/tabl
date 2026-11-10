import 'package:app/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('5 visages tiennent sur un petit écran et se touchent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? choisi;
    const emojis = ['😞', '😕', '🙂', '😍', '🤩'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TablSelecteurEmotion(
            emojis: emojis,
            selection: '🙂',
            onSelection: (e) => choisi = e,
          ),
        ),
      ),
    );

    for (final e in emojis) {
      expect(find.text(e), findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('😞'));
    expect(choisi, '😞');
    await tester.tap(find.text('🤩'));
    expect(choisi, '🤩');
  });
}
