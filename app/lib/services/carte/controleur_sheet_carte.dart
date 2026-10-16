import 'package:flutter/foundation.dart';

/// Les bottom sheets de l'Explorer — une seule valeur possible à la
/// fois (megaprompt Bloc 1, règle 51).
enum SheetCarte { periode, filtres, villes, premium, amis, restaurant }

enum EtatAnimationSheet { fermee, ouverture, ouverte, fermeture }

/// Garantit qu'une seule bottom sheet peut exister à la fois — pas par
/// discipline d'appel, mais par construction : il n'y a qu'un seul champ
/// [sheetActive], jamais une pile ou plusieurs booléens indépendants
/// (règles 51-53). Ouvrir une nouvelle sheet remplace toujours
/// l'ancienne, y compris en rafale (tap répété sur le même déclencheur).
class ControleurSheetCarte extends ChangeNotifier {
  SheetCarte? _sheetActive;
  EtatAnimationSheet _etat = EtatAnimationSheet.fermee;

  SheetCarte? get sheetActive => _sheetActive;
  EtatAnimationSheet get etat => _etat;

  /// Ouvre [sheet], en remplaçant toute sheet déjà ouverte ou en cours
  /// d'animation — jamais deux instances, jamais un empilement.
  void ouvrir(SheetCarte sheet) {
    _sheetActive = sheet;
    _etat = EtatAnimationSheet.ouverture;
    notifyListeners();
  }

  /// À appeler quand l'animation d'ouverture se termine.
  void confirmerOuverte() {
    if (_etat != EtatAnimationSheet.ouverture) return;
    _etat = EtatAnimationSheet.ouverte;
    notifyListeners();
  }

  void fermer() {
    if (_sheetActive == null) return;
    _etat = EtatAnimationSheet.fermeture;
    notifyListeners();
  }

  /// À appeler quand l'animation de fermeture se termine.
  void confirmerFermee() {
    _etat = EtatAnimationSheet.fermee;
    _sheetActive = null;
    notifyListeners();
  }
}
