import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// La carte « Vous les connaissez peut-être » ne revient dans le Feed
/// qu'au plus une fois tous les [intervalleSuggestionsFeed] : de temps en
/// temps, pas à chaque ouverture.
const Duration intervalleSuggestionsFeed = Duration(days: 3);

/// Elle s'insère après ce nombre de publications : on a d'abord des
/// nouvelles de ses amis.
const int publicationsAvantSuggestions = 4;

/// La carte peut-elle revenir, vue la dernière fois à
/// [derniereApparition] (`null` : jamais sur cet appareil) ?
bool suggestionsDuesDansLeFeed({
  required DateTime? derniereApparition,
  required DateTime maintenant,
}) =>
    derniereApparition == null ||
    maintenant.difference(derniereApparition) >= intervalleSuggestionsFeed;

/// Où la carte s'insère parmi [nombrePublications] : après la
/// [publicationsAvantSuggestions]-ième, ou après la dernière si le Feed
/// est plus court.
int positionSuggestionsDansLeFeed(int nombrePublications) =>
    min(publicationsAvantSuggestions, nombrePublications);

/// Quand la carte est apparue dans le Feed pour la dernière fois, sur
/// cet appareil. Une erreur de lecture vaut « jamais » : au pire, la
/// carte revient un peu plus tôt.
abstract interface class MemoireSuggestions {
  Future<DateTime?> derniereApparition();

  Future<void> noterApparition(DateTime quand);
}

/// [MemoireSuggestions] gardée localement, via `shared_preferences`.
class MemoireSuggestionsPreferences implements MemoireSuggestions {
  static const String _cle = 'suggestions_feed_vues_le';

  @override
  Future<DateTime?> derniereApparition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final valeur = prefs.getString(_cle);
      return valeur == null ? null : DateTime.tryParse(valeur);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> noterApparition(DateTime quand) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cle, quand.toIso8601String());
    } catch (_) {
      // Pas de stockage : la carte reviendra simplement plus tôt.
    }
  }
}
