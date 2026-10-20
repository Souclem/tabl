import 'dart:typed_data';

import 'retour.dart';

/// Les messages des utilisateurs à l'équipe (« Aide et contact »).
abstract class RetourService {
  /// Envoie un message à l'équipe, avec jusqu'à [nombreMaxCaptures]
  /// captures d'écran.
  Future<void> envoyer({
    required TypeRetour type,
    required String texte,
    List<Uint8List> captures = const [],
  });
}
