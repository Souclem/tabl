import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_cercle.dart';
import 'ecran_commentaires.dart';
import 'ecran_creer_instant.dart';
import 'ecran_viewer_instants.dart';

const List<String> _moisAnnee = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Onglet Feed : les souvenirs des gens qu'on suit (et les siens), du
/// plus récent au plus ancien, avec réaction, commentaires et wishlist.
///
/// Structure et copie reprises du prototype fonctionnel
/// (`instruction/Clément (2)/Tabl.dc.html`, bloc `isFeed`) : pas de
/// carte encadrée, pas d'onglets "Récent"/"Pour toi" (jamais réellement
/// dans le prototype — une erreur corrigée en cours de route).
class EcranFeed extends StatefulWidget {
  const EcranFeed({
    required this.souvenirService,
    required this.abonnementService,
    this.instantService,
    super.key,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// `null` désactive entièrement les Instants sur cet écran (megaprompt
  /// Bloc 2, règle 52 — feature flag : pas de CTA, pas de module "À
  /// table maintenant", pas de signal, pas de trou UI). C'est aussi ce
  /// que les tests existants obtiennent par défaut, sans rien changer à
  /// leur comportement.
  final InstantService? instantService;

  @override
  State<EcranFeed> createState() => _EcranFeedState();
}

class _EcranFeedState extends State<EcranFeed> {
  // Calculé une seule fois : cet écran vit dans l'IndexedStack de
  // EcranPrincipal, un changement d'onglet ne doit pas relancer la
  // requête (même raisonnement que le badge de EcranProfil). Mutable
  // (pas `late final`) : une réaction met à jour la liste en place,
  // sans tout recharger.
  late Future<List<SouvenirFeed>> _futurFeed = widget.souvenirService.feed();
  List<SouvenirFeed>? _souvenirs;

  /// Pastille sur l'icône d'ajout d'ami, même source que le badge de
  /// EcranProfil.
  late final Future<int> _futurDemandes =
      widget.abonnementService.nombreDemandesEnAttente();

  // Wishlist ("Enregistrer") : purement locale à la session pour
  // l'instant, aucune table dédiée côté serveur (l'onglet Wishlist de
  // EcranPrincipal est encore "à venir" — voir le résumé de fin
  // d'implémentation).
  final Set<String> _enregistres = {};

  // Instants : chargés en un seul appel groupé une fois le Feed connu
  // (même principe que réactions/commentaires/amis tagués), pas une
  // requête par post. Vide et jamais rechargé si `instantService` est
  // absent (règle 52).
  Map<String, SignalInstants> _signaux = {};
  bool _signauxCharges = false;

  Future<void> _chargerSignaux(List<SouvenirFeed> souvenirs) async {
    final service = widget.instantService;
    if (service == null || _signauxCharges) return;
    _signauxCharges = true;
    final signaux = await service.signaux(souvenirs.map((s) => s.id).toList());
    if (!mounted) return;
    setState(() => _signaux = signaux);
  }

  List<_CandidatATableMaintenant> get _candidatsATableMaintenant {
    final souvenirs = _souvenirs;
    if (souvenirs == null) return const [];
    final candidats = [
      for (final s in souvenirs)
        if (_signaux[s.id]?.aDesInstants ?? false)
          _CandidatATableMaintenant(souvenir: s, signal: _signaux[s.id]!),
    ];
    // Règle 13 : non vu d'abord, puis activité la plus récente — jamais
    // de classement social.
    candidats.sort((a, b) {
      final nonVuA = a.signal.nonVus > 0;
      final nonVuB = b.signal.nonVus > 0;
      if (nonVuA != nonVuB) return nonVuA ? -1 : 1;
      final dateA = a.signal.plusRecentActifLe ?? DateTime(0);
      final dateB = b.signal.plusRecentActifLe ?? DateTime(0);
      return dateB.compareTo(dateA);
    });
    return candidats;
  }

  Future<void> _ouvrirInstants(String experienceId) async {
    final candidats = _candidatsATableMaintenant;
    var index = candidats.indexWhere((c) => c.souvenir.id == experienceId);
    List<_CandidatATableMaintenant> contextes = candidats;
    if (index == -1) {
      // Un seul Instant actif (règle 11 : le signal du post suffit,
      // pas d'entrée "À table maintenant") — le contexte se limite à
      // cette expérience.
      final souvenir = _souvenirs!.firstWhere((s) => s.id == experienceId);
      contextes = [
        _CandidatATableMaintenant(
          souvenir: souvenir,
          signal: _signaux[experienceId] ?? SignalInstants.aucun,
        ),
      ];
      index = 0;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranViewerInstants(
          instantService: widget.instantService!,
          contextes: [
            for (final c in contextes)
              ContexteInstant(
                experienceId: c.souvenir.id,
                auteurPseudo: c.souvenir.auteurPseudo,
                restaurantNom: c.souvenir.restaurantNom,
                ville: c.souvenir.ville,
              ),
          ],
          indexInitial: index,
          onVoirExperience: (_) => Navigator.of(context).pop(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _signauxCharges = false);
    _chargerSignaux(_souvenirs!);
  }

  void _ouvrirSheetATableMaintenant() {
    final candidats = _candidatsATableMaintenant;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                TablTokens.espaceS,
              ),
              child: Text('À table maintenant', style: TablTokens.sousTitre),
            ),
            for (final candidat in candidats)
              TablLigneATableMaintenant(
                auteurPseudo: candidat.souvenir.auteurPseudo,
                restaurantNom: candidat.souvenir.restaurantNom,
                libelleInstants: candidat.signal.nonVus > 1
                    ? '${candidat.signal.nonVus} nouveaux Instants'
                    : candidat.signal.nonVus == 1
                        ? '1 nouvel Instant'
                        : (candidat.signal.total > 1
                            ? '${candidat.signal.total} Instants'
                            : 'vu'),
                nonVu: candidat.signal.nonVus > 0,
                onTap: () {
                  Navigator.of(context).pop();
                  _ouvrirInstants(candidat.souvenir.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _ajouterInstant(String experienceId) async {
    final service = widget.instantService;
    if (service == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranCreerInstant(
          instantService: service,
          experienceId: experienceId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _signauxCharges = false);
    _chargerSignaux(_souvenirs!);
  }

  void _allerVersCercle() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EcranCercle(abonnementService: widget.abonnementService),
      ),
    );
  }

  void _bientotDisponible() {
    afficherMessage(context, 'Bientôt disponible.');
  }

  Future<void> _basculerReaction(SouvenirFeed souvenir) async {
    final nouvelEtat = !souvenir.jaiReagi;
    // Optimiste : l'animation et le compteur réagissent tout de suite,
    // sans attendre le réseau — on ne fait pas patienter pour un geste
    // aussi léger.
    _remplacer(
      souvenir.copierAvec(
        jaiReagi: nouvelEtat,
        nombreReactions: souvenir.nombreReactions + (nouvelEtat ? 1 : -1),
      ),
    );
    try {
      await widget.souvenirService.basculerReaction(
        souvenir.id,
        reagir: nouvelEtat,
      );
    } catch (_) {
      // Échec réseau : on revient à l'état d'avant plutôt que de laisser
      // affiché quelque chose qui n'a pas vraiment été enregistré.
      if (!mounted) return;
      _remplacer(souvenir);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  void _basculerEnregistrement(String souvenirId) {
    setState(() {
      if (!_enregistres.remove(souvenirId)) _enregistres.add(souvenirId);
    });
  }

  Future<void> _ouvrirCommentaires(SouvenirFeed souvenir) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranCommentaires(
          souvenirService: widget.souvenirService,
          souvenirId: souvenir.id,
        ),
      ),
    );
    // Le nombre de commentaires a pu changer pendant la visite : on
    // recharge tout le Feed au retour plutôt que de suivre les ajouts un
    // par un — plus simple, et cet écran n'est pas quitté souvent.
    if (!mounted) return;
    setState(() {
      _futurFeed = widget.souvenirService.feed();
      _souvenirs = null;
      _signauxCharges = false;
    });
  }

  void _remplacer(SouvenirFeed souvenir) {
    final souvenirs = _souvenirs;
    if (souvenirs == null) return;
    setState(() {
      _souvenirs = [
        for (final s in souvenirs) if (s.id == souvenir.id) souvenir else s,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          children: [
            _BarreSuperieure(
              futurDemandes: _futurDemandes,
              onAjouterAmis: _allerVersCercle,
              onNotifications: _bientotDisponible,
              onPeriode: _bientotDisponible,
            ),
            Expanded(
              child: FutureBuilder<List<SouvenirFeed>>(
                future: _futurFeed,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: TablTokens.primaire,
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    // Le message affiché reste générique côté UI, mais
                    // l'erreur réelle part dans les logs — sans ça, un
                    // échec silencieux ne laisse rien pour diagnostiquer.
                    debugPrint(
                      'EcranFeed: ${snapshot.error}\n${snapshot.stackTrace}',
                    );
                    return Center(
                      child: Text(
                        messageErreurGenerique,
                        style: TablTokens.corps.copyWith(
                          color: TablTokens.texteDoux,
                        ),
                      ),
                    );
                  }

                  // `??=` : on ne réinitialise pas la liste mutable à
                  // chaque rebuild déclenché par une réaction, seulement
                  // au premier chargement (ou après un rechargement
                  // volontaire).
                  final souvenirs = _souvenirs ??= snapshot.data!;
                  if (souvenirs.isEmpty) {
                    return _EtatVide(onAjouterAmis: _allerVersCercle);
                  }
                  _chargerSignaux(souvenirs);

                  final candidats = _candidatsATableMaintenant;
                  return Column(
                    children: [
                      // Règle 11 : seulement à partir de 2 expériences
                      // actives — sinon le signal du post lui-même
                      // suffit, pas la peine d'un module en plus.
                      if (candidats.length >= 2)
                        TablRaccourciATableMaintenant(
                          nombre: candidats.length,
                          onPresse: _ouvrirSheetATableMaintenant,
                        ),
                      Expanded(
                        child: _ListeFeed(
                          souvenirs: souvenirs,
                          signaux: _signaux,
                          enregistres: _enregistres,
                          onReagir: _basculerReaction,
                          onOuvrirCommentaires: _ouvrirCommentaires,
                          onBasculerEnregistrement: _basculerEnregistrement,
                          onOuvrirCarte: _bientotDisponible,
                          onOuvrirInstants: _ouvrirInstants,
                          onAjouterInstant: _ajouterInstant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeFeed extends StatelessWidget {
  const _ListeFeed({
    required this.souvenirs,
    required this.signaux,
    required this.enregistres,
    required this.onReagir,
    required this.onOuvrirCommentaires,
    required this.onBasculerEnregistrement,
    required this.onOuvrirCarte,
    required this.onOuvrirInstants,
    required this.onAjouterInstant,
  });

  final List<SouvenirFeed> souvenirs;
  final Map<String, SignalInstants> signaux;
  final Set<String> enregistres;
  final ValueChanged<SouvenirFeed> onReagir;
  final ValueChanged<SouvenirFeed> onOuvrirCommentaires;
  final ValueChanged<String> onBasculerEnregistrement;
  final VoidCallback onOuvrirCarte;
  final ValueChanged<String> onOuvrirInstants;
  final ValueChanged<String> onAjouterInstant;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      // La barre de navigation flotte par-dessus (voir EcranPrincipal) :
      // une marge basse généreuse évite qu'elle ne masque le dernier post.
      padding: const EdgeInsets.fromLTRB(
        0,
        TablTokens.espaceS,
        0,
        TablTokens.espaceXxl + TablTokens.espaceL,
      ),
      itemCount: souvenirs.length + 1,
      itemBuilder: (context, index) {
        if (index == souvenirs.length) {
          return const _PiedDeFeed();
        }
        final souvenir = souvenirs[index];
        final signal = signaux[souvenir.id];
        return _Post(
          souvenir: souvenir,
          enregistre: enregistres.contains(souvenir.id),
          signal: signal,
          onReagir: () => onReagir(souvenir),
          onOuvrirCommentaires: () => onOuvrirCommentaires(souvenir),
          onBasculerEnregistrement: () => onBasculerEnregistrement(souvenir.id),
          onOuvrirCarte: onOuvrirCarte,
          onOuvrirInstants: (signal?.aDesInstants ?? false)
              ? () => onOuvrirInstants(souvenir.id)
              : null,
          onAjouterInstant: (souvenir.estAMoi && (signal?.fenetreCreationOuverte ?? false))
              ? () => onAjouterInstant(souvenir.id)
              : null,
        );
      },
    );
  }
}

class _BarreSuperieure extends StatelessWidget {
  const _BarreSuperieure({
    required this.futurDemandes,
    required this.onAjouterAmis,
    required this.onNotifications,
    required this.onPeriode,
  });

  final Future<int> futurDemandes;
  final VoidCallback onAjouterAmis;
  final VoidCallback onNotifications;
  final VoidCallback onPeriode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        TablTokens.espaceS,
        TablTokens.espaceM,
        TablTokens.espaceS,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tabl.',
                  style: TablTokens.titreAffichage.copyWith(
                    fontSize: 26,
                    letterSpacing: -0.5,
                    height: 1,
                  ),
                ),
                TextButton(
                  onPressed: onPeriode,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: TablTokens.texteDoux,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ces 30 derniers jours', style: TablTokens.legende),
                      const SizedBox(width: TablTokens.espaceXs),
                      const Icon(Icons.expand_more_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<int>(
            future: futurDemandes,
            builder: (context, snapshot) {
              return _IconeCirculaire(
                icone: Icons.person_add_alt_1_outlined,
                pastille: (snapshot.data ?? 0) > 0,
                onPresse: onAjouterAmis,
              );
            },
          ),
          const SizedBox(width: TablTokens.espaceS),
          _IconeCirculaire(
            icone: Icons.notifications_none_rounded,
            pastille: false,
            onPresse: onNotifications,
          ),
        ],
      ),
    );
  }
}

/// Bouton rond translucide utilisé pour les actions du haut de Feed —
/// mêmes proportions et couleurs que le prototype (38×38, contour très
/// discret, pastille dorée si [pastille]).
class _IconeCirculaire extends StatelessWidget {
  const _IconeCirculaire({
    required this.icone,
    required this.pastille,
    required this.onPresse,
  });

  final IconData icone;
  final bool pastille;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: TablTokens.texte.withValues(alpha: 0.03),
          shape: CircleBorder(
            side: BorderSide(color: TablTokens.texte.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              onPressed: onPresse,
              icon: Icon(icone, size: 19, color: TablTokens.texte),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
        if (pastille)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TablTokens.primaire,
                border: Border.all(color: TablTokens.fond, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _EtatVide extends StatelessWidget {
  const _EtatVide({required this.onAjouterAmis});

  final VoidCallback onAjouterAmis;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TablTokens.espaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Votre feed est encore vide.',
              textAlign: TextAlign.center,
              style: TablTokens.titreAffichage.copyWith(fontSize: 24),
            ),
            const SizedBox(height: TablTokens.espaceM),
            Text(
              "Les bonnes adresses prennent vie lorsqu'elles sont partagées "
              'avec les personnes qui comptent vraiment.',
              textAlign: TextAlign.center,
              style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
            ),
            const SizedBox(height: TablTokens.espaceXl),
            TablBouton(libelle: 'Ajouter une connexion', onPresse: onAjouterAmis),
          ],
        ),
      ),
    );
  }
}

class _PiedDeFeed extends StatelessWidget {
  const _PiedDeFeed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TablTokens.espaceL,
        vertical: TablTokens.espaceL,
      ),
      child: Column(
        children: [
          Text(
            'Vous êtes à jour.',
            style: TablTokens.titreAffichage.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// Un moment dans le Feed — pas de carte encadrée : seule la photo est
/// arrondie, le reste s'affiche directement sur le fond de l'écran,
/// comme dans le prototype.
class _Post extends StatelessWidget {
  const _Post({
    required this.souvenir,
    required this.enregistre,
    required this.onReagir,
    required this.onOuvrirCommentaires,
    required this.onBasculerEnregistrement,
    required this.onOuvrirCarte,
    this.signal,
    this.onOuvrirInstants,
    this.onAjouterInstant,
  });

  final SouvenirFeed souvenir;
  final bool enregistre;
  final VoidCallback onReagir;
  final VoidCallback onOuvrirCommentaires;
  final VoidCallback onBasculerEnregistrement;
  final VoidCallback onOuvrirCarte;

  /// `null` : pas d'Instants sur ce post, ou fonctionnalité désactivée
  /// (megaprompt Bloc 2, règle 52).
  final SignalInstants? signal;

  /// `null` s'il n'y a aucun Instant actif à consulter.
  final VoidCallback? onOuvrirInstants;

  /// `null` si ce n'est pas mon post, ou si la fenêtre de création est
  /// fermée (règle 3-4).
  final VoidCallback? onAjouterInstant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL,
              0,
              TablTokens.espaceL,
              10,
            ),
            child: Row(
              children: [
                _Avatar(pseudo: souvenir.auteurPseudo),
                const SizedBox(width: TablTokens.espaceS),
                Expanded(
                  child: Text(
                    souvenir.auteurPseudo,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.corps.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  _dateLisible(souvenir.dateVisite),
                  style: TablTokens.legende.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: AspectRatio(
                    aspectRatio: 1 / 1.06,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: TablTokens.surface),
                        if (souvenir.photoUrl != null)
                          Image.network(
                            souvenir.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) =>
                                const SizedBox(),
                          ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.18),
                                  Colors.black.withValues(alpha: 0.62),
                                  Colors.black.withValues(alpha: 0.9),
                                ],
                                stops: const [0.4, 0.62, 0.83, 1.0],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 13,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: onOuvrirCarte,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 15,
                                      color: TablTokens.primaire,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        souvenir.restaurantNom,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFF8F4EE),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: onOuvrirCarte,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 22, top: 1),
                                  child: Text(
                                    souvenir.ville,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Colors.white.withValues(alpha: 0.64),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (souvenir.emotion != null)
                  Positioned(
                    left: 10,
                    bottom: -19,
                    child: Container(
                      width: 37,
                      height: 37,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TablTokens.fond.withValues(alpha: 0.62),
                        border: Border.all(
                          color: TablTokens.primaire.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        souvenir.emotion!.emoji,
                        style: const TextStyle(fontSize: 19),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL + TablTokens.espaceXs,
              26,
              TablTokens.espaceL + TablTokens.espaceXs,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (souvenir.legende != null)
                  Text(souvenir.legende!, style: TablTokens.titreAffichage.copyWith(fontSize: 16)),
                if (souvenir.impressions.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final impression in souvenir.impressions.take(2))
                        _PuceImpression(texte: impression),
                      if (souvenir.impressions.length > 2)
                        Text(
                          '+${souvenir.impressions.length - 2}',
                          style: TablTokens.legende,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    _ActionTabler(
                      actif: souvenir.jaiReagi,
                      onPresse: onReagir,
                    ),
                    _ActionTexte(
                      icone: Icons.mode_comment_outlined,
                      libelle: 'Commenter',
                      onPresse: onOuvrirCommentaires,
                    ),
                    const Spacer(),
                    _ActionTexte(
                      icone: enregistre
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      libelle: enregistre ? 'Enregistrée' : 'Enregistrer',
                      actif: enregistre,
                      onPresse: onBasculerEnregistrement,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _libelleReactions(souvenir),
                  style: TablTokens.legende.copyWith(
                    color: TablTokens.texteDoux.withValues(alpha: 0.9),
                  ),
                ),
                if (signal != null || onAjouterInstant != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (signal != null && signal!.aDesInstants)
                        TablSignalInstants(
                          total: signal!.total,
                          nonVus: signal!.nonVus,
                          onPresse: onOuvrirInstants ?? () {},
                        ),
                      if (signal != null &&
                          signal!.aDesInstants &&
                          onAjouterInstant != null)
                        const SizedBox(width: TablTokens.espaceM),
                      if (onAjouterInstant != null)
                        TablBoutonAjouterInstant(onPresse: onAjouterInstant!),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Reprend l'algorithme `proofText` du prototype : jamais un chiffre
  /// brut mis en avant, toujours une phrase ("a aimé"/"ont aimé"/"avez
  /// aimé"/"Personne n'a encore aimé").
  String _libelleReactions(SouvenirFeed s) {
    if (s.nombreReactions == 0) return "Personne n'a encore aimé";
    final verbe = s.jaiReagi
        ? 'avez aimé'
        : (s.nombreReactions > 1 ? 'ont aimé' : 'a aimé');
    final noms = s.premieresReactions;
    if (noms.isEmpty) return verbe;
    final reste = s.nombreReactions - noms.length;
    final tete = noms.join(', ');
    return reste > 0
        ? '$tete et $reste autre${reste > 1 ? 's' : ''} $verbe'
        : '$tete $verbe';
  }

  String _dateLisible(DateTime date) {
    return '${date.day} ${_moisAnnee[date.month - 1]}';
  }
}

class _PuceImpression extends StatelessWidget {
  const _PuceImpression({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: TablTokens.texte.withValues(alpha: 0.075)),
        color: TablTokens.texte.withValues(alpha: 0.022),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 11.5,
          color: TablTokens.texte.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Bouton "J'aime" : reprend l'animation cloche + cœur déjà en place
/// (identité de marque), avec le libellé dynamique du prototype
/// ("J'aime" / "Aimé").
class _ActionTabler extends StatelessWidget {
  const _ActionTabler({required this.actif, required this.onPresse});

  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: TablTokens.espaceS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablBoutonReaction(actif: actif, onPresse: onPresse),
          Text(
            actif ? 'Aimé' : "J'aime",
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
              color: actif ? TablTokens.primaire : TablTokens.texteDoux,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTexte extends StatelessWidget {
  const _ActionTexte({
    required this.icone,
    required this.libelle,
    required this.onPresse,
    this.actif = false,
  });

  final IconData icone;
  final String libelle;
  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? TablTokens.primaire : TablTokens.texteDoux;
    return TextButton.icon(
      onPressed: onPresse,
      style: TextButton.styleFrom(
        foregroundColor: couleur,
        padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceXs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icone, size: 19, color: couleur),
      label: Text(
        libelle,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: actif ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Une expérience candidate à "À table maintenant" — le souvenir Feed
/// déjà chargé, plus son signal Instants.
class _CandidatATableMaintenant {
  const _CandidatATableMaintenant({required this.souvenir, required this.signal});

  final SouvenirFeed souvenir;
  final SignalInstants signal;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.pseudo});

  final String pseudo;

  @override
  Widget build(BuildContext context) {
    final initiale = pseudo.isEmpty ? '?' : pseudo[0].toUpperCase();
    return CircleAvatar(
      radius: 12,
      backgroundColor: TablTokens.primaire.withValues(alpha: 0.85),
      child: Text(
        initiale,
        style: TablTokens.legende.copyWith(
          fontSize: 11,
          color: TablTokens.texteSurPrimaire,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
