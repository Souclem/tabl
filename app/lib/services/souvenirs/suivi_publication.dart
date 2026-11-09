import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'envoi_publications.dart';

/// Où en est la publication que la cloche suit.
enum PhaseCloche {
  /// Les photos partent (0 → 90 %) : Modifier et Annuler sont possibles.
  envoi,

  /// L'ordre de publier est parti (90 → 99 %) : plus d'action possible.
  validation,

  /// Rien n'est parti faute de réseau : le moment est gardé sur le
  /// téléphone.
  horsLigne,

  /// La publication n'a pas abouti pour une autre raison.
  echec,

  /// Le serveur a confirmé : 100 %.
  publie,
}

/// Ce que l'auteur peut faire à un instant donné.
enum GesteCloche {
  modifier,
  annuler,
  garderEnBrouillon,
  reessayer,
  envoyerDesQuePossible,
}

/// Comment la cloche se referme : à l'appelant d'en tirer la suite
/// (retour à la finalisation, au Fil, message).
enum IssueCloche {
  /// Le moment est publié, confirmé par le serveur.
  publie,

  /// Le moment était déjà publié : ce qui vient d'être demandé n'a pas été
  /// appliqué (relance d'un envoi dont le commit avait abouti, ou annulation
  /// arrivée trop tard).
  dejaPublie,

  /// « Modifier » : retour à la finalisation, rien n'a été envoyé.
  modifier,

  /// « Annuler » : rien n'a été envoyé, le brouillon reste sur le téléphone.
  annule,

  /// « Garder en brouillon » après un échec.
  brouillonGarde,

  /// « Envoyer dès que possible » : la publication est dans la file.
  enAttente,
}

class ResultatCloche {
  const ResultatCloche(this.issue, {this.tablesEnEchec = const []});

  final IssueCloche issue;

  /// Les Tables dont l'association a échoué (le moment est publié quand
  /// même) : à ne jamais présenter comme un succès.
  final List<String> tablesEnEchec;
}

/// Suit une publication pour l'écran « cloche » : le pourcentage qui
/// avance avec l'envoi réel, l'état du réseau, ce que l'auteur peut faire.
///
/// Le pourcentage n'est pas une animation de fantaisie :
/// - 0 → 90 % suit l'envoi des photos : une courbe de temps, plafonnée par
///   ce qui est réellement parti (30 % + 55 % × photos envoyées / total,
///   90 % quand toutes le sont) ;
/// - 90 → 99 % attend le serveur (validation) ;
/// - 100 % seulement quand le serveur a confirmé.
///
/// L'horloge vient de l'écran, qui appelle [avancer] à chaque image : le
/// suivi n'a ni minuteur ni animation propre, et un test le pilote à la
/// main.
class SuiviPublication extends ChangeNotifier {
  SuiviPublication(this._envois, this.brouillonId);

  final EnvoiPublications _envois;
  final String brouillonId;

  PhaseCloche _phase = PhaseCloche.envoi;
  PhaseCloche get phase => _phase;

  double _affiche = 0;
  double _cible = 0;

  /// La longueur du trait doré, de 0 à 1.
  double get progression => _affiche / 100;

  /// Le pourcentage affiché : jamais 100 avant la confirmation du serveur.
  int get pourcentage => _phase == PhaseCloche.publie && _affiche >= 100
      ? 100
      : math.min(99, _affiche.floor());

  /// Le réseau tarde : l'envoi continue, l'écran le dit.
  bool get reseauLent => _reseauLent;
  bool _reseauLent = false;

  /// Vrai quand la publication est arrêtée en attendant l'auteur.
  bool get enAttenteDuChoix =>
      _phase == PhaseCloche.horsLigne || _phase == PhaseCloche.echec;

  /// Vrai quand le moment était déjà publié (voir [IssueCloche.dejaPublie]).
  bool get dejaPublie => _dejaPublie;
  bool _dejaPublie = false;

  /// Vrai quand « Annuler » ou « Modifier » est arrivé après le commit : le
  /// moment est publié, pas annulé.
  bool get annulationTropTard => _annulationTropTard;
  bool _annulationTropTard = false;

  List<String> get tablesEnEchec => _tablesEnEchec;
  List<String> _tablesEnEchec = const [];

  /// Une action de l'auteur est en cours : les gestes sont grisés.
  bool get occupe => _occupe;
  bool _occupe = false;

  ResultatCloche? _resultat;

  /// Non nul quand la cloche doit se refermer.
  ResultatCloche? get resultat => _resultat;

