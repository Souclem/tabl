import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/services.dart';

void main() {
  group('ControleurSheetCarte', () {
    test('aucune sheet active au départ', () {
      final controleur = ControleurSheetCarte();

      expect(controleur.sheetActive, isNull);
      expect(controleur.etat, EtatAnimationSheet.fermee);
    });

    test('ouvrir une sheet la rend active en cours d\'ouverture', () {
      final controleur = ControleurSheetCarte();

      controleur.ouvrir(SheetCarte.periode);

      expect(controleur.sheetActive, SheetCarte.periode);
      expect(controleur.etat, EtatAnimationSheet.ouverture);
    });

    test('tap rapide 10x sur la même sheet : une seule valeur possible, '
        'jamais un empilement (règle 51-53 du megaprompt Bloc 1)', () {
      final controleur = ControleurSheetCarte();

      for (var i = 0; i < 10; i++) {
        controleur.ouvrir(SheetCarte.periode);
      }

      expect(controleur.sheetActive, SheetCarte.periode);
    });

    test('ouvrir une nouvelle sheet remplace toujours l\'ancienne', () {
      final controleur = ControleurSheetCarte();
      controleur.ouvrir(SheetCarte.periode);

      controleur.ouvrir(SheetCarte.filtres);

      expect(controleur.sheetActive, SheetCarte.filtres);
    });

    test('fermer puis confirmerFermee remet à zéro', () {
      final controleur = ControleurSheetCarte();
      controleur.ouvrir(SheetCarte.villes);
      controleur.confirmerOuverte();

      controleur.fermer();
      expect(controleur.etat, EtatAnimationSheet.fermeture);

      controleur.confirmerFermee();
      expect(controleur.sheetActive, isNull);
      expect(controleur.etat, EtatAnimationSheet.fermee);
    });

    test('fermer sans sheet active ne fait rien', () {
      final controleur = ControleurSheetCarte();

      controleur.fermer();

      expect(controleur.etat, EtatAnimationSheet.fermee);
    });

    test('notifie ses auditeurs à chaque changement', () {
      final controleur = ControleurSheetCarte();
      var notifications = 0;
      controleur.addListener(() => notifications++);

      controleur.ouvrir(SheetCarte.periode);
      controleur.confirmerOuverte();
      controleur.fermer();
      controleur.confirmerFermee();

      expect(notifications, 4);
    });
  });
}
