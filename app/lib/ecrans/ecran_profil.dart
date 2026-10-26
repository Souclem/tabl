import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'contenu_profil.dart';
import 'ecran_accueil.dart';
import 'ecran_aide.dart';
import 'ecran_abonnes.dart';
import 'ecran_choix_souvenir.dart';
import 'feuille_audience.dart';

/// Onglet Profil : en haut, qui on est (photo, prénom, moments, abonnés,
/// abonnements) ; dessous, son journal en grille par mois et son bilan
/// de l'année (voir [ContenuProfil]). Les réglages (profil privé,
/// déconnexion) sont derrière le bouton en haut à droite.
class EcranProfil extends StatefulWidget {
  const EcranProfil({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.utilisateur,
    this.tableService,
    this.retourService,
    this.rechercheLieuService,
    this.positionService,
  });

  final AuthService authService;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;
  final Utilisateur utilisateur;

  /// `null` par défaut : construit à la demande (feuille "Qui peut
  /// voir ?") à partir de `TablBackend.client`, même principe que
  /// `EcranPrincipal.carteService` — ne jamais toucher `TablBackend`
  /// avant que ce soit nécessaire.
  final TableService? tableService;

  /// `null` par défaut : construit à l'ouverture d'« Aide et contact »,
  /// même principe que [tableService].
  final RetourService? retourService;

