import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// La cloche : l'écran qui publie un brouillon et qui le suit, de
/// « À table » à la confirmation du serveur. Se ferme sur un
/// [ResultatCloche] : à l'écran qui l'a ouverte d'en tirer la suite (retour
/// à la finalisation, Fil, message).
///
/// Une fois « Publier » touché, rien à toucher : la publication va au bout.
/// Sans réseau, ou après un échec, elle s'arrête et l'auteur choisit :
/// garder en brouillon, envoyer dès que possible, réessayer.
class EcranCloche extends StatefulWidget {
  const EcranCloche({
    super.key,
    required this.brouillonId,
    required this.envois,
    this.pauseFinale = const Duration(milliseconds: 900),
    this.delaiSuspendu = delaiEnvoiSuspendu,
  });

  final String brouillonId;
  final EnvoiPublications envois;

  /// Combien de temps la cloche reste à 100 % avant de se refermer.
  final Duration pauseFinale;

  /// Sans progression pendant ce temps, l'envoi est jugé suspendu (échec).
  final Duration delaiSuspendu;

  @override
  State<EcranCloche> createState() => _EcranClocheState();
}

class _EcranClocheState extends State<EcranCloche>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final SuiviPublication _suivi;
  late final Ticker _horloge;
  var _ferme = false;

  @override
  void initState() {
    super.initState();
    _suivi = SuiviPublication(
      widget.envois,
      widget.brouillonId,
      delaiSuspendu: widget.delaiSuspendu,
    )..addListener(_siFini);
    WidgetsBinding.instance.addObserver(this);
    _horloge = createTicker(_suivi.avancer)..start();
    unawaited(_suivi.demarrer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _horloge.dispose();
    _suivi.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _suivi.miseEnPause();
      case AppLifecycleState.resumed:
        unawaited(_suivi.auRetour());
      default:
        break;
    }
  }

  void _siFini() {
    final resultat = _suivi.resultat;
    if (resultat == null || _ferme) return;
    _ferme = true;
    _horloge.stop();
    final pause =
        _suivi.phase == PhaseCloche.publie ||
            _suivi.dejaPublie ||
            resultat.tablesEnEchec.isNotEmpty
        ? widget.pauseFinale
        : Duration.zero;
    Future.delayed(pause, () {
      if (mounted) Navigator.of(context).pop(resultat);
    });
  }

  String? _note() {
    if (_suivi.annulationTropTard) {
      return 'Ce moment était déjà publié : il n\'a pas pu rester en brouillon.';
    }
    if (_suivi.dejaPublie) {
      return 'Ce moment était déjà publié : vos dernières modifications n\'ont pas été appliquées.';
    }
    return switch (_suivi.phase) {
      PhaseCloche.envoi || PhaseCloche.validation =>
        _suivi.reseauLent ? 'Le réseau est lent…' : null,
      PhaseCloche.horsLigne =>
        'Pas de réseau. Votre moment est gardé sur ce téléphone ; rien n\'a été envoyé.',
      PhaseCloche.echec =>
        'La publication n\'a pas abouti. Rien n\'a été diffusé ; votre moment est gardé.',
      PhaseCloche.publie => switch (_suivi.tablesEnEchec.length) {
        0 => null,
        1 => 'Publié, mais l\'ajout à l\'une de vos Tables n\'a pas abouti.',
        final n => 'Publié, mais l\'ajout à $n de vos Tables n\'a pas abouti.',
      },
    };
  }

  ActionCloche _action(GesteCloche geste) {
    final libre = !_suivi.occupe;
    VoidCallback? surAppui(Future<void> Function() action) =>
        libre ? () => unawaited(action()) : null;
    return switch (geste) {
      GesteCloche.garderEnBrouillon => ActionCloche(
        libelle: 'Garder en brouillon',
        onPresse: surAppui(_suivi.garderEnBrouillon),
      ),
      GesteCloche.reessayer => ActionCloche(
        libelle: 'Réessayer',
        principale: true,
        onPresse: surAppui(_suivi.reessayer),
      ),
      GesteCloche.envoyerDesQuePossible => ActionCloche(
        libelle: 'Envoyer dès que possible',
        principale: true,
        onPresse: surAppui(_suivi.envoyerDesQuePossible),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    // Pas de retour par geste : une publication en route va au bout.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TablTokens.fond,
        body: ListenableBuilder(
          listenable: _suivi,
          builder: (context, _) => TablClochePublication(
            progression: _suivi.progression,
            pourcentage: '${_suivi.pourcentage}',
            mot: 'À table',
            estompe: _suivi.enAttenteDuChoix,
            note: _note(),
            actions: [for (final g in _suivi.gestes) _action(g)],
          ),
        ),
      ),
    );
  }
}
