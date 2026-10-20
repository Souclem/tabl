import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'retour.dart';
import 'retour_service.dart';

/// Messages adossés à Supabase : table `retours` et bucket privé
/// `retours` (migration `20261020020000_aide_et_contact.sql`).
class RetourServiceSupabase implements RetourService {
  RetourServiceSupabase(this._client);

  final SupabaseClient _client;

  String get _monId => _client.auth.currentSession!.user.id;

  @override
  Future<void> envoyer({
    required TypeRetour type,
    required String texte,
    List<Uint8List> captures = const [],
  }) async {
    final horodatage = DateTime.now().millisecondsSinceEpoch;
    // Chacune sous mon dossier : c'est ce que vérifie la policy du bucket.
    final chemins = await Future.wait([
      for (var i = 0; i < captures.length; i++)
        _deposer(captures[i], '$_monId/$horodatage-$i'),
    ]);

    await _client.from('retours').insert({
      'auteur_id': _monId,
      'type': type.valeur,
      'texte': texte.trim(),
      'captures': chemins,
      'plateforme': Platform.operatingSystem,
      'systeme': Platform.operatingSystemVersion,
    });
  }

  Future<String> _deposer(Uint8List octets, String cheminSansExtension) async {
    final format = formatCapture(octets);
    final chemin = '$cheminSansExtension.${format.extension}';
    await _client.storage
        .from('retours')
        .uploadBinary(
          chemin,
          octets,
          fileOptions: FileOptions(contentType: format.typeMime),
        );
    return chemin;
  }
}
