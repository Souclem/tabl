import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_explorer.dart';
import 'ecran_gerer_table.dart';
import 'ecran_proposition_table.dart';

/// L'écran d'une Table (megaprompt Bloc 3) : 3 onglets fixes, dans cet
/// ordre — Notre histoire / On y va ? / À découvrir. Ouverture manuelle
/// toujours sur Notre histoire (règle 3) : ce raccord-ci n'a pas de
/// deep-link, [tabInitial] existe seulement pour les tests et un futur
/// raccord notification.
class EcranTable extends StatefulWidget {
  const EcranTable({
    super.key,
    required this.tableId,
    required this.tableService,
    required this.abonnementService,
    this.carteService,
    this.tabInitial = 0,
  });

  final String tableId;
  final TableService tableService;
  final AbonnementService abonnementService;

  /// `null` par défaut : construit à la demande à partir de
  /// `TablBackend.client` (même principe que `EcranPrincipal.carteService`)
  /// — seulement utilisé pour "Voir sur la carte" et "Garder" en
  /// "À découvrir", jamais au premier affichage.
  final CarteService? carteService;
  final int tabInitial;

  @override
  State<EcranTable> createState() => _EcranTableState();
}

class _EcranTableState extends State<EcranTable> {
  static const _libellesTabs = ['Notre histoire', 'On y va ?', 'À découvrir'];

  late int _tab = widget.tabInitial;

