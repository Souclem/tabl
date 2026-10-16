import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'ecran_accueil.dart';
import 'ecran_abonnes.dart';
import 'feuille_audience.dart';

/// Onglet Profil : identité de l'utilisateur, ses propres publications
/// (présentées comme dans le Feed, via le même [TablPublication]), accès
/// aux abonnés et déconnexion.
class EcranProfil extends StatefulWidget {
  const EcranProfil({
    super.key,
    required this.authService,
    required this.abonnementService,
    required this.souvenirService,
    required this.utilisateur,
    this.tableService,
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

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil>
    with ActionsPublications<EcranProfil> {
  bool _enCours = false;

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

  Future<void> _basculerProfilPrive(bool prive) async {
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
    try {
      await widget.abonnementService.definirProfilPrive(prive);
      if (!mounted) return;
      setState(() {
        _nombreDemandes = widget.abonnementService.nombreDemandesEnAttente();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _profilPrive = avant);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  TableService get _tableService =>
      widget.tableService ?? TableServiceSupabase(TablBackend.client);

  // Recalculé seulement à la création de l'état et au retour de l'écran
  // Cercle (voir _allerVersAbonnes) — jamais à chaque reconstruction, sans
  // quoi un changement d'onglet dans l'IndexedStack parent ou toute autre
  // reconstruction sans rapport relancerait la requête et ferait
  // clignoter le badge à 0 le temps qu'elle reparte.
  late Future<int> _nombreDemandes =
      widget.abonnementService.nombreDemandesEnAttente();

  Future<void> _allerVersAbonnes() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EcranAbonnes(abonnementService: widget.abonnementService),
      ),
    );
    if (!mounted) return;
    setState(() {
      _nombreDemandes = widget.abonnementService.nombreDemandesEnAttente();
    });
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
      body: SafeArea(
        child: Stack(
          children: [
            FutureBuilder<List<SouvenirFeed>>(
              future: _futurSouvenirs,
              builder: (context, snapshot) {
                final termine =
                    snapshot.connectionState == ConnectionState.done;
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
                  onRefresh: () async {
                    recharger();
                    await _futurSouvenirs;
                  },
                  child: ListView(
                    // La barre de navigation flotte par-dessus (voir
                    // EcranPrincipal) : marge basse identique au Feed.
                    padding: const EdgeInsets.only(
                      bottom: TablTokens.espaceXxl + TablTokens.espaceL,
                    ),
                    children: [
                      _EnTeteProfil(
                        utilisateur: widget.utilisateur,
                        nombrePublications: mesSouvenirs?.length,
                      ),
                      if (!termine)
                        const Padding(
                          padding: EdgeInsets.all(TablTokens.espaceXl),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: TablTokens.primaire,
                            ),
                          ),
                        )
                      else if (mesSouvenirs == null)
                        _MessageListe(texte: messageErreurGenerique)
                      else if (mesSouvenirs.isEmpty)
                        const _MessageListe(
                          texte: "Vous n'avez encore rien publié.",
                        )
                      else
                        for (final souvenir in mesSouvenirs)
                          construirePublication(
                            souvenir,
                            contexte: ContextePublication.profilPerso,
                            onOuvrirLieu: () => ouvrirRestaurant(souvenir),
                            onOptions: () => _ouvrirOptions(souvenir),
                          ),
                      if (_profilPrive != null)
                        _InterrupteurProfilPrive(
                          prive: _profilPrive!,
                          onChange: _basculerProfilPrive,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(TablTokens.espaceL),
                        child: TablBouton(
                          libelle: 'Se déconnecter',
                          enCours: _enCours,
                          onPresse: _seDeconnecter,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: TablTokens.espaceS,
              right: TablTokens.espaceM,
              child: Row(
                children: [
                  _BoutonAbonnes(
                    nombreDemandes: _nombreDemandes,
                    onPresse: _allerVersAbonnes,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Haut du profil : avatar, pseudo, e-mail et nombre de publications.
class _EnTeteProfil extends StatelessWidget {
  const _EnTeteProfil({
    required this.utilisateur,
    required this.nombrePublications,
  });

  final Utilisateur utilisateur;

  /// `null` tant que la liste n'est pas chargée.
  final int? nombrePublications;

  @override
  Widget build(BuildContext context) {
    final nombre = nombrePublications;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        TablTokens.espaceXxl,
        TablTokens.espaceL,
        TablTokens.espaceXl,
      ),
      child: Column(
        children: [
          TablAvatar(
            pseudo: utilisateur.pseudo,
            photoUrl: utilisateur.photoUrl,
            rayon: 45,
          ),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            utilisateur.pseudo,
            textAlign: TextAlign.center,
            style: TablTokens.titre,
          ),
          const SizedBox(height: TablTokens.espaceXs),
          Text(
            utilisateur.email,
            textAlign: TextAlign.center,
            style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
          ),
          if (nombre != null) ...[
            const SizedBox(height: TablTokens.espaceM),
            Text(
              nombre == 0
                  ? 'Aucun moment'
                  : '$nombre moment${nombre > 1 ? 's' : ''}',
              style: TablTokens.legende,
            ),
          ],
        ],
      ),
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

/// Icône vers l'écran Cercle, avec un badge si des demandes de suivi
/// sont en attente.
class _BoutonAbonnes extends StatelessWidget {
  const _BoutonAbonnes({required this.nombreDemandes, required this.onPresse});

  final Future<int> nombreDemandes;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: nombreDemandes,
      builder: (context, snapshot) {
        final nombre = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: TablTokens.surface,
              shape: const CircleBorder(
                side: BorderSide(color: TablTokens.bordure),
              ),
              clipBehavior: Clip.antiAlias,
              child: IconButton(
                onPressed: onPresse,
                icon: const Icon(Icons.people_outline_rounded, size: 20),
                color: TablTokens.primaire,
                splashRadius: 22,
              ),
            ),
            if (nombre > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  height: 17,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: TablTokens.primaire,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$nombre',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: TablTokens.texteSurPrimaire,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
