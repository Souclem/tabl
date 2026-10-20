import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'contenu_profil.dart';

/// Le profil d'une autre personne, présenté comme le sien : en-tête
/// (photo, prénom, moments, abonnés, abonnements, « Suivre »), « Toi &
/// elle » si on a déjà partagé des tables, puis son journal et son bilan
/// (voir [ContenuProfil]).
///
/// Comme Instagram : un profil privé que je ne suis pas ne montre que
/// l'en-tête et "Suivre" ; ses publications restent cachées. Pour le
/// reste, la base ne renvoie que les publications que j'ai le droit de
/// voir (RLS, réglage "Qui peut voir ?" de chacune).
class EcranProfilAutre extends StatefulWidget {
  const EcranProfilAutre({
    super.key,
    required this.profilId,
    required this.pseudo,
    required this.abonnementService,
    required this.souvenirService,
  });

  final String profilId;

  /// Affiché tout de suite, avant que le profil soit chargé.
  final String pseudo;
  final AbonnementService abonnementService;
  final SouvenirService souvenirService;

  @override
  State<EcranProfilAutre> createState() => _EcranProfilAutreState();
}

class _EcranProfilAutreState extends State<EcranProfilAutre>
    with
        ActionsPublications<EcranProfilAutre>,
        ContenuProfil<EcranProfilAutre> {
  ProfilVisite? _profil;
  CompteursProfil? _compteurs;
  DuoProfils? _duo;

  @override
  String? get prenomProfil => _profil?.pseudo ?? widget.pseudo;
  bool _chargement = true;
  bool _erreur = false;
  bool _actionEnCours = false;

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  AbonnementService get abonnementService => widget.abonnementService;

  @override
  void initState() {
    super.initState();
    recharger();
  }

  @override
  void recharger() => _charger();

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final (profil, compteurs) = await (
        widget.abonnementService.profil(widget.profilId),
        _chargerCompteurs(),
      ).wait;
      // Ses moments et les nôtres partent ensemble : on attend la plus
      // lente des deux requêtes, pas leur somme.
      final (publications, mesMomentsAvecLui) = profil.publicationsVisibles
          ? await (
              widget.souvenirService.souvenirsDe(widget.profilId),
              _mesMomentsAvecLui(),
            ).wait
          : (const <SouvenirFeed>[], null);
      final duo = mesMomentsAvecLui == null
          ? null
          : duoAvec(
              sesMoments: publications,
              mesMomentsAvecLui: mesMomentsAvecLui,
            );
      if (!mounted) return;
      setState(() {
        _profil = profil;
        _compteurs = compteurs;
        _duo = duo;
        souvenirs = publications;
        momentsADeux = null;
        _chargement = false;
      });
    } catch (e) {
      debugPrint('EcranProfilAutre: $e');
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  /// Les chiffres ne sont qu'un plus : sans eux (base pas encore à jour,
  /// réseau), le profil s'affiche quand même, avec des tirets.
  Future<CompteursProfil?> _chargerCompteurs() async {
    try {
      return await widget.abonnementService.compteurs(widget.profilId);
    } catch (e) {
      debugPrint('EcranProfilAutre: compteurs : $e');
      return null;
    }
  }

  /// Même principe pour « Toi & elle ».
  Future<List<SouvenirFeed>> _mesMomentsAvecLui() async {
    try {
      return await widget.souvenirService.mesMomentsAvec(widget.profilId);
    } catch (e) {
      debugPrint('EcranProfilAutre: moments à deux : $e');
      return const [];
    }
  }

  Future<void> _suivre(ProfilVisite profil) => _agir(() async {
    final statut = await widget.abonnementService.suivre(profil.id);
    if (!mounted) return;
    // Profil public : abonné tout de suite. Privé : une demande, que
    // l'autre accepte ou refuse.
    setState(() => _profil = profil.copierAvec(statut: statut));
    if (statut == StatutAbonnement.demandeEnvoyee) {
      afficherMessage(context, 'Demande envoyée à ${profil.pseudo}.');
    }
  });

  Future<void> _annulerDemande(ProfilVisite profil) => _agir(() async {
    await widget.abonnementService.arreterDeSuivre(profil.id);
    if (!mounted) return;
    setState(() => _profil = profil.copierAvec(statut: StatutAbonnement.aucun));
  });

  Future<void> _nePlusSuivre(ProfilVisite profil) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        title: Text('Ne plus suivre ${profil.pseudo} ?'),
        content: profil.estPrive
            ? const Text(
                'Son profil est privé : vous ne verrez plus ses moments, '
                'sauf en renvoyant une demande.',
              )
            : null,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: const Text('Ne plus suivre'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    await _agir(() async {
      await widget.abonnementService.arreterDeSuivre(profil.id);
      if (!mounted) return;
      // Un profil privé cache maintenant ses publications.
      _charger();
    });
  }

  Future<void> _agir(Future<void> Function() action) async {
    setState(() => _actionEnCours = true);
    try {
      await action();
    } catch (e) {
      debugPrint('EcranProfilAutre: $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _actionEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = _profil;
    final publications = souvenirs;
    final visibles = profil != null && profil.publicationsVisibles;
    final duo = _duo;
    final pseudo = profil?.pseudo ?? widget.pseudo;
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: RefreshIndicator(
        color: TablTokens.primaire,
        edgeOffset: MediaQuery.paddingOf(context).top + kToolbarHeight,
        onRefresh: _charger,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: TablEnTeteProfil.hauteurDepliee(
                context,
                avecAction: true,
              ),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              automaticallyImplyLeading: false,
              leadingWidth: 44 + TablTokens.espaceM,
              leading: Padding(
                padding: const EdgeInsets.only(left: TablTokens.espaceM),
                child: Center(
                  child: TablBoutonVerre(
                    icone: Icons.arrow_back_rounded,
                    libelle: 'Retour',
                    onPresse: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              flexibleSpace: TablEnTeteProfil(
                pseudo: pseudo,
                photoUrl: profil?.photoUrl,
                couvertureUrl: visibles && publications != null
                    ? photoCouverture(publications)
                    : null,
                avecRetour: true,
                compteurs: [
                  CompteurProfil(
                    // Ce que je peux voir quand ses moments me sont
                    // ouverts, sinon le total publié (comme Instagram).
                    nombre: visibles
                        ? publications?.length
                        : _compteurs?.moments,
                    libelle: 'moments',
                  ),
                  CompteurProfil(
                    nombre: _compteurs?.abonnes,
                    libelle: 'abonnés',
                  ),
                  CompteurProfil(
                    nombre: _compteurs?.abonnements,
                    libelle: 'abonnements',
                  ),
                ],
                action: SizedBox(
                  height: 46,
                  child: profil == null ? null : _boutonSuivi(profil),
                ),
              ),
            ),
            if (_chargement && profil == null)
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
            else if (_erreur || profil == null)
              const SliverToBoxAdapter(
                child: _Message(texte: messageErreurGenerique),
              )
            else if (!profil.publicationsVisibles)
              SliverToBoxAdapter(child: _ProfilPrive(pseudo: profil.pseudo))
            else if (publications == null || publications.isEmpty)
              const SliverToBoxAdapter(
                child: _Message(texte: 'Aucun moment à afficher.'),
              )
            else ...[
              if (duo != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TablTokens.espaceL - 4,
                      TablTokens.espaceS,
                      TablTokens.espaceL - 4,
                      TablTokens.espaceS,
                    ),
                    child: TablCarteDuo(
                      monPseudo: 'Toi',
                      sonPseudo: pseudo,
                      saPhotoUrl: profil.photoUrl,
                      depuis: duo.depuis,
                      resume: duo.resume,
                      onRevoir: () => revoirMomentsADeux(duo.souvenirs),
                    ),
                  ),
                ),
              ...slivresJournalEtBilan(publications),
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: TablTokens.espaceXxl),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boutonSuivi(ProfilVisite profil) {
    final enCours = _actionEnCours;
    switch (profil.statut) {
      case StatutAbonnement.aucun:
      case StatutAbonnement.demandeRecue:
        return FilledButton(
          onPressed: enCours ? null : () => _suivre(profil),
          style: FilledButton.styleFrom(
            backgroundColor: TablTokens.primaire,
            foregroundColor: TablTokens.texteSurPrimaire,
          ),
          child: Text(profil.meSuit ? 'Suivre en retour' : 'Suivre'),
        );
      case StatutAbonnement.demandeEnvoyee:
        return OutlinedButton(
          onPressed: enCours ? null : () => _annulerDemande(profil),
          child: const Text('Demande envoyée'),
        );
      case StatutAbonnement.abonne:
        return OutlinedButton.icon(
          onPressed: enCours ? null : () => _nePlusSuivre(profil),
          icon: const Icon(
            Icons.check_rounded,
            size: 18,
            color: TablTokens.primaire,
          ),
          label: const Text('Abonné'),
        );
    }
  }
}

/// À la place des publications d'un profil privé que je ne suis pas.
class _ProfilPrive extends StatelessWidget {
  const _ProfilPrive({required this.pseudo});

  final String pseudo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Column(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 32,
            color: TablTokens.texteDoux,
          ),
          const SizedBox(height: TablTokens.espaceM),
          const Text('Ce profil est privé', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceXs),
          Text(
            'Suivez $pseudo pour voir ses moments.',
            textAlign: TextAlign.center,
            style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
          ),
        ],
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
