import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

Commentaire _c(String id, {String? parentId, int minute = 0, int jaime = 0}) =>
    Commentaire(
      id: id,
      texte: id,
      creeLe: DateTime(2026, 11, 1, 12, minute),
      auteurPseudo: 'x',
      estLeMien: false,
      parentId: parentId,
      nombreJaime: jaime,
    );

void main() {
  group('filsDeCommentaires', () {
    test('chaque commentaire suivi de ses réponses, du plus ancien au plus '
        'récent', () {
      final fils = filsDeCommentaires([
        _c('b', minute: 5),
        _c('a', minute: 1),
        _c('b2', parentId: 'b', minute: 9),
        _c('b1', parentId: 'b', minute: 6),
      ]);
      expect([for (final f in fils) f.commentaire.id], ['a', 'b']);
      expect(fils[0].reponses, isEmpty);
      expect([for (final r in fils[1].reponses) r.id], ['b1', 'b2']);
    });

    test("une réponse dont le commentaire n'est plus là n'est pas montrée", () {
      final fils = filsDeCommentaires([_c('r', parentId: 'parti')]);
      expect(fils, isEmpty);
    });
  });

  test("filId : une réponse appartient au fil de ce qu'elle répond", () {
    expect(_c('a').filId, 'a');
    expect(_c('r', parentId: 'a').filId, 'a');
  });

  group('apresJaimeCommentaire', () {
    test('le compte suit, le reste ne bouge pas', () {
      final apres = apresJaimeCommentaire(
        [_c('a', jaime: 2), _c('b')],
        'a',
        aimer: true,
      );
      expect(apres[0].nombreJaime, 3);
      expect(apres[0].jaiAime, isTrue);
      expect(apres[1].nombreJaime, 0);
    });

    test('un geste déjà fait ne compte pas deux fois', () {
      final apres = apresJaimeCommentaire([_c('a')], 'a', aimer: false);
      expect(apres[0].nombreJaime, 0);
    });
  });

  test('libellés', () {
    expect(libelleJaimeCommentaire(0), isNull);
    expect(libelleJaimeCommentaire(1), "1 j'aime");
    expect(libelleJaimeCommentaire(12), "12 j'aime");
    expect(libelleVoirReponses(1), 'Voir la réponse');
    expect(libelleVoirReponses(3), 'Voir les 3 réponses');
  });
}
