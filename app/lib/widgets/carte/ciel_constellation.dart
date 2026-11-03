import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ---------------------------------------------------------------
//  Ce que le ciel reçoit, prêt à dessiner
// ---------------------------------------------------------------

/// Une étoile, à sa place dans le ciel (x = longitude, y = Mercator en
/// degrés, croissant vers le sud) : un restaurant.
class EtoileDuCiel {
  const EtoileDuCiel({
    required this.cle,
    required this.nom,
    required this.detail,
    required this.x,
    required this.y,
    required this.poids,
    this.groupe = -1,
  });

  final String cle;
  final String nom;

  /// « 4 repas », sous son nom.
  final String detail;
  final double x;
  final double y;

  /// Plus il est grand (ses repas), plus l'étoile est grosse.
  final int poids;

  /// Le groupe qui la contient (indice dans [TablCielConstellation.groupes]),
  /// -1 s'il n'y en a pas.
  final int groupe;
}

/// Un groupe d'étoiles, une étoile qui en contient d'autres : une ville,
/// une région, un pays, ou quelques étoiles trop proches pour se voir
/// séparément. De loin une seule étoile, qui se dédouble quand ce qu'elle
/// réunit a la place de se montrer.
class GroupeDuCiel {
  const GroupeDuCiel({
    required this.nom,
    required this.etiquette,
    required this.parent,
    required this.cx,
    required this.cy,
    required this.ecart,
    required this.poids,
  });

  final String nom;

  /// « 137 tables », sous son nom.
  final String etiquette;

  /// Le groupe qui le contient (indice dans [TablCielConstellation.groupes],
  /// toujours avant lui), -1 s'il n'y en a pas.
  final int parent;
  final double cx;
  final double cy;

  /// La distance entre ce qu'il réunit : il se dédouble quand elle laisse,
  /// à l'écran, la place à leurs étoiles.
  final double ecart;

  /// Plus il est grand (ses tables), plus son étoile est grosse.
  final int poids;
}

/// Un tracé de la carte, en coordonnées du ciel, et son emprise.
class TraceDuCiel {
  const TraceDuCiel(
    this.points, {
    required this.xmin,
    required this.xmax,
    required this.ymin,
    required this.ymax,
  });

  final Float64List points;
  final double xmin;
  final double xmax;
  final double ymin;
  final double ymax;
}

/// Des routes qui apparaissent ensemble, à partir de [zoom].
class RoutesDuCiel {
  const RoutesDuCiel({
    required this.zoom,
    required this.autoroute,
    required this.traces,
  });

  final double zoom;
  final bool autoroute;
  final List<TraceDuCiel> traces;
}

/// Le fond : terres, frontières, routes.
class FondDuCiel {
  const FondDuCiel({
    required this.terres,
    required this.frontieres,
    required this.routes,
  });

  final List<TraceDuCiel> terres;
  final List<TraceDuCiel> frontieres;
  final List<RoutesDuCiel> routes;
}

// ---------------------------------------------------------------
//  Le ciel
// ---------------------------------------------------------------

/// La Constellation : chaque restaurant est une étoile. Trop proches pour
/// l'écran, des étoiles n'en font qu'une (une ville, une région, un pays,
/// ou simplement voisines), qui se dédouble quand on s'en approche. Entre
/// elles, un courant de lumière dorée. Les étoiles flottent, suivent le
/// doigt avec un peu de souplesse ; au repos, la carte (terres, frontières,
/// routes) apparaît, et s'efface dès qu'on bouge.
class TablCielConstellation extends StatefulWidget {
  const TablCielConstellation({
    super.key,
    required this.etoiles,
    required this.onTapEtoile,
    required this.onTapVide,
    this.groupes = const [],
    this.liens = const [],
    this.fond,
    this.cleChoisie,
    this.onGeste,
    this.margeHaut = 130,
    this.margeBas = 90,
    this.anime = true,
    this.reveler = false,
    this.onRepos,
  });

  /// De la plus ancienne à la plus récente : elles s'allument dans cet
  /// ordre, et les liens les plus anciens sont les plus pâles.
  final List<EtoileDuCiel> etoiles;

  /// Les groupes d'étoiles, les parents avant leurs enfants.
  final List<GroupeDuCiel> groupes;

  /// De, vers : dans [etoiles] ; groupe : dans [groupes], le plus petit qui
  /// contient les deux étoiles. Le lien se voit quand il s'ouvre.
  final List<({int de, int vers, int groupe})> liens;
  final FondDuCiel? fond;

  /// L'étoile entourée (celle dont la fiche est ouverte).
  final String? cleChoisie;
  final ValueChanged<String> onTapEtoile;

  /// Un toucher hors des étoiles (ou sur une ville, qu'on ouvre).
  final VoidCallback onTapVide;

  /// Au premier geste (pour effacer une aide, par exemple).
  final VoidCallback? onGeste;

  /// La place prise en haut et en bas par ce qui est posé sur le ciel.
  final double margeHaut;
  final double margeBas;

  /// `false` dans les tests : une seule image, sans animation.
  final bool anime;

  /// Une carte est posée sous le ciel : de près, au repos, le ciel
  /// s'éclaircit pour laisser voir son plan (rues, eau, parcs).
  final bool reveler;

  /// Au repos, là où regarde le ciel (zoom à l'échelle de Mapbox) : pour
  /// y poser la carte de dessous.
  final ValueChanged<({double latitude, double longitude, double zoom})>?
  onRepos;

  @override
  State<TablCielConstellation> createState() => _TablCielConstellationState();
}

// Les réglages retenus sur le prototype (3 novembre 2026).
const _flottement = 2.5; // pixels
const _elasticite = 0.10;
const _rythmeFlottement = 0.55;
const _vitesseCourant = 26.0; // pixels par seconde

/// Ce que réunit un groupe se sépare quand l'écart, à l'écran, atteint
/// quelques pixels plus quelques fois la taille moyenne de leurs étoiles.
double _debutOuverture(double rayon) => 8 + 3 * rayon;
double _finOuverture(double rayon) => 14 + 4.5 * rayon;
const _nomsMax = 8;

/// La taille d'une étoile : un groupe d'après ses tables ; un restaurant,
/// plus petit, d'après ses repas.
double _rayonGroupe(int tables) => math.min(22, 2.4 + 1.1 * math.sqrt(tables));
double _rayonEtoile(int repas) => math.min(9, 1.4 + 0.75 * math.sqrt(repas));

