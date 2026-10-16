import 'package:supabase_flutter/supabase_flutter.dart';

/// L'adresse publique d'une photo de profil à partir de son chemin dans
/// le bucket `avatars` (colonne `profils.photo_url`), ou `null` s'il n'y
/// en a pas — l'app affiche alors l'initiale du pseudo.
String? urlPhotoProfil(SupabaseClient client, String? chemin) {
  if (chemin == null || chemin.isEmpty) return null;
  return client.storage.from('avatars').getPublicUrl(chemin);
}
