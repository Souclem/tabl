/// Les raccourcis villes de l'Explorer — des favoris personnels
/// ("Paris, Liège, Marbella, +"), pas des filtres ni des marqueurs
/// cartographiques (megaprompt Bloc 1, règles 15-19). Locaux à
/// l'appareil : même principe que [EtatOnboarding], pas de donnée
/// partagée entre proches ici.
abstract interface class RaccourcisVillesService {
  /// Dans l'ordre où elles ont été ajoutées.
  Future<List<String>> mesVilles();

  /// Idempotent : ajouter une ville déjà présente ne la duplique pas.
  Future<void> ajouterVille(String ville);

  /// Ne supprime jamais de souvenirs, restaurants ou historique — retire
  /// uniquement le raccourci (règle 19).
  Future<void> retirerVille(String ville);
}
