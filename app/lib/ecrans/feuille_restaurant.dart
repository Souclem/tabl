import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'actions_publications.dart';
import 'feuille_demander_avis.dart';

/// Ouvre la fiche d'un restaurant, en page : d'où qu'on vienne (Explorer,
/// Feed, profil), c'est la même. Voir [FicheRestaurant].
Future<void> ouvrirFeuilleRestaurant(
  BuildContext context, {
  required String nom,
  required String sousTitre,
  required SouvenirService souvenirService,
  AbonnementService? abonnementService,
  TableService? tableService,
  AvisService? avisService,
  String? restaurantId,
  String? resume,
  String? photoUrl,
  bool estEnvie = false,
  Future<String> Function()? entrerDansTabl,
  VoidCallback? onVoirSurLaCarte,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => FicheRestaurant(
        nom: nom,
        sousTitre: sousTitre,
        resume: resume,
        photoUrl: photoUrl,
        restaurantId: restaurantId,
        estEnvie: estEnvie,
        entrerDansTabl: entrerDansTabl,
        souvenirService: souvenirService,
        abonnementService: abonnementService,
        tableService: tableService,
        avisService: avisService,
        onVoirSurLaCarte: onVoirSurLaCarte,
      ),
    ),
  );
}

/// La fiche d'un restaurant, d'après le prototype : sa photo en grand,
/// Garder · Proposer · Carte, puis ce que mon cercle en dit — l'avis du
/// cercle sur 5, qui le connaît, qui y retourne, qui l'a découvert le
/// premier —, mon histoire ici, ce qui ressort, et les moments de mon
/// cercle, qu'on agrandit sur place comme dans le Feed.
class FicheRestaurant extends StatefulWidget {
  const FicheRestaurant({
    super.key,
    required this.nom,
    required this.sousTitre,
    required this.souvenirService,
    this.abonnementService,
    this.tableService,
    this.avisService,
    this.resume,
    this.photoUrl,
    this.restaurantId,
    this.estEnvie = false,
    this.entrerDansTabl,
    this.onVoirSurLaCarte,
  });

  final String nom;

  /// "Italien · Rue du Pont 16, Liège".
  final String sousTitre;

  /// "Emma et 2 autres y sont allés", si connu.
  final String? resume;

  /// Une photo déjà connue, en attendant celles des moments.
  final String? photoUrl;
  final SouvenirService souvenirService;

  /// Pour ouvrir le profil des proches.
  final AbonnementService? abonnementService;

  /// Pour « Proposer » à une Table. `null` : pas de bouton.
  final TableService? tableService;

  /// Pour « Demander » un avis à ceux qui y sont allés. `null` : pas de
  /// bouton.
  final AvisService? avisService;

  /// `null` pour un lieu qui n'est encore que dans l'annuaire : aucun avis.
  final String? restaurantId;
  final bool estEnvie;

  /// Pour un lieu de l'annuaire : le fait entrer dans Tabl et renvoie son
  /// identifiant (nécessaire pour le garder).
  final Future<String> Function()? entrerDansTabl;

  /// « Carte » : le montre sur la carte. `null` : pas de bouton.
  final VoidCallback? onVoirSurLaCarte;

  @override
  State<FicheRestaurant> createState() => _FicheRestaurantState();
}

