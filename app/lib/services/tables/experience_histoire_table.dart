import '../souvenirs/emotion.dart';

/// Une expérience dans "Notre histoire" (megaprompt Bloc 3, règle 22) —
/// réutilise la source `Experience` (nos `souvenirs`) existante, n'affiche
/// que ce qui est utile. Jamais recopié dans une table séparée (règle 41).
class ExperienceHistoireTable {
  const ExperienceHistoireTable({
    required this.id,
    required this.restaurantNom,
    required this.ville,
    required this.dateVisite,
    required this.auteurPseudo,
    this.photoUrl,
    this.emotion,
  });

  final String id;
  final String? photoUrl;
  final String restaurantNom;
  final String ville;
  final DateTime dateVisite;
  final String auteurPseudo;
  final Emotion? emotion;
}

/// "Là où l'on revient" (règle 21) : une vraie récurrence — plusieurs
/// expériences de membres de la Table liées au même restaurant dans le
/// temps. Jamais un score ou un classement, juste ce fait.
class RecurrenceTable {
  const RecurrenceTable({required this.restaurantNom, required this.nombreFois});

  final String restaurantNom;
  final int nombreFois;
}
