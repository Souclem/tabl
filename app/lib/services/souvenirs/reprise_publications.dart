import 'dart:async';

import 'package:flutter/widgets.dart';

import 'envoi_publications.dart';

/// Relance la file d'envoi à l'ouverture de l'app et à chaque retour au
/// premier plan. Programme aussi les rappels des brouillons quand l'app
/// passe en arrière-plan, et les retire quand elle revient : ils ne sonnent
/// que l'app fermée.
class ReprisePublications with WidgetsBindingObserver {
  ReprisePublications(this._envois);

  final EnvoiPublications _envois;
  bool _lancementTraite = false;

  /// Programmés depuis le dernier retour au premier plan : un départ passe
  /// par plusieurs états (inactive, hidden, paused), un seul suffit.
  bool _rappelsProgrammes = false;

  void demarrer() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reprendre());
    unawaited(_envois.retirerRappels());
  }

  void arreter() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _rappelsProgrammes = false;
        unawaited(_envois.retirerRappels());
        unawaited(_reprendre());
      // Dès « inactive » : une app tuée depuis le sélecteur d'apps ne
      // passe pas toujours par « paused ».
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        if (_rappelsProgrammes) return;
        _rappelsProgrammes = true;
        unawaited(_envois.programmerRappels());
      case AppLifecycleState.detached:
        break;
    }
  }

  Future<void> _reprendre() async {
    // Sans session, rien ne part : le lancement attend la première reprise
    // où l'on est connecté.
    if (!_envois.connecte) return;
    final auLancement = !_lancementTraite;
    _lancementTraite = true;
    try {
      await _envois.reprendre(auLancement: auLancement);
    } catch (e) {
      debugPrint('Reprise des publications : $e');
    }
  }
}
