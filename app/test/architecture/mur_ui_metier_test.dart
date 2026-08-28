import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou : widgets/ ne doit jamais dépendre de services/.
///
/// Depuis la fusion de tabl_ui dans app/ (un seul package), le
/// compilateur n'empêche plus rien : la séparation entre le visuel et le
/// métier tient uniquement par convention (voir CLAUDE.md, « La règle
/// d'organisation »). Ce test remplace le mur que la frontière de
/// package assurait avant — si ce test casse, c'est que le mur est en
/// train d'être percé, pas un détail de plomberie à corriger sans en
/// parler.
void main() {
  test('lib/widgets/ ne contient aucun import de lib/services/', () {
    final dossier = Directory('lib/widgets');
    final fichiers = dossier
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    final motifImportServices = RegExp(
      '''import\\s+['"](package:app/)?(\\.\\./)*services''',
    );

    final coupables = <String>[
      for (final fichier in fichiers)
        if (motifImportServices.hasMatch(fichier.readAsStringSync()))
          fichier.path,
    ];

    expect(
      coupables,
      isEmpty,
      reason:
          'widgets/ doit rester purement visuel : un composant reçoit ses '
          "données déjà prêtes à l'affichage, jamais une dépendance vers "
          'services/. Fichiers en tort : $coupables',
    );
  });
}
