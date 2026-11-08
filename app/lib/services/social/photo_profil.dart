import 'package:supabase_flutter/supabase_flutter.dart';

/// L'adresse publique d'une photo de profil à partir de son chemin dans
/// le bucket `avatars` (colonne `profils.photo_url`), ou `null` s'il n'y
/// en a pas — l'app affiche alors l'initiale du pseudo.
///
/// [miniature] : la copie de 132 × 132 px rangée dans un sous-dossier
/// `mini/` à côté de l'original (même nom) — ~5 fois plus légère, pour la
/// carte et les petits avatars.
String? urlPhotoProfil(
  SupabaseClient client,
  String? chemin, {
  bool miniature = false,
}) {
  if (chemin == null || chemin.isEmpty) return null;
  return client.storage
      .from('avatars')
      .getPublicUrl(miniature ? cheminMiniature(chemin) : chemin);
}

/// `demo/portrait_001.jpg` → `demo/mini/portrait_001.jpg`.
String cheminMiniature(String chemin) {
  final separateur = chemin.lastIndexOf('/');
  return separateur == -1
      ? 'mini/$chemin'
      : '${chemin.substring(0, separateur)}/mini/${chemin.substring(separateur + 1)}';
}
