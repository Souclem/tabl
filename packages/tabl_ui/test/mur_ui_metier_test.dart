import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : tabl_ui ne doit dépendre que de Flutter.
///
/// Le compilateur empêche déjà d'importer du métier sans dépendance
/// déclarée. Ce test attrape l'étape d'avant : quelqu'un qui ajoute la
/// dépendance dans le pubspec. Si ce test casse, c'est que le mur entre
/// le design et le métier est en train d'être percé — ce n'est pas un
/// détail de plomberie, il faut en parler avant de le corriger.
void main() {
  test('tabl_ui ne dépend de rien d\'autre que Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    // On isole le bloc `dependencies:` (jusqu'à `dev_dependencies:`).
    final debut = pubspec.indexOf(RegExp(r'^dependencies:', multiLine: true));
    expect(debut, isNonNegative, reason: 'bloc dependencies introuvable');
    final fin = pubspec.indexOf(
      RegExp(r'^dev_dependencies:', multiLine: true),
      debut,
    );
    final bloc = pubspec.substring(debut, fin == -1 ? pubspec.length : fin);

    final declarees = RegExp(r'^  (\w+):', multiLine: true)
        .allMatches(bloc)
        .map((m) => m.group(1)!)
        .toSet();

    expect(
      declarees,
      equals({'flutter'}),
      reason: 'tabl_ui doit rester purement visuel : aucune dépendance vers '
          'les données, le réseau ou le métier. Dépendances trouvées : '
          '$declarees',
    );
  });
}
