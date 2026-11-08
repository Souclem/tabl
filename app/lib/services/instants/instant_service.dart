import 'dart:typed_data';

import 'instant_affichable.dart';
import 'signal_instants.dart';
import 'type_media_instant.dart';

/// La fenêtre de création (règle 4) est fermée pour cette expérience —
/// le bouton "+ Instant" doit simplement disparaître, jamais afficher
/// cette exception à l'utilisateur (elle ne devrait normalement pas
/// être atteignable si l'écran cache déjà le CTA).
class FenetreInstantFermeeException implements Exception {
  const FenetreInstantFermeeException();
}

/// Le maximum d'Instants actifs est atteint (règle 29) — message dédié,
/// jamais une erreur technique générique.
class LimiteInstantsAtteinteException implements Exception {
  const LimiteInstantsAtteinteException();
}

/// Instants : fragments vivants et temporaires d'une expérience déjà
/// publiée (megaprompt Bloc 2). Un Instant n'existe jamais sans son
/// expérience parente ; son audience est toujours celle du parent, ce
/// service ne définit aucune règle de visibilité qui lui soit propre.
abstract interface class InstantService {
  /// Crée un Instant sur sa propre publication [experienceId]. Lève
  /// [FenetreInstantFermeeException] si plus de
  /// [InstantsConfig.fenetreCreation] s'est écoulé depuis la publication,
  /// ou [LimiteInstantsAtteinteException] si
  /// [InstantsConfig.maxParExperience] est déjà atteint.
  Future<void> creer({
    required String experienceId,
    required TypeMediaInstant type,
    required Uint8List media,
  });

  /// Les Instants actifs d'une expérience, du plus ancien au plus
  /// récent (règle 65), prêts à afficher dans le viewer.
  Future<List<InstantAffichable>> instantsDe(String experienceId);

  /// Marque un Instant comme vu par le compte courant. À n'appeler que
  /// lorsque le média a réellement été présenté suffisamment longtemps
  /// (règle 9) — jamais à la simple ouverture d'une liste.
  Future<void> marquerVu(String instantId);

  /// Supprime son propre Instant (règle 30).
  Future<void> supprimer(String instantId);

  /// Le signal Instants de chaque expérience de [experienceIds], en un
  /// seul aller — pour composer le signal sur chaque post du Feed sans
  /// une requête par post.
  Future<Map<String, SignalInstants>> signaux(List<String> experienceIds);
}