  /// Les gestes proposés, dans l'ordre d'affichage ; le dernier est le
  /// principal quand il y en a deux de natures différentes.
  List<GesteCloche> get gestes {
    if (_resultat != null) return const [];
    return switch (_phase) {
      PhaseCloche.envoi => const [GesteCloche.modifier, GesteCloche.annuler],
      PhaseCloche.validation || PhaseCloche.publie => const [],
      PhaseCloche.horsLigne => const [
        GesteCloche.garderEnBrouillon,
        GesteCloche.envoyerDesQuePossible,
      ],
      PhaseCloche.echec => const [
        GesteCloche.garderEnBrouillon,
        GesteCloche.reessayer,
      ],
    };
  }

  // --- Horloge ------------------------------------------------------

  Duration? _dernierInstant;
  Duration? _debutEssai;
  Duration? _debutValidation;

  // Les moments de la courbe : (millisecondes, pourcentage). Elle atteint
  // 90 % en 2,7 s si le réseau suit.
  static const _courbe = [
    (0, 0.0),
    (650, 10.0),
    (1150, 20.0),
    (2050, 70.0),
    (2700, 90.0),
  ];

  static double _pourcentageDuTemps(double ms) {
    if (ms >= _courbe.last.$1) return _courbe.last.$2;
    for (var i = 1; i < _courbe.length; i++) {
      if (ms <= _courbe[i].$1) {
        final (m0, p0) = _courbe[i - 1];
        final (m1, p1) = _courbe[i];
        final u = (ms - m0) / (m1 - m0);
        return p0 + (p1 - p0) * (u * u * (3 - 2 * u));
      }
    }
    return _courbe.last.$2;
  }

  /// Fait avancer le trait ; [ecoule] est le temps écoulé depuis un point
  /// fixe (celui du `Ticker` de l'écran).
  void avancer(Duration ecoule) {
    final precedent = _dernierInstant ?? ecoule;
    _dernierInstant = ecoule;
    _debutEssai ??= ecoule;
    final dt = math.min(64.0, (ecoule - precedent).inMicroseconds / 1000);
    final ms = (ecoule - _debutEssai!).inMicroseconds / 1000;
    final avant = (_affiche, _reseauLent, _phase);

    switch (_phase) {
      case PhaseCloche.envoi:
        final plafond = _photosParties
            ? 90.0
            : 30 + 55 * _fractionEnvoyee.clamp(0.0, 1.0);
        _cible = math.min(_pourcentageDuTemps(ms), plafond);
        _reseauLent = !_photosParties && ms > 2100;
        _lisser(dt, 110);
        if (_photosParties && _affiche >= 88.6) {
          _phase = PhaseCloche.validation;
          _debutValidation = ecoule;
        }
      case PhaseCloche.validation:
        final depuis = (ecoule - (_debutValidation ?? ecoule)).inMicroseconds;
        _cible = 90 + 9 * (1 - math.exp(-depuis / 1000 / 700));
        _reseauLent = depuis > 900 * 1000;
        _lisser(dt, 110);
      case PhaseCloche.publie:
        _cible = 100;
        _reseauLent = false;
        _lisser(dt, 60);
        if (_cible - _affiche < 0.4) _affiche = 100;
        if (_affiche >= 100 && _resultat == null) _resultat = _issueFinale;
      case PhaseCloche.horsLigne || PhaseCloche.echec:
        _reseauLent = false;
    }

    if (avant != (_affiche, _reseauLent, _phase) || _resultat != null) {
      notifyListeners();
    }
  }

  void _lisser(double dt, double tau) {
    _affiche += (_cible - _affiche) * (1 - math.exp(-dt / tau));
  }

  // --- Envoi --------------------------------------------------------

  int _envoyees = 0;
  int _total = 0;
  bool _photosParties = false;
  double get _fractionEnvoyee => _total == 0 ? 0 : _envoyees / _total;

  ResultatCloche? _issueFinale;
  bool _quitte = false;
  bool _arrete = false;

  /// Lance (ou relance) l'envoi. Se termine avec l'essai, jamais sur une
  /// erreur : l'issue passe par [phase] et [resultat].
  Future<void> demarrer() async {
    _phase = PhaseCloche.envoi;
    _affiche = 0;
    _cible = 0;
    _reseauLent = false;
    _envoyees = 0;
    _total = 0;
    _photosParties = false;
    _debutEssai = null;
    _debutValidation = null;
    _occupe = false;
    notifyListeners();

    final ResultatEnvoi resultat;
    try {
      resultat = await _envois.envoyer(
        brouillonId,
        surProgression: (envoyees, total) {
          _envoyees = envoyees;
          _total = total;
          _photosParties = envoyees >= total;
        },
      );
    } catch (e) {
      if (!_arrete) _echouer(e);
      return;
    }
    // L'auteur a quitté (Modifier, Annuler) pendant l'envoi : c'est
    // [_quitter] qui conclut.
    if (_quitte || _arrete) return;

    switch (resultat.statut) {
      case StatutEnvoi.publie:
        _dejaPublie = resultat.dejaPublie;
        _tablesEnEchec = resultat.tablesEnEchec;
        _issueFinale = ResultatCloche(
          resultat.dejaPublie ? IssueCloche.dejaPublie : IssueCloche.publie,
          tablesEnEchec: resultat.tablesEnEchec,
        );
        _phase = PhaseCloche.publie;
        notifyListeners();
      case StatutEnvoi.echec:
        _echouer(resultat.erreur);
      case StatutEnvoi.incomplet:
        _terminer(const ResultatCloche(IssueCloche.modifier));
      case StatutEnvoi.introuvable || StatutEnvoi.annule:
        _terminer(const ResultatCloche(IssueCloche.annule));
      case StatutEnvoi.dejaEnCours:
        // Une reprise traite déjà ce brouillon : « Réessayer » reviendra.
        _echouer(null);
    }
  }