double _lisse(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _sortie(double t) => 1 - math.pow(1 - t, 3).toDouble();

/// La latitude d'une position du ciel (Mercator en degrés).
double _latitude(double y) =>
    (2 * math.atan(math.exp(-y * math.pi / 180)) - math.pi / 2) * 180 / math.pi;

/// Le zoom de Mapbox (tuiles de 512 points) qui montre [s] points par degré.
double _zoomMapbox(double s) => math.log(s * 360 / 512) / math.ln2;
double _entreDeux(double t) =>
    t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3).toDouble() / 2;

class _Camera {
  _Camera(this.cx, this.cy, this.s);
  double cx;
  double cy;
  double s;
  _Camera copie() => _Camera(cx, cy, s);
}

/// Ce qui bouge : sa place à l'écran, sa façon de flotter et de suivre.
class _Astre {
  _Astre(math.Random h)
    : p1 = h.nextDouble() * 6.283,
      p2 = h.nextDouble() * 6.283,
      p3 = h.nextDouble() * 6.283,
      p4 = h.nextDouble() * 6.283,
      scintille = h.nextDouble() * 6.283,
      mou = 0.55 + h.nextDouble() * 0.9;

  final double p1;
  final double p2;
  final double p3;
  final double p4;
  final double scintille;

  /// Son retard propre quand on zoome : la constellation s'étire.
  final double mou;
  double ax = 0;
  double ay = 0;
  bool pret = false;
  double rayonEcran = 0;
}

/// Un grain du courant, entre deux étoiles.
class _Grain {
  _Grain(math.Random h)
    : u = h.nextDouble(),
      ecart = (h.nextDouble() + h.nextDouble() + h.nextDouble()) / 1.5 - 1,
      ph = h.nextDouble() * 6.283,
      taille = 0.5 + math.pow(h.nextDouble(), 2) * 1.4,
      a = 0.35 + h.nextDouble() * 0.65;

  double u;
  final double ecart;
  final double ph;
  final double taille;
  final double a;
}

class _Lien {
  _Lien(this.de, this.vers, this.cote, this.groupe, math.Random h)
    : grains = [for (var i = 0; i < 150; i++) _Grain(h)];

  final int de;
  final int vers;
  final double cote;
  final List<_Grain> grains;

  /// Le plus petit groupe qui contient ses deux étoiles : visible quand il
  /// est ouvert.
  final _EtatGroupe? groupe;
}

class _EtatEtoile {
  _EtatEtoile(this.etoile, this.rang, this.astre);

  final EtoileDuCiel etoile;

  /// De la plus ancienne (0) à la plus récente.
  final int rang;
  final _Astre astre;

  /// Son groupe, et combien il est ouvert (1 sans groupe) : fermé, elle se
  /// fond dans son étoile.
  _EtatGroupe? groupe;
  double tp = 1;
  double allumee = 0;
}

class _EtatGroupe {
  _EtatGroupe(this.groupe, this.parent)
    : astre = _Astre(math.Random(Object.hash(groupe.nom, groupe.cx)));

  final GroupeDuCiel groupe;
  final _EtatGroupe? parent;
  final _Astre astre;

  /// Toutes ses étoiles, sous-groupes compris.
  final etoiles = <_EtatEtoile>[];

  /// La taille moyenne des étoiles qu'il réunit directement, combien il en
  /// réunit, et le seul groupe qu'il contienne, s'il n'a que lui.
  double rayonEnfants = 3;
  int enfants = 0;
  _EtatGroupe? seulEnfant;
  double t = 1;
  double e = 1;

  /// Combien son parent est ouvert (1 sans parent).
  double tp = 1;
  double allumee = 0;

  /// Son centre maintenant, ramené vers celui de son parent tant qu'il est
  /// fermé.
  double x = 0;
  double y = 0;
}

class _EtoileFond {
  _EtoileFond(math.Random h)
    : x = h.nextDouble(),
      y = h.nextDouble(),
      r = 0.3 + math.pow(h.nextDouble(), 3) * 1.3,
      a = 0.15 + h.nextDouble() * 0.5,
      f = 0.4 + h.nextDouble() * 1.6,
      ph = h.nextDouble() * 6.283,
      prof = 0.015 + h.nextDouble() * 0.05;

  final double x;
  final double y;
  final double r;
  final double a;
  final double f;
  final double ph;
  final double prof;
}

class _Arc {
  _Arc(this.points, this.cumul);
  final List<Offset> points;
  final List<double> cumul;
  double get longueur => cumul.last;
}

class _Etiquette {
  _Etiquette(this.image, this.largeur, this.hauteur);
  final ui.Image image;
  final double largeur;
  final double hauteur;
}

