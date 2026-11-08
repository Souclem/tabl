/// Sélectionne les photos à afficher en mosaïque de cover d'une Table
/// (megaprompt Bloc 3, règles 13-16).
///
/// [photosParOrdreDePertinence] doit déjà être trié du plus au moins
/// pertinent (le plus significatif d'abord — en pratique, l'expérience la
/// plus récente) : cette fonction ne fait que couper à la bonne taille
/// selon le nombre de photos disponibles, jamais de tri ni de tirage
/// aléatoire — c'est ce qui garantit la stabilité (règle 16, "la mosaïque
/// ne doit pas changer à chaque ouverture").
List<String> selectionnerMosaique(List<String> photosParOrdreDePertinence) {
  final n = photosParOrdreDePertinence.length;
  if (n <= 6) return photosParOrdreDePertinence;
  // >6 : sélectionner automatiquement 4 à 6 images fortes (règle 14) —
  // les 6 les plus pertinentes plutôt qu'une grille de 20 vignettes.
  return photosParOrdreDePertinence.take(6).toList();
}