class _FicheRestaurantState extends State<FicheRestaurant>
    with ActionsPublications<FicheRestaurant> {
  late String? _restaurantId = widget.restaurantId;
  late bool _estEnvie = widget.estEnvie;
  bool _envieEnCours = false;
  bool _chargement = true;
  bool _erreur = false;
  List<ResumeTable> _tables = const [];

  @override
  SouvenirService get souvenirService => widget.souvenirService;

  @override
  AbonnementService? get abonnementService => widget.abonnementService;

  @override
  void initState() {
    super.initState();
    recharger();
    _chargerTables();
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
      final moments = await widget.souvenirService.souvenirsDuRestaurant(id);
      if (!mounted) return;
      setState(() {
        souvenirs = moments;
        _chargement = false;
        _erreur = false;
      });
    } catch (e) {
      debugPrint('FicheRestaurant: $e');
      if (mounted) {
        setState(() {
          _erreur = true;
          _chargement = false;
        });
      }
    }
  }

  Future<void> _chargerTables() async {
    try {
      final tables = await widget.tableService?.mesTables() ?? const [];
      if (mounted) setState(() => _tables = tables);
    } catch (e) {
      debugPrint('FicheRestaurant: tables : $e');
    }
  }

  Future<void> _basculerEnvieRestaurant() async {
    if (_envieEnCours) return;
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
      afficherMessage(
        context,
        envie ? 'Gardée dans vos envies.' : 'Retirée de vos envies.',
      );
    } catch (e) {
      debugPrint('FicheRestaurant: envie : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _envieEnCours = false);
    }
  }

  /// La ville, celle de la fiche (« Italien · Rue du Pont 16, Liège » →
  /// « Liège »), pour proposer le restaurant à une Table.
  String get _ville {
    final morceaux = widget.sousTitre.split(',');
    return morceaux.length > 1 ? morceaux.last.trim() : '';
  }

  Future<void> _proposer() async {
    final c = TablCouleurs.of(context);
    final service = widget.tableService;
    if (service == null || _tables.isEmpty) return;
    final table = await showModalBottomSheet<ResumeTable>(
      context: context,
      backgroundColor: TablCouleurs.of(context).surfaceBasse,
      showDragHandle: true,
      builder: (contexte) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            0,
            TablTokens.espaceL - 4,
            TablTokens.espaceM,
          ),
          children: [
            Text(
              'Proposer ${widget.nom}',
              style: c.titreAffichage.copyWith(fontSize: 24),
            ),
            const SizedBox(height: 4),
            Text(
              'À quelle Table ? Elle répondra GO ou non, puis on trouvera la date.',
              style: c.legende,
            ),
            const SizedBox(height: TablTokens.espaceM),
            for (final t in _tables)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(
                  t.emoji ?? '🍽',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(t.nom, style: c.corps),
                trailing: Icon(Icons.chevron_right_rounded, color: c.texteDoux),
                onTap: () => Navigator.of(contexte).pop(t),
              ),
          ],
        ),
      ),
    );
    if (table == null || !mounted) return;
    try {
      final resultat = await service.proposer(
        tableId: table.id,
        nomRestaurant: widget.nom,
        ville: _ville,
      );
      if (!mounted) return;
      afficherMessage(
        context,
        resultat.dejaExistante
            ? 'Déjà proposé à ${table.nom}.'
            : 'Proposé à ${table.nom}.',
      );
    } catch (e) {
      debugPrint('FicheRestaurant: proposer : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  /// La liste de ceux qui le connaissent (ou y retournent).
  void _voirProches(String titre, List<ProcheFiche> proches) {
    final c = TablCouleurs.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TablCouleurs.of(context).surfaceBasse,
      showDragHandle: true,
      builder: (contexte) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            0,
            TablTokens.espaceL - 4,
            TablTokens.espaceM,
          ),
          children: [
            Text(titre, style: c.titreAffichage.copyWith(fontSize: 24)),
            const SizedBox(height: TablTokens.espaceS),
            for (final p in proches)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TablAvatar(
                  pseudo: p.pseudo,
                  photoUrl: p.photoUrl,
                  rayon: 20,
                ),
                title: Text(p.pseudo, style: c.corps),
                subtitle: Text(
                  p.fois == 1 ? 'Une fois' : '${p.fois} fois',
                  style: c.legende,
                ),
                onTap: abonnementService == null
                    ? null
                    : () {
                        Navigator.of(contexte).pop();
                        ouvrirProfilDe(p.id, p.pseudo);
                      },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final moments = souvenirs ?? const <SouvenirFeed>[];
    final r = resumerFiche(moments);
    final note = r.note;
    final maintenant = DateTime.now();
    final derniere = r.maDerniere;
    final detailAvis = [
      if (r.avis > 0) r.avis == 1 ? '1 avis' : '${r.avis} avis',
      if (r.sansAvis > 0)
        r.sansAvis == 1
            ? '1 passage sans avis'
            : '${r.sansAvis} passages sans avis',
    ].join(' · ');
    final premiere = r.premiereDecouverte;
    return Scaffold(
      backgroundColor: c.fond,
      body: ListView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom + TablTokens.espaceXl,
        ),
        children: [
          TablHerosFiche(
            nom: widget.nom,
            sousTitre: widget.sousTitre,
            photoUrl: r.photoUrl ?? widget.photoUrl,
            mention: r.mesFois >= 3
                ? 'Votre adresse · ${r.mesFois} fois'
                : null,
            onRetour: () => Navigator.of(context).pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceL - 4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TablActionsFiche(
                  actions: [
                    ActionFiche(
                      icone: _estEnvie
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      libelle: _estEnvie ? 'Gardée' : 'Garder',
                      active: _estEnvie,
                      onPresse: _basculerEnvieRestaurant,
                    ),
                    if (widget.tableService != null && _tables.isNotEmpty)
                      ActionFiche(
                        icone: Icons.person_add_alt_1_outlined,
                        libelle: 'Proposer',
                        onPresse: _proposer,
                      ),
                    if (widget.avisService != null &&
                        _restaurantId != null &&
                        r.connaissent.isNotEmpty)
                      ActionFiche(
                        icone: Icons.chat_bubble_outline_rounded,
                        libelle: 'Demander',
                        onPresse: () => demanderUnAvis(
                          context,
                          avisService: widget.avisService!,
                          restaurantId: _restaurantId!,
                          nom: widget.nom,
                          detail: widget.sousTitre,
                          proches: r.connaissent,
                        ),
                      ),
                    if (widget.onVoirSurLaCarte != null)
                      ActionFiche(
                        icone: Icons.map_outlined,
                        libelle: 'Carte',
                        onPresse: () {
                          Navigator.of(context).pop();
                          widget.onVoirSurLaCarte!();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: TablTokens.espaceM),
                if (_erreur)
                  const _Message(texte: messageErreurGenerique)
                else if (_chargement)
                  Padding(
                    padding: EdgeInsets.all(TablTokens.espaceXl),
                    child: Center(
                      child: CircularProgressIndicator(color: c.primaire),
                    ),
                  )
                else if (r.estVide)
                  const _Message(
                    texte:
                        'Personne de votre cercle n\'y est encore allé. '
                        'Gardez-la pour ne pas l\'oublier.',
                  )
                else ...[
                  if (r.connaissent.isNotEmpty) ...[
                    TablAvisCercle(
                      note: note == null ? null : noteLisible(note),
                      emoji: r.emojiDominant,
                      detailAvis: detailAvis.isEmpty
                          ? 'Aucun ressenti donné'
                          : detailAvis,
                      connaissent: r.connaissent.length,
                      visagesConnaissent: [
                        for (final p in r.connaissent.take(3))
                          BullePersonne(pseudo: p.pseudo, photoUrl: p.photoUrl),
                      ],
                      yRetournent: r.yRetournent.length,
                      onConnaissent: () => _voirProches(
                        r.connaissent.length == 1
                            ? 'La connaît'
                            : 'Ils la connaissent',
                        r.connaissent,
                      ),
                      onYRetournent: r.yRetournent.isEmpty
                          ? null
                          : () =>
                                _voirProches('Ils y retournent', r.yRetournent),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (premiere != null) ...[
                    TablPremiereDecouverte(
                      visage: BullePersonne(
                        pseudo: premiere.proche.pseudo,
                        photoUrl: premiere.proche.photoUrl,
                      ),
                      annee: '${premiere.annee}',
                      onPresse: abonnementService == null
                          ? null
                          : () => ouvrirProfilDe(
                              premiere.proche.id,
                              premiere.proche.pseudo,
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TablMonHistoireFiche(
                    fois: r.mesFois,
                    depuis: derniere == null
                        ? null
                        : tempsDepuis(derniere, maintenant),
                    detail: monHistoireIci(r),
                  ),
                  if (r.ceQuiRessort.isNotEmpty) ...[
                    const SizedBox(height: TablTokens.espaceL),
                    const TablEtiquetteFiche(texte: 'Ce qui ressort'),
                    const SizedBox(height: TablTokens.espaceM - 4),
                    TablCeQuiRessort(impressions: r.ceQuiRessort),
                  ],
                  const SizedBox(height: TablTokens.espaceL),
                  TablEtiquetteFiche(
                    texte: moments.length == 1
                        ? 'Le moment du cercle ici'
                        : 'Les moments du cercle ici',
                  ),
                  const SizedBox(height: TablTokens.espaceS),
                ],
              ],
            ),
          ),
          if (!_chargement && !_erreur)
            for (final m in parDateDecroissante(moments))
              publicationDepliable(
                m,
                contexte: ContextePublication.feed,
                titreAuteur: true,
                // On est déjà sur ce restaurant.
                onOuvrirLieu: () {},
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
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceXl),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: c.titreAffichage.copyWith(fontSize: 19, height: 1.35),
      ),
    );
  }
}
