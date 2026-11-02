import 'package:app/services/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final maintenant = DateTime(2026, 11, 2, 20);

  group('suggestionsDuesDansLeFeed', () {
    test('jamais vue sur cet appareil : elle peut venir', () {
      expect(
        suggestionsDuesDansLeFeed(
          derniereApparition: null,
          maintenant: maintenant,
        ),
        isTrue,
      );
    });

    test('vue il y a moins de trois jours : pas encore', () {
      expect(
        suggestionsDuesDansLeFeed(
          derniereApparition: maintenant.subtract(const Duration(days: 2)),
          maintenant: maintenant,
        ),
        isFalse,
      );
    });

    test('vue il y a trois jours : elle revient', () {
      expect(
        suggestionsDuesDansLeFeed(
          derniereApparition: maintenant.subtract(intervalleSuggestionsFeed),
          maintenant: maintenant,
        ),
        isTrue,
      );
    });
  });

  test(
    'après la 4e publication, ou après la dernière si le Feed est court',
    () {
      expect(positionSuggestionsDansLeFeed(12), 4);
      expect(positionSuggestionsDansLeFeed(4), 4);
      expect(positionSuggestionsDansLeFeed(2), 2);
    },
  );
}
