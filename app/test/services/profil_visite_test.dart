import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

ProfilVisite _profil({required bool prive, required StatutAbonnement statut}) =>
    ProfilVisite(id: 'id', pseudo: 'emma', estPrive: prive, statut: statut);

void main() {
  test('profil public : publications visibles, abonné ou pas', () {
    for (final statut in StatutAbonnement.values) {
      expect(
        _profil(prive: false, statut: statut).publicationsVisibles,
        isTrue,
      );
    }
  });

  test('profil privé : seulement pour un abonné accepté', () {
    expect(
      _profil(
        prive: true,
        statut: StatutAbonnement.abonne,
      ).publicationsVisibles,
      isTrue,
    );
    for (final statut in [
      StatutAbonnement.aucun,
      StatutAbonnement.demandeEnvoyee,
      StatutAbonnement.demandeRecue,
    ]) {
      expect(
        _profil(prive: true, statut: statut).publicationsVisibles,
        isFalse,
      );
    }
  });
}
