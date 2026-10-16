import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  test('date : sans l\'année si c\'est cette année, avec sinon', () {
    final maintenant = DateTime(2026, 10, 16);
    expect(dateLisibleSouvenir(DateTime(2026, 3, 12), maintenant: maintenant), '12 mars');
    expect(
      dateLisibleSouvenir(DateTime(2025, 11, 3), maintenant: maintenant),
      '3 novembre 2025',
    );
  });
}
