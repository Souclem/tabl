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

  test('commentaire : depuis quand, puis la date', () {
    final maintenant = DateTime(2026, 10, 20, 18);
    String depuis(Duration ecart) => dateLisibleCommentaire(
      maintenant.subtract(ecart),
      maintenant: maintenant,
    );
    expect(depuis(const Duration(seconds: 20)), 'à l’instant');
    expect(depuis(const Duration(minutes: 5)), '5 min');
    expect(depuis(const Duration(hours: 3)), '3 h');
    expect(depuis(const Duration(hours: 30)), 'hier');
    expect(depuis(const Duration(days: 4)), '4 j');
    expect(depuis(const Duration(days: 20)), '30 septembre');
    expect(titreCommentaires(0), 'Commentaires');
    expect(titreCommentaires(3), '3 commentaires');
  });

  test('légende : toujours entre guillemets, sans les doubler', () {
    expect(
      legendeAffichee('Onze petites assiettes.'),
      '«\u00A0Onze petites assiettes.\u00A0»',
    );
    expect(legendeAffichee('  « Déjà citée »  '), '«\u00A0Déjà citée\u00A0»');
    expect(
      legendeAffichee('"Tapée avec des guillemets"'),
      '«\u00A0Tapée avec des guillemets\u00A0»',
    );
    expect(legendeAffichee('   '), isNull);
    expect(legendeAffichee(null), isNull);
  });
}