  void _echouer(Object? erreur) {
    _phase = erreur != null && estErreurReseau(erreur)
        ? PhaseCloche.horsLigne
        : PhaseCloche.echec;
    _occupe = false;
    notifyListeners();
  }

  void _terminer(ResultatCloche resultat) {
    _resultat = resultat;
    _occupe = false;
    notifyListeners();
  }

  // --- Gestes -------------------------------------------------------

  Future<void> modifier() => _quitter(IssueCloche.modifier);
  Future<void> annuler() => _quitter(IssueCloche.annule);
  Future<void> garderEnBrouillon() => _quitter(IssueCloche.brouillonGarde);

  /// Défait ce qui est parti (arrête l'envoi avant son commit) et garde le
  /// brouillon sur le téléphone. Si le moment s'est publié entre-temps, la
  /// cloche le dit au lieu de prétendre avoir annulé.
  Future<void> _quitter(IssueCloche issue) async {
    if (_occupe || _resultat != null) return;
    if (!gestes.any(
      (g) =>
          g == GesteCloche.modifier ||
          g == GesteCloche.annuler ||
          g == GesteCloche.garderEnBrouillon,
    )) {
      return;
    }
    _occupe = true;
    _quitte = true;
    notifyListeners();
    try {
      final defait = await _envois.garderEnBrouillon(brouillonId);
      _dejaPublie = !defait;
      _annulationTropTard = !defait;
      _terminer(ResultatCloche(defait ? issue : IssueCloche.dejaPublie));
    } catch (e) {
      _quitte = false;
      _echouer(e);
    }
  }

  /// « Envoyer dès que possible » : la file reprendra à l'ouverture ou à
  /// la reprise de l'app.
  Future<void> envoyerDesQuePossible() async {
    if (_occupe ||
        _resultat != null ||
        !gestes.contains(GesteCloche.envoyerDesQuePossible)) {
      return;
    }
    _occupe = true;
    notifyListeners();
    try {
      final gardee = await _envois.mettreEnAttente(brouillonId);
      _terminer(
        ResultatCloche(gardee ? IssueCloche.enAttente : IssueCloche.annule),
      );
    } catch (e) {
      _echouer(e);
    }
  }

  /// « Réessayer » : un nouvel envoi complet, avec le même identifiant (le
  /// serveur ne verra jamais deux moments).
  Future<void> reessayer() async {
    if (_occupe || _resultat != null || _phase != PhaseCloche.echec) return;
    _quitte = false;
    await demarrer();
  }

  @override
  void notifyListeners() {
    if (!_arrete) super.notifyListeners();
  }

  /// L'écran se ferme : l'envoi en cours continue (la file le rattrape),
  /// mais plus rien n'est à montrer.
  @override
  void dispose() {
    _arrete = true;
    super.dispose();
  }
}

/// Vrai quand [erreur] vient d'un réseau absent ou trop lent, plutôt que
/// d'un refus du serveur : la cloche propose alors « Envoyer dès que
/// possible ». Les photos partent ensemble : une coupure arrive enveloppée
/// dans une [ParallelWaitError].
bool estErreurReseau(Object erreur) {
  if (erreur is SocketException ||
      erreur is TimeoutException ||
      erreur is HandshakeException) {
    return true;
  }
  if (erreur is ParallelWaitError) {
    final erreurs = erreur.errors;
    if (erreurs is Iterable) {
      return erreurs.any((e) {
        final interne = e is AsyncError ? e.error : e;
        return interne != null && estErreurReseau(interne);
      });
    }
    return false;
  }
  // Le client HTTP du SDK enveloppe l'erreur système dans une
  // `ClientException` (paquet `http`, pas une dépendance directe) ; un
  // SDK qui la recopie dans son message n'en change pas le sens.
  final texte = erreur.toString();
  return erreur.runtimeType.toString() == 'ClientException' ||
      texte.contains('SocketException') ||
      texte.contains('Failed host lookup');
}
