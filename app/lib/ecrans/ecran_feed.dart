import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'ecran_abonnes.dart';
import 'ecran_creer_instant.dart';
import 'ecran_notifications.dart';
import 'ecran_viewer_instants.dart';
import 'gestion_suggestions.dart';

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
    this.notificationService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.memoireSuggestions,
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

  /// Pour la cloche. `null` : pas de pastille, et le service est
  /// construit à l'ouverture des notifications (jamais dans les tests).
  final NotificationService? notificationService;

  /// Pour modifier ses propres moments et choisir qui les voit. `null` :
  /// construits à la demande (jamais dans les tests).
  final TableService? tableService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

  /// Quand la carte des suggestions est apparue pour la dernière
  /// fois. `null` : retenu sur l'appareil.
  final MemoireSuggestions? memoireSuggestions;

  @override
  State<EcranFeed> createState() => _EcranFeedState();
}

class _EcranFeedState extends State<EcranFeed>
    with
        ActionsPublications<EcranFeed>,
        GestionSuggestions<EcranFeed>,
        WidgetsBindingObserver {
  // Calculé une seule fois : cet écran vit dans l'IndexedStack de
  // EcranPrincipal, un changement d'onglet ne doit pas relancer la
  // requête (même raisonnement que le badge de EcranProfil). Mutable
  // (pas `late final`) : une réaction met à jour la liste en place,
  // sans tout recharger.
  late Future<List<SouvenirFeed>> _futurFeed = widget.souvenirService.feed();

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  AbonnementService get abonnementService => widget.abonnementService;

  @override
  TableService? get tableService => widget.tableService;

  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  @override
  PositionService? get positionService => widget.positionService;

  @override
  void recharger() {
    setState(() {
      _futurFeed = widget.souvenirService.feed();
      souvenirs = null;
      _signauxCharges = false;
    });
    _verifierNotifications();
    // La carte reste où elle est ; ses boutons, eux, se remettent à
    // jour (on a pu suivre quelqu'un depuis son profil).
    if (_suggestionsDansLeFeed) chargerSuggestions();
  }

  @override
  Future<void> ouvrirProfilSuggere(String profilId, String pseudo) =>
      ouvrirProfilDe(profilId, pseudo);

  @override
  void apresSuiviSuggere(StatutAbonnement statut) {
    // Un Feed vide se remplit dès qu'on suit quelqu'un de public.
    if (statut == StatutAbonnement.abonne && (souvenirs?.isEmpty ?? false)) {
      recharger();
    }
  }

  /// La place des suggestions a été décidée pour ce Feed.
  bool _suggestionsDecidees = false;

  /// Les suggestions ont leur carte au milieu des publications.
  bool _suggestionsDansLeFeed = false;

  /// Une fois par Feed : un Feed vide montre toujours les suggestions ;
  /// sinon, elles s'y glissent de temps en temps (voir
  /// [suggestionsDuesDansLeFeed]).
  Future<void> _deciderSuggestions(List<SouvenirFeed> souvenirs) async {
    if (_suggestionsDecidees) return;
    _suggestionsDecidees = true;
    final memoire =
        widget.memoireSuggestions ?? MemoireSuggestionsPreferences();
    final maintenant = DateTime.now();
    if (souvenirs.isNotEmpty &&
        !suggestionsDuesDansLeFeed(
          derniereApparition: await memoire.derniereApparition(),
          maintenant: maintenant,
        )) {
      return;
    }
    await chargerSuggestions();
    if (!mounted || souvenirs.isEmpty || (suggestions?.isEmpty ?? true)) {
      return;
    }
    setState(() => _suggestionsDansLeFeed = true);
    await memoire.noterApparition(maintenant);
  }

  /// Du nouveau dans les notifications : la pastille de la cloche.
  bool _notificationsNouvelles = false;

  /// La cloche se revérifie chaque minute tant que l'app est ouverte,
  /// et dès qu'on y revient.
  Timer? _veilleNotifications;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verifierNotifications();
    _veiller();
  }

  @override
  void dispose() {
    _veilleNotifications?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState etat) {
    if (etat == AppLifecycleState.resumed) {
      _verifierNotifications();
      _veiller();
    } else if (etat == AppLifecycleState.paused) {
      _veilleNotifications?.cancel();
    }
  }

  void _veiller() {
    _veilleNotifications?.cancel();
    if (widget.notificationService == null) return;
    _veilleNotifications = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _verifierNotifications(),
    );
  }

  Future<void> _verifierNotifications() async {
    final service = widget.notificationService;
    if (service == null) return;
    try {
      final (:notifications, :vuesLe) = await service.mesNotifications();
      if (!mounted) return;
      setState(
        () => _notificationsNouvelles = aDesNouvelles(
          notifications,
          vuesLe: vuesLe,
        ),
      );
    } catch (e) {
      debugPrint('EcranFeed: notifications : $e');
    }
  }

  Future<void> _ouvrirNotifications() async {
    setState(() => _notificationsNouvelles = false);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranNotifications(
          notificationService:
              widget.notificationService ??
              NotificationServiceSupabase(TablBackend.client),
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
          // Construit seulement ici, au tap sur la cloche.
          avisService: AvisServiceSupabase(TablBackend.client),
          carteService: CarteServiceSupabase(TablBackend.client),
          tableService:
              widget.tableService ?? TableServiceSupabase(TablBackend.client),
        ),
      ),
    );
    if (!mounted) return;
    // Une demande acceptée, un moment ouvert : de quoi revoir le Feed.
    recharger();
  }

  /// Pastille sur l'icône d'ajout d'ami, même source que le badge de
  /// EcranProfil.
  late final Future<int> _futurDemandes = widget.abonnementService
      .nombreDemandesEnAttente();

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
    final souvenirs = this.souvenirs;
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
      final souvenir = souvenirs!.firstWhere((s) => s.id == experienceId);
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
    _chargerSignaux(souvenirs!);
  }

  void _ouvrirSheetATableMaintenant() {
    final candidats = _candidatsATableMaintenant;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablCouleurs.of(context).surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                TablTokens.espaceS,
              ),
              child: Text(
                'À table maintenant',
                style: TablCouleurs.of(context).sousTitre,
              ),
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
    _chargerSignaux(souvenirs!);
  }

  void _allerVersAbonnes() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranAbonnes(
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
        ),
      ),
    );
  }

  void _bientotDisponible() {
    afficherMessage(context, 'Bientôt disponible.');
  }

  Widget _liste(List<SouvenirFeed> souvenirs) {
    final carte = _suggestionsDansLeFeed ? carteSuggestions : null;
    final position = positionSuggestionsDansLeFeed(souvenirs.length);
    return ListView.builder(
      // La barre de navigation flotte par-dessus (voir EcranPrincipal) :
      // une marge basse généreuse évite qu'elle ne masque le dernier post.
      padding: const EdgeInsets.fromLTRB(
        0,
        TablTokens.espaceS,
        0,
        TablTokens.espaceXxl + TablTokens.espaceL,
      ),
      itemCount: souvenirs.length + 1 + (carte == null ? 0 : 1),
      itemBuilder: (context, index) {
        var i = index;
        if (carte != null) {
          if (i == position) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceL),
              child: carte,
            );
          }
          if (i > position) i--;
        }
        if (i == souvenirs.length) {
          return const _PiedDeFeed();
        }
        final souvenir = souvenirs[i];
        final signal = _signaux[souvenir.id];
        return construirePublication(
          souvenir,
          contexte: ContextePublication.feed,
          onOuvrirLieu: () => ouvrirRestaurant(souvenir),
          // Ses propres moments : les modifier, choisir qui les voit,
          // les supprimer, depuis le Feed aussi.
          onOptions: souvenir.estAMoi
              ? () => optionsPublication(souvenir)
              : null,
          signal: signal,
          onOuvrirInstants: (signal?.aDesInstants ?? false)
              ? () => _ouvrirInstants(souvenir.id)
              : null,
          onAjouterInstant:
              (souvenir.estAMoi && (signal?.fenetreCreationOuverte ?? false))
              ? () => _ajouterInstant(souvenir.id)
              : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Scaffold(
      backgroundColor: c.fond,
      body: SafeArea(
        child: Column(
          children: [
            _BarreSuperieure(
              futurDemandes: _futurDemandes,
              onAjouterAmis: _allerVersAbonnes,
              notificationsNouvelles: _notificationsNouvelles,
              onNotifications: _ouvrirNotifications,
              onPeriode: _bientotDisponible,
            ),
            Expanded(
              child: FutureBuilder<List<SouvenirFeed>>(
                future: _futurFeed,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return Center(
                      child: CircularProgressIndicator(color: c.primaire),
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
                        style: c.corps.copyWith(color: c.texteDoux),
                      ),
                    );
                  }

                  // `??=` : on ne réinitialise pas la liste mutable à
                  // chaque rebuild déclenché par une réaction, seulement
                  // au premier chargement (ou après un rechargement
                  // volontaire).
                  final souvenirs = this.souvenirs ??= snapshot.data!;
                  _deciderSuggestions(souvenirs);
                  if (souvenirs.isEmpty) {
                    return _EtatVide(
                      onAjouterAmis: _allerVersAbonnes,
                      suggestions: carteSuggestions,
                    );
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
                      Expanded(child: _liste(souvenirs)),
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

class _BarreSuperieure extends StatelessWidget {
  const _BarreSuperieure({
    required this.futurDemandes,
    required this.onAjouterAmis,
    required this.onNotifications,
    required this.onPeriode,
    this.notificationsNouvelles = false,
  });

  final Future<int> futurDemandes;
  final VoidCallback onAjouterAmis;
  final VoidCallback onNotifications;
  final VoidCallback onPeriode;
  final bool notificationsNouvelles;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
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
                  style: c.titreAffichage.copyWith(
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
                    foregroundColor: c.texteDoux,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ces 30 derniers jours', style: c.legende),
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
            pastille: notificationsNouvelles,
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
    final c = TablCouleurs.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: c.texte.withValues(alpha: 0.03),
          shape: CircleBorder(
            side: BorderSide(color: c.texte.withValues(alpha: 0.1)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 38,
            height: 38,
            child: IconButton(
              onPressed: onPresse,
              icon: Icon(icone, size: 19, color: c.texte),
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
                color: c.primaire,
                border: Border.all(color: c.fond, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class _EtatVide extends StatelessWidget {
  const _EtatVide({required this.onAjouterAmis, this.suggestions});

  final VoidCallback onAjouterAmis;

  /// Des gens à suivre, sous l'invitation ; `null` : personne à proposer.
  final Widget? suggestions;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final invitation = Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Votre feed est encore vide.',
            textAlign: TextAlign.center,
            style: c.titreAffichage.copyWith(fontSize: 24),
          ),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            "Les bonnes adresses prennent vie lorsqu'elles sont partagées "
            'avec les personnes qui comptent vraiment.',
            textAlign: TextAlign.center,
            style: c.corps.copyWith(color: c.texteDoux),
          ),
          const SizedBox(height: TablTokens.espaceXl),
          TablBouton(libelle: 'Trouver des personnes', onPresse: onAjouterAmis),
        ],
      ),
    );
    final suggestions = this.suggestions;
    if (suggestions == null) return Center(child: invitation);
    // La barre de navigation flotte par-dessus : de la marge en bas.
    return LayoutBuilder(
      builder: (context, contraintes) => SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: TablTokens.espaceXxl + TablTokens.espaceL,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: contraintes.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [invitation, suggestions],
          ),
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
            style: TablCouleurs.of(
              context,
            ).titreAffichage.copyWith(fontSize: 20),
          ),
        ],
      ),
    );
  }
}

/// Une expérience candidate à "À table maintenant" — le souvenir Feed
/// déjà chargé, plus son signal Instants.
class _CandidatATableMaintenant {
  const _CandidatATableMaintenant({
    required this.souvenir,
    required this.signal,
  });

  final SouvenirFeed souvenir;
  final SignalInstants signal;
}
