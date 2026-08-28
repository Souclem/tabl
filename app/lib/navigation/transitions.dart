import 'package:flutter/material.dart';

/// Transition douce (fondu + légère montée) pour l'ouverture d'un
/// formulaire depuis un écran "parent" — donne l'impression que le
/// formulaire s'ouvre plutôt que de simplement remplacer l'écran.
Route<T> ouvrirFormulaire<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final courbe = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: courbe,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(courbe),
          child: child,
        ),
      );
    },
  );
}

/// Bouton retour défensif : dépile s'il y a quelque chose en dessous,
/// sinon exécute [secours].
///
/// Un écran comme `EcranConnexion` est parfois la racine de l'app (un
/// utilisateur qui revient y arrive directement, sans accueil en dessous —
/// voir `EcranDemarrage`). `Navigator.pop()` sans rien en dessous vide le
/// Navigator et laisse un écran noir : ce garde-fou évite ça.
void revenirOuSecours(BuildContext context, VoidCallback secours) {
  final navigateur = Navigator.of(context);
  if (navigateur.canPop()) {
    navigateur.pop();
  } else {
    secours();
  }
}

/// Simple fondu enchaîné, pour basculer entre deux écrans de même niveau
/// (connexion ↔ inscription) sans suggérer qu'on "entre" plus profond dans
/// la navigation.
Route<T> remplacerFormulaire<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
        child: child,
      );
    },
  );
}