  /// `null` par défaut : construits à l'ouverture d'« Ajouter un
  /// souvenir », même principe que [tableService].
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil>
    with ActionsPublications<EcranProfil>, ContenuProfil<EcranProfil> {
  bool _enCours = false;

  @override
  String? get prenomProfil => null;

  @override
  void Function(SouvenirFeed)? get optionsMoment => _ouvrirOptions;

  @override
  VoidCallback get onAjouterSouvenir => _ajouterDesSouvenirs;

  /// Le menu « Comment retrouver vos souvenirs ? » ; au retour d'un
  /// souvenir ajouté, ses souvenirs se rechargent et s'affichent.
  Future<void> _ajouterDesSouvenirs() async {
    final ajoute = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EcranChoixSouvenir(
          souvenirService: widget.souvenirService,
          abonnementService: widget.abonnementService,
          tableService: _tableService,
          rechercheLieuService:
              widget.rechercheLieuService ??
              RechercheLieuServiceSupabase(TablBackend.client),
          positionService:
              widget.positionService ?? PositionServiceGeolocator(),
          photosRecentes: [
            for (final s in souvenirs ?? const <SouvenirFeed>[]) ?s.photoUrl,
          ].take(3).toList(),
        ),
      ),
    );
    if (ajoute != true || !mounted) return;
    recharger();
    setState(() => rubrique = RubriqueProfil.souvenirs);
    afficherMessage(context, 'Souvenir ajouté.');
  }

  /// Remplace la photo de l'utilisateur dès qu'il en a choisi une
  /// nouvelle, sans attendre une reconnexion.
  String? _photoUrl;

  late Future<CompteursProfil> _compteurs = _chargerCompteurs();

  /// Ses propres abonnés et abonnements se lisent directement (la base
  /// laisse chacun voir ses relations) : pas besoin de la fonction qui
  /// compte ceux des autres. Le nombre de moments vient de la liste.
  Future<CompteursProfil> _chargerCompteurs() async {
    final (:abonnes, :abonnements) = await widget.abonnementService
        .abonnesEtAbonnements();
    return (
      moments: 0,
      abonnes: abonnes.length,
      abonnements: abonnements.length,
    );
  }

  @override
  AbonnementService get abonnementService => widget.abonnementService;

  // Même principe que le Feed : chargé une fois (l'écran vit dans
  // l'IndexedStack de EcranPrincipal), rechargé seulement sur demande
  // (tirer vers le bas, retour des commentaires ou du partage).
  late Future<List<SouvenirFeed>> _futurSouvenirs = _chargerSouvenirs();

  Future<List<SouvenirFeed>> _chargerSouvenirs() =>
      widget.souvenirService.souvenirsDe(widget.utilisateur.id);

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  void recharger() {
    setState(() {
      _futurSouvenirs = _chargerSouvenirs();
      _compteurs = _chargerCompteurs();
      souvenirs = null;
    });
  }

  // `null` tant que le réglage n'est pas chargé : l'interrupteur reste
  // masqué plutôt que d'afficher une valeur fausse.
  bool? _profilPrive;

  @override
  void initState() {
    super.initState();
    _chargerConfidentialite();
  }

  Future<void> _chargerConfidentialite() async {
    try {
      final prive = await widget.abonnementService.monProfilEstPrive();
      if (mounted) setState(() => _profilPrive = prive);
    } catch (e) {
      debugPrint('EcranProfil: confidentialité : $e');
    }
  }

  /// [rafraichir] : redessine la feuille des réglages, qui ne suit pas
  /// les `setState` de l'écran.
  Future<void> _basculerProfilPrive(
    bool prive, {
    VoidCallback? rafraichir,
  }) async {
    if (!prive) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (contexteDialogue) => AlertDialog(
          backgroundColor: TablTokens.surface,
          title: const Text('Rendre votre profil public ?'),
          content: const Text(
            'Tous les utilisateurs de Tabl pourront voir vos moments '
            'partagés avec "Tout le monde" et vous suivre sans demande. '
            'Les demandes en attente seront acceptées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(contexteDialogue).pop(true),
              child: const Text('Rendre public'),
            ),
          ],
        ),
      );
      if (confirme != true || !mounted) return;
    }
    final avant = _profilPrive;
    setState(() => _profilPrive = prive);
    rafraichir?.call();
    try {
      await widget.abonnementService.definirProfilPrive(prive);
      if (!mounted) return;
      setState(() {
        _nombreDemandes = widget.abonnementService.nombreDemandesEnAttente();
        _compteurs = _chargerCompteurs();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profilPrive = avant);
      rafraichir?.call();
      afficherMessage(context, messageErreurGenerique);
    }
  }

  TableService get _tableService =>
      widget.tableService ?? TableServiceSupabase(TablBackend.client);

  void _ouvrirAide() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranAide(
          retourService:
              widget.retourService ?? RetourServiceSupabase(TablBackend.client),
        ),
      ),
    );
  }

  // Recalculé seulement à la création de l'état et au retour de l'écran
  // Cercle (voir _allerVersAbonnes) — jamais à chaque reconstruction, sans
  // quoi un changement d'onglet dans l'IndexedStack parent ou toute autre
  // reconstruction sans rapport relancerait la requête et ferait
  // clignoter le badge à 0 le temps qu'elle reparte.
  late Future<int> _nombreDemandes = widget.abonnementService
      .nombreDemandesEnAttente();

  Future<void> _allerVersAbonnes({required bool ongletAbonnes}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranAbonnes(
          abonnementService: widget.abonnementService,
          souvenirService: widget.souvenirService,
          ongletAbonnes: ongletAbonnes,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _nombreDemandes = widget.abonnementService.nombreDemandesEnAttente();
      _compteurs = _chargerCompteurs();
    });
  }

  void _ouvrirReglages() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (contexteFeuille) => StatefulBuilder(
        builder: (contexteFeuille, redessiner) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL,
                ),
                child: Text('Réglages', style: TablTokens.titre),
              ),
              const SizedBox(height: TablTokens.espaceS),
              if (_profilPrive != null)
                _InterrupteurProfilPrive(
                  prive: _profilPrive!,
                  onChange: (prive) => _basculerProfilPrive(
                    prive,
                    rafraichir: () {
                      if (contexteFeuille.mounted) redessiner(() {});
                    },
                  ),
                ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL,
                ),
                leading: const Icon(
                  Icons.support_agent_rounded,
                  color: TablTokens.primaire,
                ),
                title: Text('Aide et contact', style: TablTokens.corps),
                subtitle: Text(
                  'Un bug, une idée, une question',
                  style: TablTokens.legende,
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: TablTokens.texteDoux,
                ),
                onTap: () {
                  Navigator.of(contexteFeuille).pop();
                  _ouvrirAide();
                },
              ),
              Padding(
                padding: const EdgeInsets.all(TablTokens.espaceL),
                child: TablBouton(
                  libelle: 'Se déconnecter',
                  enCours: _enCours,
                  onPresse: () {
                    Navigator.of(contexteFeuille).pop();
                    _seDeconnecter();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _modifierProfil() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (contexteFeuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Changer la photo de profil'),
              onTap: () {
                Navigator.of(contexteFeuille).pop();
                _changerPhoto();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changerPhoto() async {
    // Petite et légère : une photo de profil s'affiche au plus en 96 px.
    final fichier = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      maxHeight: 600,
      imageQuality: 85,
    );
    if (fichier == null || !mounted) return;
    try {
      final url = await widget.abonnementService.definirPhotoProfil(
        await fichier.readAsBytes(),
      );
      if (!mounted) return;
      setState(() => _photoUrl = url);
      afficherMessage(context, 'Photo de profil mise à jour.');
    } catch (e) {
      debugPrint('EcranProfil: photo : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  void _ouvrirOptions(SouvenirFeed souvenir) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (contexteSheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Qui peut voir'),
              onTap: () {
                Navigator.of(contexteSheet).pop();
                _modifierAudience(souvenir);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _modifierAudience(SouvenirFeed souvenir) async {
    final ({AudienceSouvenir audience, Set<String> amisTaguesIds}) actuelle;
    try {
      actuelle = await widget.souvenirService.audienceActuelle(souvenir.id);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    final choisie = await ouvrirFeuilleAudience(
      context,
      audienceInitiale: actuelle.audience,
      abonnementService: widget.abonnementService,
      tableService: _tableService,
      amisTaguesIds: actuelle.amisTaguesIds,
    );
    if (choisie == null || !mounted) return;
    try {
      final tablesEnEchec = await widget.souvenirService.modifierAudience(
        souvenir.id,
        choisie,
      );
      if (!mounted) return;
      afficherMessage(
        context,
        tablesEnEchec.isEmpty
            ? 'Audience mise à jour.'
            : 'Mise à jour, mais impossible de partager avec '
                  '${tablesEnEchec.length} Table${tablesEnEchec.length > 1 ? 's' : ''}.',
      );
      recharger();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _seDeconnecter() async {
    setState(() => _enCours = true);
    try {
      await widget.authService.deconnexion();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        EcranAccueil.route(
          widget.authService,
          widget.abonnementService,
          widget.souvenirService,
        ),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: FutureBuilder<List<SouvenirFeed>>(
        future: _futurSouvenirs,
        builder: (context, snapshot) {
          final termine = snapshot.connectionState == ConnectionState.done;
          if (termine && snapshot.hasError) {
            debugPrint(
              'EcranProfil: ${snapshot.error}\n${snapshot.stackTrace}',
            );
          }
          final mesSouvenirs = termine && !snapshot.hasError
              ? (souvenirs ??= snapshot.data!)
              : null;
          return RefreshIndicator(
            color: TablTokens.primaire,
            edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
            onRefresh: () async {
              recharger();
              await _futurSouvenirs;
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: TablEnTeteProfil.hauteurDepliee(
                    context,
                    avecAction: false,
                  ),
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  automaticallyImplyLeading: false,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: TablTokens.espaceM),
                      child: TablBoutonVerre(
                        icone: Icons.tune_rounded,
                        libelle: 'Réglages',
                        onPresse: _ouvrirReglages,
                      ),
                    ),
                  ],
                  flexibleSpace: _EnTete(
                    utilisateur: widget.utilisateur,
                    photoUrl: _photoUrl ?? widget.utilisateur.photoUrl,
                    souvenirs: mesSouvenirs,
                    compteurs: _compteurs,
                    nombreDemandes: _nombreDemandes,
                    onModifier: _modifierProfil,
                    onAbonnes: () => _allerVersAbonnes(ongletAbonnes: true),
                    onAbonnements: () =>
                        _allerVersAbonnes(ongletAbonnes: false),
                  ),
                ),
                if (!termine)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(TablTokens.espaceXl),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: TablTokens.primaire,
                        ),
                      ),
                    ),
                  )
                else if (mesSouvenirs == null)
                  const SliverToBoxAdapter(
                    child: _MessageListe(texte: messageErreurGenerique),
                  )
                else if (mesSouvenirs.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TablTokens.espaceL - 4,
                        TablTokens.espaceL,
                        TablTokens.espaceL - 4,
                        0,
                      ),
                      child: TablInvitationSouvenirs(
                        titre: 'Votre histoire gastronomique commence ici',
                        texte:
                            'Ajoutez vos repas passés : ils se rangent à '
                            'leur date sur votre profil.',
                        libelleBouton: 'Retrouver mes souvenirs',
                        onPresse: _ajouterDesSouvenirs,
                      ),
                    ),
                  )
                else
                  ...slivresJournalEtBilan(mesSouvenirs),
                // La barre de navigation flotte par-dessus (voir
                // EcranPrincipal).
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// L'en-tête de son profil, une fois les chiffres arrivés.
class _EnTete extends StatelessWidget {
  const _EnTete({
    required this.utilisateur,
    required this.photoUrl,
    required this.souvenirs,
    required this.compteurs,
    required this.nombreDemandes,
    required this.onModifier,
    required this.onAbonnes,
    required this.onAbonnements,
  });

  final Utilisateur utilisateur;
  final String? photoUrl;
  final List<SouvenirFeed>? souvenirs;
  final Future<CompteursProfil> compteurs;
  final Future<int> nombreDemandes;
  final VoidCallback onModifier;
  final VoidCallback onAbonnes;
  final VoidCallback onAbonnements;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CompteursProfil>(
      future: compteurs,
      builder: (context, chiffres) {
        if (chiffres.hasError) {
          debugPrint('EcranProfil: compteurs : ${chiffres.error}');
        }
        return FutureBuilder<int>(
          future: nombreDemandes,
          builder: (context, demandes) => TablEnTeteProfil(
            pseudo: utilisateur.pseudo,
            photoUrl: photoUrl,
            couvertureUrl: souvenirs == null
                ? null
                : photoCouverture(souvenirs!),
            onModifier: onModifier,
            compteurs: [
              CompteurProfil(
                nombre: souvenirs?.length,
                libelle: souvenirs?.length == 1 ? 'moment' : 'moments',
              ),
              CompteurProfil(
                nombre: chiffres.data?.abonnes,
                libelle: 'abonnés',
                onPresse: onAbonnes,
                pastille: (demandes.data ?? 0) > 0,
              ),
              CompteurProfil(
                nombre: chiffres.data?.abonnements,
                libelle: 'abonnements',
                onPresse: onAbonnements,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InterrupteurProfilPrive extends StatelessWidget {
  const _InterrupteurProfilPrive({required this.prive, required this.onChange});

  final bool prive;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceM),
      child: SwitchListTile.adaptive(
        value: prive,
        onChanged: onChange,
        activeTrackColor: TablTokens.primaire,
        title: Text('Profil privé', style: TablTokens.corps),
        subtitle: Text(
          prive
              ? 'Seules les personnes que vous acceptez voient vos moments.'
              : 'Tous les utilisateurs de Tabl peuvent voir vos moments '
                    'et vous suivre.',
          style: TablTokens.legende,
        ),
      ),
    );
  }
}

class _MessageListe extends StatelessWidget {
  const _MessageListe({required this.texte});

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
