import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';

/// Les tailles de la feuille d'un restaurant, en fraction de la hauteur
/// disponible : réduite (l'en-tête seulement) et ouverte.
const tailleFeuilleReduite = 0.34;
const tailleFeuilleOuverte = 0.94;

/// Ouvre la feuille d'un restaurant par-dessus l'écran courant (Feed,
/// Profil, liste de la carte) : une sous-page, pas une nouvelle page.
Future<void> ouvrirFeuilleRestaurant(
  BuildContext context, {
  required String nom,
  required String sousTitre,
  required SouvenirService souvenirService,
  String? restaurantId,
  String? resume,
  bool estEnvie = false,
  Future<String> Function()? entrerDansTabl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: tailleFeuilleOuverte,
      maxChildSize: tailleFeuilleOuverte,
      minChildSize: 0.4,
      expand: false,
      builder: (contexteFeuille, defilement) => FeuilleRestaurant(
        nom: nom,
        sousTitre: sousTitre,
        resume: resume,
        restaurantId: restaurantId,
        estEnvie: estEnvie,
        entrerDansTabl: entrerDansTabl,
        souvenirService: souvenirService,
        defilement: defilement,
        onFermer: () => Navigator.of(contexteFeuille).pop(),
      ),
    ),
  );
}

/// Le contenu de la page d'un restaurant, dans une feuille qui monte du
/// bas : en haut le restaurant (nom, type, qui y est allé, envie), puis
/// les avis de mon réseau du plus récent au plus ancien, en version
/// compacte (photo à gauche). Un tap sur un avis l'agrandit sur place en
/// publication complète, comme dans le Feed — jamais une autre page.
class FeuilleRestaurant extends StatefulWidget {
  const FeuilleRestaurant({
    super.key,
    required this.nom,
    required this.sousTitre,
    required this.souvenirService,
    required this.defilement,
    this.resume,
    this.restaurantId,
    this.estEnvie = false,
    this.entrerDansTabl,
    this.onFermer,
    this.onToucherEntete,
    this.onEnvieChangee,
    this.flottante = false,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String sousTitre;

  /// "Emma et 2 autres y sont allés", si connu.
  final String? resume;
  final SouvenirService souvenirService;

  /// Le défilement de la feuille (fourni par DraggableScrollableSheet).
  final ScrollController defilement;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire : aucun avis.
  final String? restaurantId;
  final bool estEnvie;

  /// Pour un lieu de l'annuaire : le fait entrer dans Tabl et renvoie son
  /// identifiant (nécessaire pour le mettre en envie).
  final Future<String> Function()? entrerDansTabl;
  final VoidCallback? onFermer;

  /// Tap sur l'en-tête — sur la carte, agrandit la feuille réduite.
  final VoidCallback? onToucherEntete;

  /// L'envie a changé (la carte se met à jour).
  final ValueChanged<bool>? onEnvieChangee;

  /// Posée sur la carte : arrondie aux quatre coins. Sinon (feuille qui
  /// monte du bord de l'écran), seulement en haut.
  final bool flottante;

  @override
  State<FeuilleRestaurant> createState() => _FeuilleRestaurantState();
}

class _FeuilleRestaurantState extends State<FeuilleRestaurant>
    with ActionsPublications<FeuilleRestaurant> {
  late String? _restaurantId = widget.restaurantId;
  late bool _estEnvie = widget.estEnvie;
  bool _envieEnCours = false;
  bool _chargement = true;
  bool _erreur = false;

  /// L'avis agrandi en publication complète, s'il y en a un.
  String? _ouvert;

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  @override
  Future<void> recharger() async {
    final id = _restaurantId;
    if (id == null) {
      setState(() {
        souvenirs = const [];
        _chargement = false;
      });
      return;
    }
    try {
      final avis = await widget.souvenirService.souvenirsDuRestaurant(id);
      if (!mounted) return;
      setState(() {
        souvenirs = avis;
        _chargement = false;
        _erreur = false;
      });
    } catch (e) {
      debugPrint('FeuilleRestaurant: $e');
      if (mounted) setState(() => _erreur = true);
    }
  }

  Future<void> _basculerEnvieRestaurant() async {
    setState(() => _envieEnCours = true);
    try {
      final id = _restaurantId ?? await widget.entrerDansTabl?.call();
      if (id == null) return;
      final envie = !_estEnvie;
      await widget.souvenirService.basculerEnvie(id, envie: envie);
      if (!mounted) return;
      setState(() {
        _restaurantId = id;
        _estEnvie = envie;
      });
      widget.onEnvieChangee?.call(envie);
    } catch (e) {
      debugPrint('FeuilleRestaurant: envie : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envieEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avis = souvenirs ?? const <SouvenirFeed>[];
    return Material(
      color: TablTokens.surface,
      elevation: widget.flottante ? 10 : 0,
      shadowColor: Colors.black,
      borderRadius: widget.flottante
          ? BorderRadius.circular(TablTokens.arrondiL)
          : const BorderRadius.vertical(
              top: Radius.circular(TablTokens.arrondiL),
            ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: widget.defilement,
        padding: const EdgeInsets.only(bottom: TablTokens.espaceXl),
        children: [
          _enTete(avis.length),
          if (_erreur)
            const _Message(texte: messageErreurGenerique)
          else if (_chargement)
            const Padding(
              padding: EdgeInsets.all(TablTokens.espaceXl),
              child: Center(
                child: CircularProgressIndicator(color: TablTokens.primaire),
              ),
            )
          else if (avis.isEmpty)
            const _Message(
              texte:
                  'Personne de votre réseau n\'y est encore allé. '
                  'Ajoutez-le à vos envies pour ne pas l\'oublier.',
            )
          else
            for (final a in avis)
              _AvisDepliable(
                key: ValueKey(a.id),
                ouvert: _ouvert == a.id,
                photoUrl: a.photoUrl,
                compact: _avisReduit(a),
                complet: _avisOuvert(a),
              ),
        ],
      ),
    );
  }

  Widget _avisReduit(SouvenirFeed a) {
    return TablLigneAvis(
      auteurPseudo: a.auteurPseudo,
      auteurPhotoUrl: a.auteurPhotoUrl,
      dateLisible: dateLisibleSouvenir(a.dateVisite),
      photoUrl: a.photoUrl,
      emoji: a.emotion?.emoji,
      legende: a.legende,
      resumeReactions: a.nombreReactions == 0
          ? null
          : libelleReactionsSouvenir(a),
      onPresse: () => setState(() => _ouvert = a.id),
    );
  }

  Widget _avisOuvert(SouvenirFeed a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _AvisDepliable.hauteurReduire,
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => setState(() => _ouvert = null),
              icon: const Icon(Icons.expand_less_rounded, size: 18),
              label: const Text('Réduire'),
              style: TextButton.styleFrom(
                foregroundColor: TablTokens.texteDoux,
              ),
            ),
          ),
        ),
        construirePublication(
          a,
          contexte: ContextePublication.feed,
          // On est déjà sur ce restaurant.
          onOuvrirLieu: () {},
        ),
      ],
    );
  }

  Widget _enTete(int nombreAvis) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onToucherEntete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TablTokens.espaceL,
          TablTokens.espaceS,
          TablTokens.espaceS,
          TablTokens.espaceM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: TablTokens.bordure,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: TablTokens.espaceM),
                    child: Text(widget.nom, style: TablTokens.titre),
                  ),
                ),
                if (widget.onFermer != null)
                  IconButton(
                    onPressed: widget.onFermer,
                    tooltip: 'Fermer',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: TablTokens.texteDoux,
                  ),
              ],
            ),
            if (widget.sousTitre.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(widget.sousTitre, style: TablTokens.legende),
              ),
            if (widget.resume != null)
              Padding(
                padding: const EdgeInsets.only(top: TablTokens.espaceS),
                child: Text(
                  widget.resume!,
                  style: TablTokens.legende.copyWith(
                    color: TablTokens.primaire,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: TablTokens.espaceM),
            TablPuceFiltre(
              libelle: _estEnvie ? 'Dans mes envies' : 'Ajouter à mes envies',
              actif: _estEnvie,
              onPresse: _envieEnCours ? () {} : _basculerEnvieRestaurant,
            ),
            if (nombreAvis > 0) ...[
              const SizedBox(height: TablTokens.espaceL),
              Text(
                nombreAvis == 1
                    ? '1 avis de votre réseau'
                    : '$nombreAvis avis de votre réseau',
                style: TablTokens.sousTitre,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un avis qui passe de sa version compacte à la publication complète,
/// sur place : la vignette grandit et glisse jusqu'à la place de la
/// grande photo, le texte compact s'efface en glissant pendant que la
/// hauteur s'ouvre, puis le reste de la publication apparaît. À la
/// fermeture, l'animation inverse.
class _AvisDepliable extends StatefulWidget {
  const _AvisDepliable({
    super.key,
    required this.ouvert,
    required this.photoUrl,
    required this.compact,
    required this.complet,
  });

  /// Hauteur de la ligne "Réduire" au-dessus de la publication complète.
  static const hauteurReduire = 44.0;

  final bool ouvert;
  final String? photoUrl;
  final Widget compact;
  final Widget complet;

  @override
  State<_AvisDepliable> createState() => _AvisDepliableState();
}

class _AvisDepliableState extends State<_AvisDepliable>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: widget.ouvert ? 1 : 0,
  );
  final _cleCompact = GlobalKey();
  final _cleComplet = GlobalKey();

  /// Hauteurs mesurées des deux versions (la complète n'est connue
  /// qu'une fois construite).
  double? _hauteurCompacte;
  double? _hauteurComplete;

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener((_) => setState(() {}));
  }

  @override
  void didUpdateWidget(_AvisDepliable ancien) {
    super.didUpdateWidget(ancien);
    if (widget.ouvert == ancien.ouvert) return;
    if (widget.ouvert) {
      // On construit d'abord la version complète (invisible) pour la
      // mesurer, puis on anime.
      _hauteurComplete = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _hauteurCompacte = _cleCompact.currentContext?.size?.height;
          _hauteurComplete = _cleComplet.currentContext?.size?.height;
        });
        _animation.forward();
      });
    } else {
      _animation.reverse();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  bool get _auRepos =>
      _animation.status == AnimationStatus.completed ||
      _animation.status == AnimationStatus.dismissed;

  @override
  Widget build(BuildContext context) {
    // Au repos : la version affichée, telle quelle.
    if (_auRepos && !(widget.ouvert && _hauteurComplete == null)) {
      return widget.ouvert ? widget.complet : widget.compact;
    }
    return LayoutBuilder(
      builder: (context, contraintes) => AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => _enMouvement(contraintes.maxWidth),
      ),
    );
  }

  Widget _enMouvement(double largeur) {
    final t = Curves.easeInOutCubic.transform(_animation.value);
    final hauteurCompacte =
        _hauteurCompacte ?? TablLigneAvis.cotePhoto + 2 * TablLigneAvis.margeHaut;
    final hauteurComplete = _hauteurComplete ?? hauteurCompacte;

    // La vignette, de sa place compacte à celle de la grande photo.
    const depart = Rect.fromLTWH(
      TablLigneAvis.margeGauche,
      TablLigneAvis.margeHaut,
      TablLigneAvis.cotePhoto,
      TablLigneAvis.cotePhoto,
    );
    final largeurPhoto = largeur - 2 * TablPublication.margePhoto;
    final arrivee = Rect.fromLTWH(
      TablPublication.margePhoto,
      _AvisDepliable.hauteurReduire + TablPublication.hauteurEnTete,
      largeurPhoto,
      largeurPhoto * TablPublication.proportionPhoto,
    );
    final photo = Rect.lerp(depart, arrivee, t)!;
    final arrondi = lerpDouble(
      TablLigneAvis.arrondiPhoto,
      TablPublication.arrondiPhoto,
      t,
    )!;

    // Le texte compact s'efface en glissant vers le bas pendant le début,
    // le reste de la publication apparaît à la fin.
    final effacement = const Interval(0, 0.4).transform(t);
    final apparition = const Interval(0.7, 1).transform(t);

    return ClipRect(
      child: SizedBox(
        height: lerpDouble(hauteurCompacte, hauteurComplete, t),
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Stack(
            children: [
              Opacity(
                opacity: apparition,
                child: KeyedSubtree(key: _cleComplet, child: widget.complet),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - effacement,
                    child: Transform.translate(
                      offset: Offset(0, 24 * t),
                      child: KeyedSubtree(
                        key: _cleCompact,
                        child: widget.compact,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: photo,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(arrondi),
                  child: widget.photoUrl == null
                      ? const ColoredBox(color: TablTokens.surface)
                      : Image.network(
                          widget.photoUrl!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: TablTokens.surface),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
      ),
    );
  }
}