  bool _chargement = true;
  bool _erreur = false;
  GroupeTable? _table;
  List<ExperienceHistoireTable> _experiences = const [];
  List<RecurrenceTable> _laOuOnRevient = const [];
  List<PropositionTable> _propositions = const [];
  List<DecouverteTable> _decouvertes = const [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = false;
    });
    try {
      final resultats = await Future.wait([
        widget.tableService.table(widget.tableId),
        widget.tableService.histoire(widget.tableId),
        widget.tableService.propositions(widget.tableId),
        widget.tableService.decouvertes(widget.tableId),
      ]);
      if (!mounted) return;
      final histoire =
          resultats[1] as ({List<ExperienceHistoireTable> experiences, List<RecurrenceTable> laOuOnRevient});
      setState(() {
        _table = resultats[0] as GroupeTable;
        _experiences = histoire.experiences;
        _laOuOnRevient = histoire.laOuOnRevient;
        _propositions = resultats[2] as List<PropositionTable>;
        _decouvertes = resultats[3] as List<DecouverteTable>;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _chargement = false;
        _erreur = true;
      });
    }
  }

  CarteService get _carteService =>
      widget.carteService ?? CarteServiceSupabase(TablBackend.client);

  void _voirSurLaCarte() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranExplorer(
          carteService: _carteService,
          abonnementService: widget.abonnementService,
          raccourcisVillesService: RaccourcisVillesServicePreferences(),
          entitlementService: const EntitlementServiceGratuit(),
        ),
      ),
    );
  }

  Future<void> _proposer() async {
    final saisie = await showDialog<({String nom, String ville})>(
      context: context,
      builder: (_) => const _DialogueProposerRestaurant(),
    );
    if (saisie == null) return;
    final resultat = await widget.tableService.proposer(
      tableId: widget.tableId,
      nomRestaurant: saisie.nom,
      ville: saisie.ville,
    );
    if (!mounted) return;
    if (resultat.dejaExistante) {
      afficherMessage(
        context,
        '${resultat.proposition.restaurantNom} est déjà proposé dans cette Table.',
      );
    }
    await _charger();
  }

  Future<void> _repondre(String propositionId, bool go) async {
    await widget.tableService.repondreProposition(propositionId, go: go);
    await _charger();
  }

  Future<void> _ouvrirProposition(String propositionId) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EcranPropositionTable(
          propositionId: propositionId,
          tableService: widget.tableService,
        ),
      ),
    );
    await _charger();
  }

  Future<void> _basculerGarder(String restaurantId, bool garder) async {
    await _carteService.basculerGarder(restaurantId, garder: garder);
    await _charger();
  }

  Future<void> _gererLaTable() async {
    final table = _table;
    if (table == null) return;
    // `true` seulement si l'utilisateur a quitté ou supprimé la Table
    // (règle 56) — dans ce cas la Table n'a plus de raison d'exister
    // pour lui, on ne recharge pas, on repart directement à la liste.
    final quitteOuSupprimee = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EcranGererTable(
          table: table,
          tableService: widget.tableService,
          abonnementService: widget.abonnementService,
        ),
      ),
    );
    if (!mounted) return;
    if (quitteOuSupprimee ?? false) {
      Navigator.of(context).pop();
    } else {
      await _charger();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_chargement) {
      return const Scaffold(
        backgroundColor: TablTokens.fond,
        body: Center(child: CircularProgressIndicator(color: TablTokens.primaire)),
      );
    }
    final table = _table;
    if (_erreur || table == null) {
      return Scaffold(
        backgroundColor: TablTokens.fond,
        body: SafeArea(
          child: Column(
            children: [
              _boutonRetourSeul(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Message sobre, pas de crash, pas de fuite de nom/membres
                      // (règle 89) — couvre aussi bien "supprimée" que "hors
                      // ligne"/"non autorisé".
                      const Text(
                        'Cette Table n\'est plus disponible.',
                        style: TablTokens.corps,
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      OutlinedButton(onPressed: _charger, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TablBoutonRetour(onPresse: () => Navigator.of(context).pop()),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: TablTokens.texteDoux),
                    tooltip: 'Gérer la Table',
                    onPressed: _gererLaTable,
                  ),
                ],
              ),
            ),
            _entete(table),
            TablTabsTable(
              options: _libellesTabs,
              selectionne: _tab,
              onSelection: (i) => setState(() => _tab = i),
            ),
            const Divider(color: TablTokens.bordure, height: 1),
            Expanded(child: _contenuTab(table)),
          ],
        ),
      ),
    );
  }

  Widget _boutonRetourSeul() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceM,
        0,
      ),
      child: Row(
        children: [TablBoutonRetour(onPresse: () => Navigator.of(context).pop())],
      ),
    );
  }

  Widget _entete(GroupeTable table) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        TablTokens.espaceS,
        TablTokens.espaceL,
        TablTokens.espaceM,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: TablCouvertureTable(
              urls: table.couverturePhotoUrl != null
                  ? [table.couverturePhotoUrl!]
                  : table.mosaiquePhotosUrls,
            ),
          ),
          const SizedBox(width: TablTokens.espaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.emoji == null ? table.nom : '${table.nom} ${table.emoji}',
                  style: TablTokens.titre,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  table.nombreMembresActifs == 1
                      ? '1 personne'
                      : '${table.nombreMembresActifs} personnes',
                  style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
                ),
                TextButton(
                  onPressed: _voirSurLaCarte,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                  child: const Text('Voir sur la carte'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenuTab(GroupeTable table) {
    return switch (_tab) {
      0 => _notreHistoire(),
      1 => _onYVa(),
      _ => _aDecouvrir(),
    };
  }

  Widget _notreHistoire() {
    if (_experiences.isEmpty) {
      return _etatVide(
        'Votre histoire commence ici.',
        'Les restaurants partagés dans cette Table apparaîtront ici.',
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceL),
      children: [
        if (_laOuOnRevient.isNotEmpty) ...[
          const SizedBox(height: TablTokens.espaceM),
          Text('Là où l\'on revient', style: TablTokens.sousTitre),
          for (final r in _laOuOnRevient)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceXs),
              child: Text(
                '${r.restaurantNom} · ${r.nombreFois} fois ensemble',
                style: TablTokens.corps,
              ),
            ),
          const SizedBox(height: TablTokens.espaceM),
        ],
        Text('Nos moments', style: TablTokens.sousTitre),
        for (final e in _experiences)
          TablLigneExperienceHistoire(
            photoUrl: e.photoUrl,
            restaurantNom: e.restaurantNom,
            ville: e.ville,
            dateLisible: _dateLisible(e.dateVisite),
            auteurPseudo: e.auteurPseudo,
            emoji: e.emotion?.emoji,
          ),
        const SizedBox(height: TablTokens.espaceL),
      ],
    );
  }

  Widget _onYVa() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL,
            TablTokens.espaceM,
            TablTokens.espaceL,
            0,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _proposer,
              child: const Text('Proposer un restaurant'),
            ),
          ),
        ),
        Expanded(
          child: _propositions.isEmpty
              ? _etatVide('Une adresse en tête ?', 'Proposez-la à la Table.')
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceL),
                  children: [
                    for (final p in _propositions)
                      TablLigneProposition(
                        restaurantNom: p.restaurantNom,
                        ville: p.ville,
                        proposePar: p.proposePar,
                        etatTexte: p.etatTexte,
                        active: p.active,
                        nombreGo: p.nombreGo,
                        monInteret: p.monInteret,
                        onGo: () => _repondre(p.id, true),
                        onJePasse: () => _repondre(p.id, false),
                        onTap: () => _ouvrirProposition(p.id),
                      ),
                    const SizedBox(height: TablTokens.espaceL),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _aDecouvrir() {
    if (_decouvertes.isEmpty) {
      return _etatVide(
        'Rien de nouveau pour le moment.',
        'Les adresses connues par les membres apparaîtront ici.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceL),
      itemCount: _decouvertes.length,
      separatorBuilder: (_, _) => const Divider(color: TablTokens.bordure, height: 1),
      itemBuilder: (context, index) {
        final d = _decouvertes[index];
        return TablLigneDecouverte(
          restaurantNom: d.restaurantNom,
          sousTitreLieu: d.quartier == null ? d.ville : '${d.quartier} · ${d.ville}',
          connaisseursTexte: _texteConnaisseurs(d.pseudosConnaisseurs),
          emotions: d.emotionsRepresentatives,
          dejaGarde: d.dejaGardeParMoi,
          onBasculerGarder: (garder) => _basculerGarder(d.restaurantId, garder),
          onVoirSurLaCarte: _voirSurLaCarte,
        );
      },
    );
  }

  Widget _etatVide(String titre, String sousTitre) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(TablTokens.espaceL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titre, style: TablTokens.corps, textAlign: TextAlign.center),
            const SizedBox(height: TablTokens.espaceXs),
            Text(
              sousTitre,
              style: TablTokens.legende.copyWith(color: TablTokens.texteDoux),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _texteConnaisseurs(List<String> pseudos) {
    if (pseudos.length == 1) return '${pseudos[0]} connaît cette adresse';
    if (pseudos.length == 2) {
      return '${pseudos[0]} et ${pseudos[1]} connaissent cette adresse';
    }
    return '${pseudos[0]}, ${pseudos[1]} et ${pseudos.length - 2} autres connaissent cette adresse';
  }

  String _dateLisible(DateTime date) {
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${date.day} ${mois[date.month - 1]} ${date.year}';
  }
}

class _DialogueProposerRestaurant extends StatefulWidget {
  const _DialogueProposerRestaurant();

  @override
  State<_DialogueProposerRestaurant> createState() => _DialogueProposerRestaurantState();
}

class _DialogueProposerRestaurantState extends State<_DialogueProposerRestaurant> {
  final _nom = TextEditingController();
  final _ville = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    _ville.dispose();
    super.dispose();
  }

  bool get _peutValider => _nom.text.trim().isNotEmpty && _ville.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: TablTokens.surface,
      title: const Text('Proposer un restaurant', style: TablTokens.sousTitre),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TablChampTexte(
            libelle: 'Restaurant',
            controleur: _nom,
            indication: 'Bibo',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TablTokens.espaceS),
          TablChampTexte(
            libelle: 'Ville',
            controleur: _ville,
            indication: 'Marbella',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _peutValider
              ? () => Navigator.of(context).pop((
                  nom: _nom.text.trim(),
                  ville: _ville.text.trim(),
                ))
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: TablTokens.primaire,
            foregroundColor: TablTokens.texteSurPrimaire,
          ),
          child: const Text('Proposer'),
        ),
      ],
    );
  }
}
