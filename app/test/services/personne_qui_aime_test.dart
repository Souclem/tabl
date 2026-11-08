import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ({String id, String pseudo, String? photoUrl}) r(String id) =>
      (id: id, pseudo: id, photoUrl: null);

  group('personnesNommees', () {
    test("celles que je suis d'abord, puis les plus récentes", () {
      final nommees = personnesNommees(
        [r('ines'), r('louise'), r('paul'), r('arthur')],
        suivis: {'arthur', 'louise'},
        monId: 'moi',
      );
      expect([for (final p in nommees) p.pseudo], ['louise', 'arthur', 'ines']);
      expect([for (final p in nommees) p.suivie], [true, true, false]);
    });

    test('jamais moi, et 3 au plus', () {
      final nommees = personnesNommees(
        [r('moi'), r('a'), r('b'), r('c'), r('d')],
        suivis: {'moi', 'd'},
        monId: 'moi',
      );
      expect([for (final p in nommees) p.pseudo], ['d', 'a', 'b']);
    });
  });
}
