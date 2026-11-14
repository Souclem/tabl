import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Ouvre la feuille "Qui peut voir ce moment ?" — la même à la création
/// d'une publication et depuis le "⋯" d'un post déjà publié, jamais une
/// page à part. Retourne l'audience choisie, ou `null` si la feuille est
/// fermée sans valider.
///
/// [amisTaguesIds] : amis tagués comme présents, pour prévenir s'ils
/// ne verront pas le moment (le tag n'élargit jamais l'audience).
///
/// [donnees] : déjà chargées par l'appelant s'il en a besoin lui aussi
/// (le formulaire de publication), sinon chargées ici.
Future<AudienceSouvenir?> ouvrirFeuilleAudience(
  BuildContext context, {
  required AudienceSouvenir audienceInitiale,
  required AbonnementService abonnementService,
  TableService? tableService,
  Future<DonneesAudience>? donnees,
  Set<String> amisTaguesIds = const {},
}) {
  final c = TablCouleurs.of(context);
  return showModalBottomSheet<AudienceSouvenir>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(TablTokens.arrondiL),
      ),
    ),
    builder: (_) => _FeuilleAudience(
      audienceInitiale: audienceInitiale,
      donnees:
          donnees ?? chargerDonneesAudience(abonnementService, tableService),
      amisTaguesIds: amisTaguesIds,
    ),
  );
}

/// Tout ce qu'il faut pour afficher la feuille, chargé en une fois.
Future<DonneesAudience> chargerDonneesAudience(
  AbonnementService abonnementService,
  TableService? tableService,
) async {
  final resultats = await Future.wait<Object>([
    abonnementService.monProfilEstPrive(),
    abonnementService.mesAbonnesIds(),
    abonnementService.mesRelations(),
    tableService?.mesTables() ?? Future.value(<ResumeTable>[]),
  ]);
  final tables = resultats[3] as List<ResumeTable>;
  final membres =
      await tableService?.membresActifsParTable([
        for (final t in tables) t.id,
      ]) ??
      const <String, Set<String>>{};
  return DonneesAudience(
    contexte: ContexteAudience(
      profilPrive: resultats[0] as bool,
      abonnesIds: resultats[1] as Set<String>,
      membresParTable: membres,
    ),
    relations: resultats[2] as List<ProfilPublic>,
    tables: tables,
  );
}

class DonneesAudience {
  const DonneesAudience({
    required this.contexte,
    required this.relations,
    required this.tables,
  });

  final ContexteAudience contexte;
  final List<ProfilPublic> relations;
  final List<ResumeTable> tables;
}

class _FeuilleAudience extends StatefulWidget {
  const _FeuilleAudience({
    required this.audienceInitiale,
    required this.donnees,
    required this.amisTaguesIds,
  });

  final AudienceSouvenir audienceInitiale;
  final Future<DonneesAudience> donnees;
  final Set<String> amisTaguesIds;

  @override
  State<_FeuilleAudience> createState() => _FeuilleAudienceState();
}

class _FeuilleAudienceState extends State<_FeuilleAudience> {
  late AudienceSouvenir _audience = widget.audienceInitiale;
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _choisirMode(ModeAudience mode) {
    if (mode == _audience.mode) return;
    // Les personnes choisies n'ont pas le même sens d'un mode à l'autre
    // (autorisées vs exclues) : on repart d'une liste vide.
    setState(() {
      _audience = AudienceSouvenir(mode: mode);
      _recherche.clear();
    });
  }

  void _basculerTable(String id) {
    final ids = {..._audience.tableIds};
    if (!ids.remove(id)) ids.add(id);
    setState(() => _audience = _audience.copierAvec(tableIds: ids));
  }

  void _basculerPersonne(String id) {
    final ids = {..._audience.personneIds};
    if (!ids.remove(id)) ids.add(id);
    setState(() => _audience = _audience.copierAvec(personneIds: ids));
  }

