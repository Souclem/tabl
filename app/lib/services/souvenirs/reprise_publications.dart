import 'dart:async';

import 'package:flutter/widgets.dart';

import 'envoi_publications.dart';

/// Relance la file d'envoi à l'ouverture de l'app et à chaque retour au
/// premier plan.
class ReprisePublications with WidgetsBindingObserver {
  ReprisePublications(this._envois);

  final EnvoiPublications _envois;
  bool _lancementTraite = false;

  void demarrer() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reprendre());
  }

  void arreter() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reprendre());
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
