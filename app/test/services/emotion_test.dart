import 'package:app/services/souvenirs/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('on propose 5 visages, du pire au meilleur, sans l\'ancien neutre', () {
    expect(
      [for (final e in Emotion.proposees) e.emoji],
      ['😞', '😕', '🙂', '😍', '🤩'],
    );
    expect(
      [for (final e in Emotion.proposees) e.libelle],
      ['Déçu', 'Bof', 'Bien', 'J\'adore', 'Exceptionnel'],
    );
    expect(Emotion.proposees, isNot(contains(Emotion.neutre)));
  });

  test('l\'emoji stocké est retrouvé, y compris l\'ancien 😐', () {
    expect(Emotion.depuisEmoji('😞'), Emotion.decu);
    expect(Emotion.depuisEmoji('😕'), Emotion.bof);
    expect(Emotion.depuisEmoji('😐'), Emotion.neutre);
    expect(Emotion.depuisEmoji('?'), isNull);
    expect(Emotion.depuisEmoji(null), isNull);
  });
}
