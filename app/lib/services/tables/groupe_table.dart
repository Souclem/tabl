import 'membre_table.dart';

/// Le détail complet d'une Table (megaprompt Bloc 3, règle 48 —
/// "GroupeTable" côté Dart pour ne pas entrer en collision avec `Table`
/// du SDK Flutter/mot-clé SQL ; "Table" reste le terme produit affiché à
/// l'écran).
class GroupeTable {
  const GroupeTable({
    required this.id,
    required this.nom,
    required this.creeParMoi,
    required this.jeSuisAdmin,
    required this.membres,
    this.emoji,
    this.signature,
    this.couverturePhotoUrl,
    this.mosaiquePhotosUrls = const [],
  });

  final String id;
  final String nom;
  final String? emoji;

  /// Optionnelle (règle 18) — jamais un champ bio forcé.
  final String? signature;

  final String? couverturePhotoUrl;
  final List<String> mosaiquePhotosUrls;

  final bool creeParMoi;
  final bool jeSuisAdmin;

  final List<MembreTable> membres;

  int get nombreMembresActifs =>
      membres.where((m) => m.statut.valeur == 'active').length;
}