  /// "L'ajouter" sur l'avertissement : l'ajoute en "Seulement…", le
  /// retire des exclusions en "Tout le monde sauf…".
  void _inclureTague(String id) => _basculerPersonne(id);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Le clavier de la recherche ne doit pas masquer la feuille.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: FutureBuilder<DonneesAudience>(
            future: widget.donnees,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('FeuilleAudience: ${snapshot.error}');
                return const _Message(texte: messageErreurGenerique);
              }
              final donnees = snapshot.data;
              if (donnees == null) {
                return Padding(
                  padding: const EdgeInsets.all(TablTokens.espaceXl),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: TablCouleurs.of(context).primaire,
                    ),
                  ),
                );
              }
              return _contenu(donnees);
            },
          ),
        ),
      ),
    );
  }

  Widget _contenu(DonneesAudience donnees) {
    final c = TablCouleurs.of(context);
    final contexte = donnees.contexte;
    final pseudos = {for (final r in donnees.relations) r.id: r.pseudo};
    final horsAudience = contexte.taguesHorsAudience(
      _audience,
      widget.amisTaguesIds,
    );
    final nbAbonnes = contexte.abonnesIds.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL,
        TablTokens.espaceS,
        TablTokens.espaceL,
        TablTokens.espaceL,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: c.bordure,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            'Qui peut voir ce moment ?',
            style: c.titreAffichage.copyWith(fontSize: 26),
          ),
          const SizedBox(height: TablTokens.espaceM),
          TablOptionAudience(
            titre: 'Tout le monde',
            sousTitre: contexte.profilPrive
                ? (nbAbonnes == 1
                      ? 'La personne qui vous suit'
                      : 'Les $nbAbonnes personnes qui vous suivent')
                : 'Tous les utilisateurs de Tabl',
            selectionnee: _audience.mode == ModeAudience.toutLeMonde,
            onSelection: () => _choisirMode(ModeAudience.toutLeMonde),
          ),
          TablOptionAudience(
            titre: 'Seulement…',
            sousTitre: 'Des Tables et/ou des personnes',
            selectionnee: _audience.mode == ModeAudience.seulement,
            onSelection: () => _choisirMode(ModeAudience.seulement),
            detail: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (donnees.tables.isNotEmpty) ...[
                  const _Rubrique(texte: 'Tables'),
                  Wrap(
                    spacing: TablTokens.espaceS,
                    runSpacing: TablTokens.espaceS,
                    children: [
                      for (final table in donnees.tables)
                        TablPuceSelection(
                          libelle: table.emoji == null
                              ? table.nom
                              : '${table.nom} ${table.emoji}',
                          selectionnee: _audience.tableIds.contains(table.id),
                          onBascule: () => _basculerTable(table.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: TablTokens.espaceM),
                ],
                const _Rubrique(texte: 'Personnes'),
                _choixPersonnes(donnees.relations),
              ],
            ),
          ),
          TablOptionAudience(
            titre: 'Tout le monde sauf…',
            selectionnee: _audience.mode == ModeAudience.sauf,
            onSelection: () => _choisirMode(ModeAudience.sauf),
            detail: _choixPersonnes(donnees.relations),
          ),
          for (final id in horsAudience)
            _AvertissementTague(
              pseudo: pseudos[id] ?? 'Une personne taguée',
              // En "Tout le monde" sur un profil privé, la personne ne
              // nous suit pas : rien à "ajouter" sans changer de mode.
              onAjouter: _audience.mode == ModeAudience.toutLeMonde
                  ? null
                  : () => _inclureTague(id),
            ),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            contexte.libellePortee(_audience),
            textAlign: TextAlign.center,
            style: c.legende,
          ),
          const SizedBox(height: TablTokens.espaceM),
          TablBouton(
            libelle: 'Enregistrer',
            onPresse: _audience.estValide
                ? () => Navigator.of(context).pop(_audience.normalisee())
                : null,
          ),
        ],
      ),
    );
  }

  /// Recherche + pastilles : les personnes déjà choisies restent
  /// toujours visibles, les autres sont filtrées par la recherche.
  Widget _choixPersonnes(List<ProfilPublic> relations) {
    final c = TablCouleurs.of(context);
    if (relations.isEmpty) {
      return Text(
        'Personne pour l\'instant — suivez des gens pour les choisir ici.',
        style: c.legende,
      );
    }
    final filtre = _recherche.text.trim().toLowerCase();
    final affichees = [
      for (final r in relations)
        if (_audience.personneIds.contains(r.id) ||
            r.pseudo.toLowerCase().contains(filtre))
          r,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (relations.length > 6) ...[
          TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            style: c.corps,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Rechercher…',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              filled: true,
              fillColor: c.fond,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(TablTokens.arrondiM),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: TablTokens.espaceS),
        ],
        Wrap(
          spacing: TablTokens.espaceS,
          runSpacing: TablTokens.espaceS,
          children: [
            for (final r in affichees)
              TablPuceSelection(
                libelle: r.pseudo,
                selectionnee: _audience.personneIds.contains(r.id),
                onBascule: () => _basculerPersonne(r.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _Rubrique extends StatelessWidget {
  const _Rubrique({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: TablTokens.espaceS),
      child: Text(
        texte.toUpperCase(),
        style: c.legende.copyWith(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AvertissementTague extends StatelessWidget {
  const _AvertissementTague({required this.pseudo, required this.onAjouter});

  final String pseudo;
  final VoidCallback? onAjouter;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: TablTokens.espaceS),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: c.primaire),
          const SizedBox(width: TablTokens.espaceS),
          Expanded(
            child: Text(
              '$pseudo était avec vous mais ne verra pas ce moment.',
              style: c.legende.copyWith(color: c.texte),
            ),
          ),
          if (onAjouter != null)
            TextButton(onPressed: onAjouter, child: const Text("L'ajouter")),
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
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: c.corps.copyWith(color: c.texteDoux),
      ),
    );
  }
}
