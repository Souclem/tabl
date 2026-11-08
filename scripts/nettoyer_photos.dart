// Nettoie les photos d'un dossier avec le code même de l'app
// (`sansMetadonnees`) : pour scripts/nettoyer_photos.py.
//
// Usage : dart scripts/nettoyer_photos.dart <originaux> <propres>
// Chaque photo qui change est écrite sous <propres>, au même chemin
// relatif, et ce chemin est affiché (une ligne par photo).
import 'dart:io';

import '../app/lib/services/stockage/sans_metadonnees.dart';

void main(List<String> arguments) {
  final originaux = Directory(arguments[0]);
  final propres = arguments[1];
  for (final fichier in originaux.listSync(recursive: true).whereType<File>()) {
    final avant = fichier.readAsBytesSync();
    final apres = sansMetadonnees(avant);
    if (_memes(avant, apres)) continue;
    final relatif = fichier.path.substring(originaux.path.length + 1);
    File('$propres/$relatif')
      ..createSync(recursive: true)
      ..writeAsBytesSync(apres);
    stdout.writeln(relatif);
  }
}

bool _memes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
