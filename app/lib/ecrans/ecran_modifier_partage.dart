import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_publier.dart' show resumePartage;

/// "Modifier le partage" (megaprompt Bloc 5, règle 80-84) : changer la
/// visibilité de base d'un souvenir déjà publié et/ou les Tables
/// auxquelles il est associé — jamais un nouvel item Feed, jamais un
/// changement de date d'origine (règle 40-41, 65).
///
/// Point d'entrée volontairement non câblé pour l'instant : il
/// suppose une vue "mes souvenirs" côté Profil qui n'existe pas encore
/// (le Profil actuel n'affiche encore ni stats ni liste — hors
/// périmètre de ce bloc). L'écran est complet et testé, prêt à être
/// ouvert dès que cette liste existera.
class EcranModifierPartage extends StatefulWidget {
  const EcranModifierPartage({
    super.key,
    required this.souvenirId,
    required this.souvenirService,
    this.tableService,
  });

  final String souvenirId;
  final SouvenirService souvenirService;
  final TableService? tableService;

  @override
  State<EcranModifierPartage> createState() => _EcranModifierPartageState();
}

class _EcranModifierPartageState extends State<EcranModifierPartage> {
  bool? _partagerAvecCercle;
  Set<String>? _tablesSelectionneesIds;
  Set<String> _tablesInitialesIds = const {};
  List<ResumeTable> _tables = const [];
  bool _chargement = true;
  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final partage = await widget.souvenirService.partageActuel(
        widget.souvenirId,
      );
      final tables = await widget.tableService?.mesTables() ?? const [];
      if (!mounted) return;
      setState(() {
        _partagerAvecCercle = partage.partagerAvecCercle;
        _tablesInitialesIds = partage.tableIds.toSet();
        _tablesSelectionneesIds = Set.of(partage.tableIds);
        _tables = tables;
        _chargement = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erreur = messageErreurGenerique;
        _chargement = false;
      });
    }
  }

  /// Règle 81-82 : un avertissement seulement si l'audience se réduit
  /// (un ancien accès disparaît) — jamais pour un simple ajout.
  bool get _reduitAudience {
    final avant = _partagerAvecCercleInitial;
    if (avant == true && _partagerAvecCercle == false) return true;
    return !_tablesInitialesIds.every(
      (id) => _tablesSelectionneesIds!.contains(id),
    );
  }

  bool? _partagerAvecCercleInitial;

  Future<void> _confirmer() async {
    if (_reduitAudience) {
      final confirme = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: TablTokens.surface,
          title: const Text('Réduire le partage ?', style: TablTokens.sousTitre),
          content: Text(
            _partagerAvecCercle == false && _partagerAvecCercleInitial == true
                ? 'Votre cercle ne pourra plus voir cette expérience.'
                : 'Cette expérience ne figurera plus dans Notre histoire des '
                      'Tables retirées.',
            style: TablTokens.corps,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      if (confirme != true) return;
    }

    setState(() => _enCours = true);
    try {
      await widget.souvenirService.modifierPartage(
        widget.souvenirId,
        partagerAvecCercle: _partagerAvecCercle!,
        tableIds: _tablesSelectionneesIds!.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (_chargement) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_erreur != null) {
              return Center(
                child: Text(
                  _erreur!,
                  style: TablTokens.corps.copyWith(color: TablTokens.texteDoux),
                ),
              );
            }
            // Mémorise l'état initial une seule fois, pour comparer et
            // savoir si l'audience se réduit (règle 81-82).
            _partagerAvecCercleInitial ??= _partagerAvecCercle;

            final nomsSelectionnes = [
              for (final table in _tables)
                if (_tablesSelectionneesIds!.contains(table.id)) table.nom,
            ];

            return Padding(
              padding: const EdgeInsets.all(TablTokens.espaceL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Modifier le partage', style: TablTokens.titre),
                  const SizedBox(height: TablTokens.espaceXl),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('Partager avec mon cercle'),
                      ),
                      ButtonSegment(value: false, label: Text('Garder pour moi')),
                    ],
                    selected: {_partagerAvecCercle!},
                    onSelectionChanged: (selection) =>
                        setState(() => _partagerAvecCercle = selection.first),
                    style: SegmentedButton.styleFrom(
                      backgroundColor: TablTokens.surface,
                      selectedBackgroundColor: TablTokens.primaire,
                      foregroundColor: TablTokens.texte,
                      selectedForegroundColor: TablTokens.texteSurPrimaire,
                    ),
                  ),
                  if (_tables.isNotEmpty) ...[
                    const SizedBox(height: TablTokens.espaceL),
                    Text('Ajouter à une Table', style: TablTokens.sousTitre),
                    const SizedBox(height: TablTokens.espaceS),
                    Wrap(
                      spacing: TablTokens.espaceS,
                      runSpacing: TablTokens.espaceS,
                      children: [
                        for (final table in _tables)
                          FilterChip(
                            label: Text(table.nom),
                            selected: _tablesSelectionneesIds!.contains(
                              table.id,
                            ),
                            onSelected: (_) => setState(() {
                              if (!_tablesSelectionneesIds!.remove(table.id)) {
                                _tablesSelectionneesIds!.add(table.id);
                              }
                            }),
                            backgroundColor: TablTokens.surface,
                            selectedColor: TablTokens.primaire.withValues(
                              alpha: 0.2,
                            ),
                            labelStyle: TablTokens.legende,
                            side: const BorderSide(color: TablTokens.bordure),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: TablTokens.espaceM),
                  Text(
                    resumePartage(_partagerAvecCercle!, nomsSelectionnes),
                    textAlign: TextAlign.center,
                    style: TablTokens.legende.copyWith(
                      color: TablTokens.texteDoux,
                    ),
                  ),
                  const SizedBox(height: TablTokens.espaceXl),
                  TablBouton(
                    libelle: 'Confirmer',
                    enCours: _enCours,
                    onPresse: _confirmer,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