class _TablCielConstellationState extends State<TablCielConstellation>
    with SingleTickerProviderStateMixin {
  final _battement = ValueNotifier<int>(0);
  Ticker? _ticker;
  Duration _dernierTic = Duration.zero;
  double _dtEnAttente = 0;

  double _l = 0;
  double _h = 0;
  double _dpr = 2;

  final _cam = _Camera(0, 0, 1);
  final _vue = _Camera(0, 0, 1);
  double _echelleMin = 1;
  static const _echelleMax = 160000.0;
  bool _cadre = false;
  double _fondX = 0;
  double _fondY = 0;

  ({_Camera de, _Camera vers, double debut, double duree, bool ralentir})?
  _trajet;
  _Camera? _camRepos;
  double _revelation = 0;
  Offset _elan = Offset.zero;

  double _temps = 0;
  double _intro = 0;
  double _mouvement = 0;
  double _dernierMouvement = -1e9;

  List<_EtatEtoile> _etoiles = const [];
  List<_EtatGroupe> _groupes = const [];
  List<_Lien> _liens = const [];
  final List<_EtoileFond> _fond = [];

  late final ui.Image _lueurOr;
  final Map<String, _Etiquette> _etiquettes = {};

  ui.Image? _imageCarte;
  _Camera? _camCarte;
  Size? _tailleCarte;
  bool _carteEnCours = false;

  double _derniereEchelleGeste = 1;
  int _doigts = 0;
  double _dernierToucherVide = -1e9;
  bool _gesteSignale = false;

  @override
  void initState() {
    super.initState();
    final h = math.Random(20261103);
    for (var i = 0; i < 300; i++) {
      _fond.add(_EtoileFond(h));
    }
    _lueurOr = _lueur(242, 196, 120);
    _preparer();
    _intro = widget.anime ? 0 : 1;
    if (widget.anime) {
      _ticker = createTicker(_tic)..start();
    }
  }

  @override
  void didUpdateWidget(TablCielConstellation ancien) {
    super.didUpdateWidget(ancien);
    if (!identical(ancien.etoiles, widget.etoiles)) {
      final etaitVide = ancien.etoiles.isEmpty;
      _preparer();
      if (etaitVide) {
        _cadre = false;
        _intro = widget.anime ? 0 : 1;
      }
    } else if (!identical(ancien.groupes, widget.groupes) ||
        !identical(ancien.liens, widget.liens)) {
      _preparerGroupes();
    }
    if (!identical(ancien.fond, widget.fond)) _camCarte = null;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _battement.dispose();
    _lueurOr.dispose();
    _imageCarte?.dispose();
    for (final e in _etiquettes.values) {
      e.image.dispose();
    }
    super.dispose();
  }

  void _preparer() {
    final h = math.Random(7);
    // Une étoile déjà là garde sa place (et sa façon de flotter).
    final deja = {for (final e in _etoiles) e.etoile.cle: e.astre};
    var rang = 0;
    _etoiles = [
      for (final e in widget.etoiles)
        _EtatEtoile(e, rang++, deja[e.cle] ?? _Astre(h)),
    ];
    _preparerGroupes();
  }

  /// Les groupes, et les liens (qui en dépendent).
  void _preparerGroupes() {
    final groupes = <_EtatGroupe>[];
    for (final g in widget.groupes) {
      final parent = g.parent >= 0 && g.parent < groupes.length
          ? groupes[g.parent]
          : null;
      groupes.add(_EtatGroupe(g, parent));
    }
    final enfants = List.filled(groupes.length, 0);
    final tailles = List.filled(groupes.length, 0.0);
    for (var i = 0; i < groupes.length; i++) {
      if (groupes[i].parent == null) continue;
      final p = widget.groupes[i].parent;
      enfants[p]++;
      tailles[p] += _rayonGroupe(widget.groupes[i].poids);
      groupes[p].seulEnfant = groupes[i];
    }
    for (final e in _etoiles) {
      final i = e.etoile.groupe;
      e.groupe = i >= 0 && i < groupes.length ? groupes[i] : null;
      if (e.groupe == null) continue;
      enfants[i]++;
      tailles[i] += _rayonEtoile(e.etoile.poids);
      for (var g = e.groupe; g != null; g = g.parent) {
        g.etoiles.add(e);
      }
    }
    for (var i = 0; i < groupes.length; i++) {
      groupes[i].enfants = enfants[i];
      if (enfants[i] > 0) groupes[i].rayonEnfants = tailles[i] / enfants[i];
    }
    _groupes = [
      for (final g in groupes)
        if (g.etoiles.isNotEmpty) g,
    ];
    final h = math.Random(11);
    var k = 0;
    bool dedans(int i) => i >= 0 && i < _etoiles.length;
    _liens = [
      for (final l in widget.liens)
        if (dedans(l.de) && dedans(l.vers))
          _Lien(
            l.de,
            l.vers,
            k++ % 2 == 1 ? 1 : -1,
            l.groupe >= 0 && l.groupe < groupes.length
                ? groupes[l.groupe]
                : null,
            h,
          ),
    ];
  }

  void _tic(Duration ecoule) {
    final dt = (ecoule - _dernierTic).inMicroseconds / 1e6;
    _dernierTic = ecoule;
    _dtEnAttente += dt.clamp(0.0, 0.05);
    _battement.value++;
  }

  /// Une lueur ronde, dessinée une fois puis posée partout.
  static ui.Image _lueur(int r, int g, int b) {
    final enregistreur = ui.PictureRecorder();
    final c = Canvas(enregistreur);
    Color teinte(double a) => Color.fromRGBO(r, g, b, a);
    c.drawRect(
      const Rect.fromLTWH(0, 0, 128, 128),
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(64, 64),
          64,
          [teinte(0.95), teinte(0.5), teinte(0.14), teinte(0)],
          [0, 0.12, 0.35, 1],
        ),
    );
    final image = enregistreur.endRecording().toImageSync(128, 128);
    return image;
  }

  // ---------------------------------------------------------------
  //  Caméra
  // ---------------------------------------------------------------

  /// Là où la caméra veut aller : c'est la place que chaque étoile rejoint.
  Offset _versEcranCible(double x, double y) =>
      Offset((x - _cam.cx) * _cam.s + _l / 2, (y - _cam.cy) * _cam.s + _h / 2);

  _Camera _cadrage(double xmin, double xmax, double ymin, double ymax) {
    final haut = widget.margeHaut, bas = widget.margeBas;
    const cote = 28.0;
    final s = math.min(
      (_l - 2 * cote) / math.max(1e-6, xmax - xmin),
      (_h - haut - bas) / math.max(1e-6, ymax - ymin),
    );
    return _Camera(
      (xmin + xmax) / 2,
      (ymin + ymax) / 2 - (haut - bas) / 2 / s,
      s,
    );
  }

  _Camera _cadrageTout() =>
      _cadrageEtoiles(widget.etoiles) ?? _Camera(4.6, -58, 300);

  /// Le cadre de ces étoiles ; une seule adresse : environ une ville autour.
  _Camera? _cadrageEtoiles(Iterable<EtoileDuCiel> etoiles) {
    var xmin = double.infinity, xmax = double.negativeInfinity;
    var ymin = double.infinity, ymax = double.negativeInfinity;
    for (final e in etoiles) {
      xmin = math.min(xmin, e.x);
      xmax = math.max(xmax, e.x);
      ymin = math.min(ymin, e.y);
      ymax = math.max(ymax, e.y);
    }
    if (xmin.isInfinite) return null;
    if (xmax - xmin < 0.02 && ymax - ymin < 0.02) {
      return _cadrage(xmin - 0.03, xmax + 0.03, ymin - 0.03, ymax + 0.03);
    }
    return _cadrage(xmin, xmax, ymin, ymax);
  }

  _Camera _cadrageGroupe(_EtatGroupe g) {
    final c = _cadrageEtoiles([for (final e in g.etoiles) e.etoile])!;
    // Assez près pour qu'il soit tout à fait ouvert ; et ce qu'il contient
    // aussi, tant qu'il n'y a qu'une chose dedans (un pays d'une seule
    // ville, une ville d'un seul restaurant).
    for (
      _EtatGroupe? h = g;
      h != null;
      h = h.enfants == 1 ? h.seulEnfant : null
    ) {
      c.s = math.max(
        c.s,
        _finOuverture(h.rayonEnfants) * 1.08 / h.groupe.ecart,
      );
    }
    c.s = math.min(_echelleMax, c.s);
    return c;
  }

  void _deplacer(Offset d) {
    _cam.cx -= d.dx / _cam.s;
    _cam.cy -= d.dy / _cam.s;
  }

  void _zoomerAutour(Offset p, double facteur) {
    final s2 = (_cam.s * facteur).clamp(_echelleMin, _echelleMax);
    final wx = (p.dx - _l / 2) / _cam.s + _cam.cx;
    final wy = (p.dy - _h / 2) / _cam.s + _cam.cy;
    _cam
      ..s = s2
      ..cx = wx - (p.dx - _l / 2) / s2
      ..cy = wy - (p.dy - _h / 2) / s2;
  }

  void _allerVers(_Camera cible, [double duree = 0.75, bool ralentir = false]) {
    if (!widget.anime) {
      // Sans animation, on y est tout de suite.
      for (final c in [_cam, _vue]) {
        c
          ..cx = cible.cx
          ..cy = cible.cy
          ..s = cible.s;
      }
      _battement.value++;
      return;
    }
    _trajet = (
      de: _cam.copie(),
      vers: cible,
      debut: _temps,
      duree: duree,
      ralentir: ralentir,
    );
  }

  void _signalerMouvement() {
    _dernierMouvement = _temps;
    if (!widget.anime) _battement.value++;
    if (!_gesteSignale) {
      _gesteSignale = true;
      widget.onGeste?.call();
    }
  }

  // ---------------------------------------------------------------
  //  Gestes
  // ---------------------------------------------------------------

  void _debutGeste(ScaleStartDetails d) {
    _trajet = null;
    _elan = Offset.zero;
    _derniereEchelleGeste = 1;
    _doigts = d.pointerCount;
  }

  void _geste(ScaleUpdateDetails d) {
    _doigts = math.max(_doigts, d.pointerCount);
    if (d.pointerCount >= 2) {
      final facteur = d.scale / _derniereEchelleGeste;
      _derniereEchelleGeste = d.scale;
      _zoomerAutour(d.localFocalPoint, facteur);
    }
    _deplacer(d.focalPointDelta);
    _signalerMouvement();
  }

  void _finGeste(ScaleEndDetails d) {
    // Lâché en glissant : le ciel continue un peu sur sa lancée.
    if (_doigts <= 1) _elan = d.velocity.pixelsPerSecond;
  }

  void _molette(PointerSignalEvent e) {
    if (e is! PointerScrollEvent) return;
    _trajet = null;
    _zoomerAutour(e.localPosition, math.exp(-e.scrollDelta.dy * 0.0016));
    _signalerMouvement();
  }

  void _toucher(TapUpDetails d) {
    final p = d.localPosition;
    final sous = _sous(p);
    if (sous case _EtatGroupe g) {
      // Un groupe fermé : on s'en approche jusqu'à ce qu'il se dédouble.
      widget.onTapVide();
      _allerVers(_cadrageGroupe(g));
      return;
    }
    if (sous case _EtatEtoile e) {
      widget.onTapEtoile(e.etoile.cle);
      return;
    }
    widget.onTapVide();
    if (_temps - _dernierToucherVide < 0.32) {
      // Double toucher : on se rapproche.
      final s2 = math.min(_echelleMax, _cam.s * 2.6);
      final wx = (p.dx - _l / 2) / _cam.s + _cam.cx;
      final wy = (p.dy - _h / 2) / _cam.s + _cam.cy;
      _allerVers(
        _Camera(
          wx - (p.dx - _l / 2) / s2 * 0.4,
          wy - (p.dy - _h / 2) / s2 * 0.4,
          s2,
        ),
        0.42,
      );
      _dernierToucherVide = -1e9;
      return;
    }
    _dernierToucherVide = _temps;
  }

  /// Sous le doigt : un groupe fermé, ou une étoile ; la plus proche.
  Object? _sous(Offset p) {
    Object? meilleur;
    var dmin = double.infinity;
    void essayer(Object quoi, _Astre a) {
      final d = (Offset(a.ax, a.ay) - p).distance;
      if (d < math.max(22, a.rayonEcran + 12) && d < dmin) {
        dmin = d;
        meilleur = quoi;
      }
    }

    for (final g in _groupes) {
      if (g.t < 0.5 && g.tp > 0.5) essayer(g, g.astre);
    }
    for (final e in _etoiles) {
      if (e.tp > 0.5) essayer(e, e.astre);
    }
    return meilleur;
  }

  // ---------------------------------------------------------------
  //  Le mouvement de chaque image
  // ---------------------------------------------------------------

  void _avancer(double dt) {
    _temps += dt;
    if (_intro < 1) _intro = math.min(1, _intro + dt / 2.4);
    final trajet = _trajet;
    if (trajet != null) {
      final t = ((_temps - trajet.debut) / trajet.duree).clamp(0.0, 1.0);
      final e = trajet.ralentir ? _sortie(t) : _entreDeux(t);
      final de = trajet.de, vers = trajet.vers;
      _cam
        ..s = math.exp(math.log(de.s) + (math.log(vers.s) - math.log(de.s)) * e)
        ..cx = de.cx + (vers.cx - de.cx) * e
        ..cy = de.cy + (vers.cy - de.cy) * e;
      if (t >= 1) _trajet = null;
    }
    if (_elan.distance >= 4) {
      _deplacer(_elan * dt);
      _elan *= math.exp(-dt * 4.2);
    } else {
      _elan = Offset.zero;
    }
    // La vue rejoint la caméra avec la souplesse réglée : la carte suit.
    final tau = _elasticite * 0.32;
    final avant = _vue.copie();
    if (tau < 0.004 || !widget.anime) {
      _vue
        ..cx = _cam.cx
        ..cy = _cam.cy
        ..s = _cam.s;
    } else {
      final k = 1 - math.exp(-dt / tau);
      _vue
        ..s = math.exp(
          math.log(_vue.s) + (math.log(_cam.s) - math.log(_vue.s)) * k,
        )
        ..cx = _vue.cx + (_cam.cx - _vue.cx) * k
        ..cy = _vue.cy + (_cam.cy - _vue.cy) * k;
    }
    _fondX += (avant.cx - _vue.cx) * _vue.s;
    _fondY += (avant.cy - _vue.cy) * _vue.s;
    // La carte s'efface vite au premier geste, et revient doucement.
    final bouge =
        _temps - _dernierMouvement < 0.35 ||
        _trajet != null ||
        _elan.distance > 4 ||
        (math.log(_vue.s / _cam.s)).abs() > 0.01 ||
        math.sqrt(
                  math.pow(_vue.cx - _cam.cx, 2) +
                      math.pow(_vue.cy - _cam.cy, 2),
                ) *
                _vue.s >
            1;
    final cible = bouge ? 1.0 : 0.0;
    if (dt > 0) {
      final t = cible > _mouvement ? 0.12 : 0.55;
      _mouvement += (cible - _mouvement) * (1 - math.exp(-dt / t));
    }
    if (!bouge) {
      _rafraichirCarte();
      if (!_memeCamera(_camRepos, _vue)) {
        _camRepos = _vue.copie();
        widget.onRepos?.call((
          latitude: _latitude(_vue.cy),
          longitude: _vue.cx,
          zoom: _zoomMapbox(_vue.s),
        ));
      }
    }
    _revelation = widget.reveler
        ? _lisse(11.5, 12.5, _zoomMapbox(_vue.s)) * (1 - _mouvement)
        : 0;
    _placer(dt);
  }

  Offset _flotter(_Astre e, double amplitude) {
    if (amplitude == 0) return Offset.zero;
    final w = _rythmeFlottement * _temps;
    return Offset(
      amplitude * (math.sin(w + e.p1) + 0.45 * math.sin(w * 2.3 + e.p2)) / 1.45,
      amplitude *
          (math.sin(w * 0.9 + e.p3) + 0.45 * math.sin(w * 1.9 + e.p4)) /
          1.45,
    );
  }

  void _suivre(_Astre e, Offset cible, double dt) {
    final tau = _elasticite * 0.32 * e.mou;
    if (!e.pret || tau < 0.004 || !widget.anime) {
      e
        ..ax = cible.dx
        ..ay = cible.dy
        ..pret = true;
      return;
    }
    final k = 1 - math.exp(-dt / tau);
    e
      ..ax += (cible.dx - e.ax) * k
      ..ay += (cible.dy - e.ay) * k;
  }

  void _placer(double dt) {
    final n = _etoiles.length;
    // Elles s'allument dans l'ordre où on les a connues ; un groupe, avec
    // la première des siennes.
    final fondu = math.max(0.7, n * 0.03);
    for (final e in _etoiles) {
      e.allumee = _lisse(e.rang - fondu, e.rang.toDouble(), _intro * (n - 1));
    }
    for (final g in _groupes) {
      g.allumee = 0;
    }
    for (final e in _etoiles) {
      for (var g = e.groupe; g != null && g.allumee < e.allumee; g = g.parent) {
        g.allumee = e.allumee;
      }
    }
    // Un groupe se dédouble quand ce qu'il réunit a la place de se montrer,
    // jamais avant son parent.
    for (final g in _groupes) {
      final p = g.parent;
      g.tp = p?.t ?? 1;
      final r = g.rayonEnfants;
      g.t = math.min(
        _lisse(_debutOuverture(r), _finOuverture(r), g.groupe.ecart * _cam.s),
        g.tp,
      );
      g.e = _sortie(g.t);
      // Son centre, ramené vers celui de son parent tant qu'il est fermé.
      g.x = p == null ? g.groupe.cx : p.x + (g.groupe.cx - p.groupe.cx) * p.e;
      g.y = p == null ? g.groupe.cy : p.y + (g.groupe.cy - p.groupe.cy) * p.e;
      final centre = _versEcranCible(g.x, g.y);
      _suivre(g.astre, centre + _flotter(g.astre, _flottement), dt);
      g.astre.rayonEcran = _rayonGroupe(g.groupe.poids);
    }
    for (final e in _etoiles) {
      final p = e.groupe;
      e.tp = p?.t ?? 1;
      final x = p == null ? e.etoile.x : p.x + (e.etoile.x - p.groupe.cx) * p.e;
      final y = p == null ? e.etoile.y : p.y + (e.etoile.y - p.groupe.cy) * p.e;
      final place = _versEcranCible(x, y);
      _suivre(e.astre, place + _flotter(e.astre, _flottement), dt);
      e.astre.rayonEcran = _rayonEtoile(e.etoile.poids);
    }
  }

  // ---------------------------------------------------------------
  //  Le dessin
  // ---------------------------------------------------------------

  void _peindre(Canvas c, Size taille) {
    _l = taille.width;
    _h = taille.height;
    if (_l <= 0 || _h <= 0) return;
    if (!_cadre && widget.etoiles.isNotEmpty) {
      final tout = _cadrageTout();
      // Jusqu'au monde entier, même avec une seule adresse.
      _echelleMin = math.min(tout.s * 0.55, (_l - 56) / 360);
      final depart = widget.anime ? 1.6 : 1.0;
      for (final c in [_cam, _vue]) {
        c
          ..cx = tout.cx
          ..cy = tout.cy
          ..s = math.min(_echelleMax, tout.s * depart);
      }
      if (widget.anime) _allerVers(tout, 1.9, true);
      _cadre = true;
    }
    final dt = _dtEnAttente;
    _dtEnAttente = 0;
    _avancer(dt);
    _dessinerFond(c);
    _dessinerImageCarte(c);
    final or = _Lot();
    _dessinerCourant(c, dt, or);
    _dessinerEtoiles(c, or);
    or.peindre(c, _lueurOr);
    _dessinerChoisie(c);
    _dessinerNoms(c);
  }

  void _dessinerFond(Canvas c) {
    final rect = Offset.zero & Size(_l, _h);
    c.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, _h),
          [
            const Color(0xFF0B1324),
            const Color(0xFF070B16),
            const Color(0xFF05070D),
          ].map((c) => c.withValues(alpha: 1 - 0.72 * _revelation)).toList(),
          const [0, 0.55, 1],
        ),
    );
    final pinceau = Paint();
    for (final f in _fond) {
      final x = ((f.x * _l + _fondX * f.prof) % _l + _l) % _l;
      final y = ((f.y * _h + _fondY * f.prof) % _h + _h) % _h;
      final a =
          f.a * (0.6 + 0.4 * math.sin(_temps * f.f + f.ph)) * (1 - _revelation);
      pinceau.color = Color.fromRGBO(220, 228, 245, a.clamp(0.0, 1.0));
      c.drawCircle(Offset(x, y), f.r, pinceau);
    }
  }

  // --- La carte : dessinée en image au repos, posée ensuite telle quelle.

  bool _memeCamera(_Camera? a, _Camera b) =>
      a != null &&
      (math.log(a.s / b.s)).abs() < 0.002 &&
      ((a.cx - b.cx).abs() + (a.cy - b.cy).abs()) * b.s < 0.5;

  void _rafraichirCarte() {
    final fond = widget.fond;
    if (fond == null || _carteEnCours || _l <= 0) return;
    if (_memeCamera(_camCarte, _vue) && _tailleCarte == Size(_l, _h)) return;
    final camera = _vue.copie();
    final taille = Size(_l, _h);
    final enregistreur = ui.PictureRecorder();
    final c = Canvas(enregistreur)..scale(_dpr);
    _dessinerCarte(c, fond, camera, taille);
    final image = enregistreur.endRecording();
    _carteEnCours = true;
    image
        .toImage((taille.width * _dpr).ceil(), (taille.height * _dpr).ceil())
        .then((rendu) {
          image.dispose();
          _carteEnCours = false;
          if (!mounted) {
            rendu.dispose();
            return;
          }
          _imageCarte?.dispose();
          _imageCarte = rendu;
          _camCarte = camera;
          _tailleCarte = taille;
          _battement.value++;
        });
  }

  void _dessinerImageCarte(Canvas c) {
    final image = _imageCarte, camera = _camCarte, taille = _tailleCarte;
    if (image == null || camera == null || taille == null) return;
    final alpha = (1 - _mouvement) * (1 - _revelation);
    if (alpha < 0.01) return;
    // Posée là où la vue est maintenant, même si elle a un peu bougé.
    final k = _vue.s / camera.s;
    c
      ..save()
      ..translate(
        _l / 2 + (camera.cx - _vue.cx) * _vue.s,
        _h / 2 + (camera.cy - _vue.cy) * _vue.s,
      )
      ..scale(k)
      ..translate(-taille.width / 2, -taille.height / 2);
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Offset.zero & taille,
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha)
        ..filterQuality = FilterQuality.medium,
    );
    c.restore();
  }

  void _dessinerCarte(Canvas c, FondDuCiel fond, _Camera cam, Size taille) {
    final l = taille.width, h = taille.height;
    final x0 = cam.cx - l / 2 / cam.s, x1 = cam.cx + l / 2 / cam.s;
    final y0 = cam.cy - h / 2 / cam.s, y1 = cam.cy + h / 2 / cam.s;
    bool visible(TraceDuCiel t) =>
        !(t.xmax < x0 || t.xmin > x1 || t.ymax < y0 || t.ymin > y1) &&
        ((t.xmax - t.xmin) * cam.s >= 2 || (t.ymax - t.ymin) * cam.s >= 2);
    // De très près, quand une ville s'ouvre, la carte s'efface.
    final presence = 1 - 0.8 * _lisse(1500, 8000, cam.s);
    // Toutes les terres en un seul chemin : pas de couture entre voisins.
    final terres = Path();
    for (final t in fond.terres) {
      if (visible(t)) _ajouterTrace(terres, t.points, cam, l, h, fermer: true);
    }
    c.drawPath(
      terres,
      Paint()..color = Color.fromRGBO(30, 42, 70, 0.95 * presence),
    );
    c.drawPath(
      terres,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Color.fromRGBO(150, 170, 215, 0.2 * presence),
    );
    // Les routes, de fines traînées de lumière chaude ; chacune à son zoom.
    final zoom = math.log(cam.s * 360 / 256) / math.ln2;
    for (final niveau in fond.routes) {
      final apparition = _lisse(niveau.zoom - 0.8, niveau.zoom + 0.2, zoom);
      if (apparition < 0.02) continue;
      final routes = Path();
      for (final t in niveau.traces) {
        if (visible(t)) _ajouterTrace(routes, t.points, cam, l, h);
      }
      c.drawPath(
        routes,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = niveau.autoroute ? 0.8 : 0.55
          ..color = niveau.autoroute
              ? Color.fromRGBO(240, 190, 110, 0.18 * presence * apparition)
              : Color.fromRGBO(230, 192, 140, 0.085 * presence * apparition),
      );
    }
    // Les frontières, en pointillés à peine marqués.
    final frontieres = Path();
    for (final t in fond.frontieres) {
      if (visible(t)) _ajouterPointilles(frontieres, t.points, cam, l, h);
    }
    c.drawPath(
      frontieres,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Color.fromRGBO(170, 186, 222, 0.24 * presence),
    );
  }

  /// Ajoute un tracé au chemin, sans les points trop serrés pour se voir.
  static void _ajouterTrace(
    Path chemin,
    Float64List p,
    _Camera cam,
    double l,
    double h, {
    bool fermer = false,
  }) {
    var px = 0.0, py = 0.0;
    for (var i = 0; i < p.length; i += 2) {
      final x = (p[i] - cam.cx) * cam.s + l / 2;
      final y = (p[i + 1] - cam.cy) * cam.s + h / 2;
      if (i == 0) {
        chemin.moveTo(x, y);
      } else if ((x - px).abs() + (y - py).abs() > 1.5 || i == p.length - 2) {
        chemin.lineTo(x, y);
      } else {
        continue;
      }
      px = x;
      py = y;
    }
    if (fermer) chemin.close();
  }

  /// Le même tracé, en pointillés de 2 pixels tous les 5.
  static void _ajouterPointilles(
    Path chemin,
    Float64List p,
    _Camera cam,
    double l,
    double h,
  ) {
    const plein = 2.0, vide = 3.0;
    var reste = plein;
    var trace = true;
    Offset? avant;
    for (var i = 0; i < p.length; i += 2) {
      final point = Offset(
        (p[i] - cam.cx) * cam.s + l / 2,
        (p[i + 1] - cam.cy) * cam.s + h / 2,
      );
      final a = avant;
      if (a == null) {
        avant = point;
        continue;
      }
      final segment = point - a;
      var longueur = segment.distance;
      if (longueur < 1.5 && i != p.length - 2) continue;
      var depart = a;
      final direction = segment / (longueur == 0 ? 1 : longueur);
      while (longueur > 0) {
        final pas = math.min(reste, longueur);
        final fin = depart + direction * pas;
        if (trace) {
          chemin
            ..moveTo(depart.dx, depart.dy)
            ..lineTo(fin.dx, fin.dy);
        }
        reste -= pas;
        longueur -= pas;
        depart = fin;
        if (reste <= 1e-9) {
          trace = !trace;
          reste = trace ? plein : vide;
        }
      }
      avant = point;
    }
  }

  // --- Entre les villes : le courant.

  static Offset _pointArc(Offset a, Offset b, double cote, double u) {
    final mx = (a.dx + b.dx) / 2, my = (a.dy + b.dy) / 2;
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final kx = mx - dy * 0.18 * cote, ky = my + dx * 0.18 * cote;
    final v = 1 - u;
    return Offset(
      v * v * a.dx + 2 * v * u * kx + u * u * b.dx,
      v * v * a.dy + 2 * v * u * ky + u * u * b.dy,
    );
  }

  static _Arc _mesurerArc(Offset a, Offset b, double cote) {
    const pas = 32;
    final points = [
      for (var k = 0; k <= pas; k++) _pointArc(a, b, cote, k / pas),
    ];
    final cumul = <double>[0];
    for (var k = 1; k <= pas; k++) {
      cumul.add(cumul[k - 1] + (points[k] - points[k - 1]).distance);
    }
    return _Arc(points, cumul);
  }

  /// Le point à la fraction [f] de la longueur de l'arc, et sa direction.
  static (Offset, Offset) _surArc(_Arc arc, double f) {
    final d = f * arc.longueur, c = arc.cumul;
    var k = 1;
    while (k < c.length - 1 && c[k] < d) {
      k++;
    }
    final ecart = c[k] - c[k - 1];
    final t = ecart == 0 ? 0.0 : (d - c[k - 1]) / ecart;
    final a = arc.points[k - 1], b = arc.points[k];
    final l = (b - a).distance;
    return (Offset.lerp(a, b, t)!, l == 0 ? const Offset(1, 0) : (b - a) / l);
  }

  void _dessinerCourant(Canvas c, double dt, _Lot or) {
    final n = math.max(1, _etoiles.length - 1);
    final pale = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..blendMode = BlendMode.plus;
    final ecran = math.max(_l, _h);
    for (final lien in _liens) {
      final a = _etoiles[lien.de], b = _etoiles[lien.vers];
      // Il apparaît quand s'ouvre le plus petit groupe qui contient ses
      // deux étoiles.
      final niveau = _lisse(0.15, 0.6, lien.groupe?.t ?? 1);
      final allumee = math.min(a.allumee, b.allumee) * niveau;
      if (allumee < 0.01) continue;
      final pa = Offset(a.astre.ax, a.astre.ay);
      final pb = Offset(b.astre.ax, b.astre.ay);
      // Hors de l'écran, rien à dessiner (l'arc s'écarte peu de sa corde).
      final marge = 0.1 * (pb - pa).distance + 24;
      if (math.max(pa.dx, pb.dx) < -marge ||
          math.min(pa.dx, pb.dx) > _l + marge ||
          math.max(pa.dy, pb.dy) < -marge ||
          math.min(pa.dy, pb.dy) > _h + marge) {
        continue;
      }
      final arc = _mesurerArc(pa, pb, lien.cote);
      // Bien plus long que l'écran : il mène ailleurs, il s'efface.
      final loin = 1 - _lisse(1.1 * ecran, 2 * ecran, arc.longueur);
      if (arc.longueur < 2 || loin < 0.01) continue;
      final recent = (0.45 + 0.55 * lien.vers / n) * allumee * loin;
      // Un fil très pâle garde le chemin lisible.
      pale.color = Color.fromRGBO(217, 172, 103, 0.12 * recent);
      c.drawPath(Path()..addPolygon(arc.points, false), pale);
      // Un trajet trop court pour se lire n'a pas de grains ; ils naissent et
      // s'éteignent en douceur sur les premiers et derniers pixels.
      final nombre = arc.longueur < 30
          ? 0
          : math.min(lien.grains.length, (arc.longueur / 4).round());
      final bord = math.min(0.4, 36 / arc.longueur);
      final largeur = math.min(16.0, 3 + arc.longueur * 0.03);
      final pas = dt * _vitesseCourant / arc.longueur;
      for (var j = 0; j < nombre; j++) {
        final g = lien.grains[j];
        g.u = (g.u + pas) % 1;
        final (point, dir) = _surArc(arc, g.u);
        final enveloppe = math.pow(math.sin(math.pi * g.u), 0.8).toDouble();
        final ecart =
            (g.ecart * largeur +
                math.sin(_temps * _rythmeFlottement * 2 + g.ph) * 1.6) *
            enveloppe;
        final px = point.dx - dir.dy * ecart, py = point.dy + dir.dx * ecart;
        if (px < -10 || px > _l + 10 || py < -10 || py > _h + 10) continue;
        or.ajouter(
          px,
          py,
          g.taille * 3,
          g.a * recent * _lisse(0, bord, g.u) * _lisse(1, 1 - bord, g.u),
        );
      }
    }
  }

  // --- Les étoiles : restaurants et groupes fermés, dessinés de même.

  void _dessinerEtoiles(Canvas c, _Lot or) {
    final coeur = Paint()..blendMode = BlendMode.plus;
    final visibles = <(_Astre, double)>[
      for (final g in _groupes)
        if ((1 - g.t) * g.tp * g.allumee > 0.01)
          (g.astre, (1 - g.t) * g.tp * g.allumee),
      for (final e in _etoiles)
        if (e.tp * e.allumee > 0.01) (e.astre, e.tp * e.allumee),
    ];
    for (final (a, alpha) in visibles) {
      if (a.ax < -60 || a.ax > _l + 60 || a.ay < -60 || a.ay > _h + 60) {
        continue;
      }
      // Des étoiles serrées ne font pas une tache blanche : leurs halos
      // s'atténuent ensemble (leur cœur reste net).
      var foule = 0;
      for (final (b, _) in visibles) {
        if ((b.ax - a.ax).abs() < 26 && (b.ay - a.ay).abs() < 26) foule++;
      }
      final tasse = 1 / math.sqrt(foule);
      final r =
          a.rayonEcran * (1 + 0.06 * math.sin(_temps * 1.3 + a.scintille));
      or.ajouter(a.ax, a.ay, r * 5, alpha * tasse);
      coeur.color = Color.fromRGBO(255, 246, 230, alpha.clamp(0.0, 1.0));
      c.drawCircle(Offset(a.ax, a.ay), r * 0.55, coeur);
    }
  }

  void _dessinerChoisie(Canvas c) {
    final cle = widget.cleChoisie;
    if (cle == null) return;
    for (final e in _etoiles) {
      if (e.etoile.cle != cle) continue;
      c.drawCircle(
        Offset(e.astre.ax, e.astre.ay),
        e.astre.rayonEcran + 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = const Color.fromRGBO(242, 205, 138, 0.9),
      );
      return;
    }
  }

  // --- Les noms.

  static const _ivoire = Color(0xFFF5F0E8);

  _Etiquette _etiquette(
    String texte,
    double taille,
    double graisse,
    Color couleur,
  ) {
    final cle = '$taille|$graisse|${couleur.toARGB32()}|$texte';
    final deja = _etiquettes[cle];
    if (deja != null) return deja;
    final peintre = TextPainter(
      text: TextSpan(
        text: texte,
        style: TextStyle(
          fontFamily: 'BricolageGrotesque',
          fontSize: taille,
          fontWeight:
              FontWeight.values[(graisse / 100).round().clamp(1, 9) - 1],
          fontVariations: [FontVariation('wght', graisse)],
          color: couleur,
          height: 1.15,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final enregistreur = ui.PictureRecorder();
    final c = Canvas(enregistreur)..scale(_dpr);
    peintre.paint(c, Offset.zero);
    final image = enregistreur.endRecording().toImageSync(
      math.max(1, (peintre.width * _dpr).ceil()),
      math.max(1, (peintre.height * _dpr).ceil()),
    );
    final etiquette = _Etiquette(image, peintre.width, peintre.height);
    _etiquettes[cle] = etiquette;
    return etiquette;
  }

  void _poser(Canvas c, _Etiquette e, double x, double y, double alpha) {
    if (alpha <= 0.01) return;
    c.drawImageRect(
      e.image,
      Rect.fromLTWH(0, 0, e.image.width.toDouble(), e.image.height.toDouble()),
      Rect.fromLTWH(x, y, e.largeur, e.hauteur),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0))
        ..filterQuality = FilterQuality.medium,
    );
  }

  /// Le nom d'une étoile de ville ou de groupe et sa ligne de détail, sous
  /// elle, sinon au-dessus ; nulle part s'il n'y a pas la place (`false`).
  bool _poserNom(
    Canvas c,
    _Astre a,
    _Etiquette nom,
    _Etiquette detail,
    double alpha,
    double poids,
    bool Function(Rect, [double]) libre,
    List<(Rect, double)> places,
  ) {
    if (alpha <= 0.02) return false;
    if (a.ax < -30 || a.ax > _l + 30 || a.ay < -30 || a.ay > _h + 30) {
      return false;
    }
    final w = math.max(nom.largeur, detail.largeur) + 4;
    // Près du bord, le nom se décale vers l'intérieur.
    final x = math.min(_l - 10 - w, math.max(10.0, a.ax - w / 2));
    var rect = Rect.fromLTWH(x, a.ay + a.rayonEcran + 6, w, 34);
    // Pas la place en dessous : au-dessus.
    if (!libre(rect, poids)) {
      rect = Rect.fromLTWH(x, a.ay - a.rayonEcran - 40, w, 34);
    }
    if (!libre(rect, poids)) return false;
    places.add((rect, double.infinity));
    _poser(c, nom, x + w / 2 - nom.largeur / 2, rect.top, alpha);
    _poser(
      c,
      detail,
      x + w / 2 - detail.largeur / 2,
      rect.top + 17,
      0.55 * alpha,
    );
    return true;
  }

  /// Les noms, sans qu'ils se chevauchent : [_nomsMax] au plus, ceux des
  /// plus grosses étoiles. Le nom d'une étoile peut recouvrir une étoile
  /// plus petite qu'elle, jamais une plus grande ni un autre nom.
  void _dessinerNoms(Canvas c) {
    final places = <(Rect, double)>[];
    void occuper(_Astre a) {
      final r = a.rayonEcran + 3;
      places.add((
        Rect.fromCenter(
          center: Offset(a.ax, a.ay),
          width: 2 * r,
          height: 2 * r,
        ),
        a.rayonEcran,
      ));
    }

    for (final g in _groupes) {
      if (g.t < 0.35 && g.tp > 0.5) occuper(g.astre);
    }
    for (final e in _etoiles) {
      if (e.tp > 0.5) occuper(e.astre);
    }
    bool libre(Rect r, [double poids = 0]) =>
        r.left > 4 &&
        r.right < _l - 4 &&
        r.top > widget.margeHaut - 10 &&
        r.bottom < _h - widget.margeBas + 20 &&
        !places.any((p) => p.$2 >= poids && p.$1.overlaps(r));
    // Le nom d'un groupe s'efface pendant qu'il se dédouble, ceux de ce
    // qu'il réunit arrivent dans le même temps : jamais de ciel sans nom.
    final candidats =
        <({_Astre astre, String nom, String detail, double alpha})>[
          for (final g in _groupes)
            if ((1 - _lisse(0.25, 0.5, g.t)) *
                    _lisse(0.45, 0.75, g.tp) *
                    g.allumee
                case final alpha when alpha > 0.02)
              (
                astre: g.astre,
                nom: g.groupe.nom,
                detail: g.groupe.etiquette,
                alpha: alpha,
              ),
          for (final e in _etoiles)
            if (_lisse(0.45, 0.75, e.tp) * e.allumee case final alpha
                when alpha > 0.02)
              (
                astre: e.astre,
                nom: e.etoile.nom,
                detail: e.etoile.detail,
                alpha: alpha,
              ),
        ]..sort((a, b) => b.astre.rayonEcran.compareTo(a.astre.rayonEcran));
    var poses = 0;
    for (final n in candidats) {
      if (poses >= _nomsMax) break;
      if (_poserNom(
        c,
        n.astre,
        _etiquette(n.nom, 15, 700, _ivoire),
        _etiquette(n.detail, 12, 500, _ivoire),
        n.alpha,
        n.astre.rayonEcran,
        libre,
        places,
      )) {
        poses++;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _dpr = MediaQuery.devicePixelRatioOf(context);
    return Listener(
      onPointerSignal: _molette,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onScaleStart: _debutGeste,
        onScaleUpdate: _geste,
        onScaleEnd: _finGeste,
        onTapUp: _toucher,
        child: CustomPaint(painter: _PeintreCiel(this), size: Size.infinite),
      ),
    );
  }
}

/// Des lueurs à poser d'un coup (une seule image, plusieurs fois), en
/// lumière qui s'additionne.
class _Lot {
  final transformations = <RSTransform>[];
  final couleurs = <Color>[];

  void ajouter(double x, double y, double rayon, double alpha) {
    if (alpha <= 0.002 || rayon <= 0) return;
    transformations.add(
      RSTransform.fromComponents(
        rotation: 0,
        scale: 2 * rayon / 128,
        anchorX: 64,
        anchorY: 64,
        translateX: x,
        translateY: y,
      ),
    );
    couleurs.add(Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0)));
  }

  void peindre(Canvas c, ui.Image lueur) {
    if (transformations.isEmpty) return;
    c.drawAtlas(
      lueur,
      transformations,
      List.filled(transformations.length, const Rect.fromLTWH(0, 0, 128, 128)),
      couleurs,
      BlendMode.modulate,
      null,
      // Réduite à quelques pixels, la lueur doit garder son cœur : moyenne
      // sur ses versions réduites, pas un seul point pris au hasard.
      Paint()
        ..blendMode = BlendMode.plus
        ..filterQuality = FilterQuality.medium,
    );
  }
}

class _PeintreCiel extends CustomPainter {
  _PeintreCiel(this.etat) : super(repaint: etat._battement);

  final _TablCielConstellationState etat;

  @override
  void paint(Canvas canvas, Size size) => etat._peindre(canvas, size);

  @override
  bool shouldRepaint(_PeintreCiel ancien) => true;
}
