import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _SourceSimulee implements SourceVisites {
  _SourceSimulee(this.nombres);

  final Map<String, int> nombres;
  Object? panne;

  @override
  Future<int> nombreMomentsPublies(String restaurantId) async {
    if (panne != null) throw panne!;
    return nombres[restaurantId] ?? 0;
  }
}

void main() {
  group('libelleNiemeFois', () {
    test('le premier moment', () {
      expect(libelleNiemeFois(1), '1re fois ici');
    });

    test('les suivants', () {
      expect(libelleNiemeFois(2), '2e fois ici');
      expect(libelleNiemeFois(3), '3e fois ici');
      expect(libelleNiemeFois(11), '11e fois ici');
    });
  });

  group('CompteurVisites', () {
    test('un premier moment sur un lieu', () async {
      final compteur = CompteurVisites(_SourceSimulee({'resto-1': 1}));
      expect(await compteur.libelle('resto-1'), '1re fois ici');
    });

    test('compte seulement le restaurant demandé', () async {
      final compteur = CompteurVisites(
        _SourceSimulee({'resto-1': 4, 'resto-2': 1}),
      );
      expect(await compteur.libelle('resto-1'), '4e fois ici');
      expect(await compteur.libelle('resto-2'), '1re fois ici');
    });

    test('aucun moment publié : pas de puce', () async {
      final compteur = CompteurVisites(_SourceSimulee({}));
      expect(await compteur.libelle('resto-1'), isNull);
    });

    test("un compte impossible n'empêche rien : pas de puce", () async {
      final source = _SourceSimulee({'resto-1': 3})
        ..panne = StateError('réseau');
      expect(await CompteurVisites(source).libelle('resto-1'), isNull);
    });
  });
}
