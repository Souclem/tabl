import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// « Avec qui ? » : qui était à table. Une recherche, ceux avec qui l'on a
/// été [recentsIds] récemment en tête (leurs têtes, sur une rangée), puis
/// les [personnes] suivies ou qui suivent, une par ligne. Chaque personne
/// touchée est cochée ou décochée aussitôt : [onChange] reçoit la sélection
/// entière à chaque geste, rien d'autre à valider.
Future<void> ouvrirFeuilleAvecQui(
  BuildContext context, {
  required List<ProfilPublic> personnes,
  required Set<String> selection,
  required ValueChanged<Set<String>> onChange,
  List<String> recentsIds = const [],
}) {
  final c = TablCouleurs.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    showDragHandle: true,
    builder: (_) => _FeuilleAvecQui(
      personnes: personnes,
      selection: Set.of(selection),
      recentsIds: recentsIds,
      onChange: onChange,
    ),
  );
}

class _FeuilleAvecQui extends StatefulWidget {
  const _FeuilleAvecQui({
    required this.personnes,
    required this.selection,
    required this.recentsIds,
    required this.onChange,
  });

  final List<ProfilPublic> personnes;
  final Set<String> selection;
  final List<String> recentsIds;
  final ValueChanged<Set<String>> onChange;

  @override
  State<_FeuilleAvecQui> createState() => _FeuilleAvecQuiState();
}

class _FeuilleAvecQuiState extends State<_FeuilleAvecQui> {
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  void _basculer(String id) {
    setState(() {
      if (!widget.selection.remove(id)) widget.selection.add(id);
    });
    widget.onChange(Set.of(widget.selection));
  }

  Widget _rubrique(TablCouleurs c, String texte) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TablTokens.espaceL - 4,
      TablTokens.espaceM,
      TablTokens.espaceL - 4,
      TablTokens.espaceXs,
    ),
    child: Text(
      texte.toUpperCase(),
      style: c.legende.copyWith(
        fontSize: 11,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final personnes = widget.personnes;
    final cherche = _recherche.text.trim().isNotEmpty;
    final trouvees = filtrerPersonnes(personnes, _recherche.text);
    final parId = {for (final p in personnes) p.id: p};
    final recents = [for (final id in widget.recentsIds) ?parId[id]];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: TablTokens.espaceL - 4,
                ),
                child: Text(
                  'Avec qui ?',
                  style: c.titreAffichage.copyWith(fontSize: 26),
                ),
              ),
              if (personnes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(TablTokens.espaceL - 4),
                  child: Text(
                    'Personne à taguer pour l\'instant : suivez des gens '
                    'pour les retrouver ici.',
                    style: c.legende,
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TablTokens.espaceL - 4,
                    TablTokens.espaceM,
                    TablTokens.espaceL - 4,
                    0,
                  ),
                  child: TablChampTexte(
                    libelle: '',
                    controleur: _recherche,
                    indication: 'Chercher une personne',
                    iconePrefixe: Icons.search_rounded,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    children: [
                      if (!cherche && recents.isNotEmpty) ...[
                        _rubrique(c, 'Récemment à table avec vous'),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TablTokens.espaceL - 4,
                          ),
                          child: TablSelecteurPersonnes(
                            personnes: [
                              for (final p in recents)
                                PersonneSelectionnable(
                                  id: p.id,
                                  pseudo: p.pseudo,
                                  photoUrl: p.photoUrl,
                                ),
                            ],
                            selection: widget.selection,
                            onBascule: _basculer,
                          ),
                        ),
                      ],
                      _rubrique(
                        c,
                        cherche ? 'Résultats' : 'Vos abonnés et abonnements',
                      ),
                      if (trouvees.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: TablTokens.espaceL - 4,
                            vertical: TablTokens.espaceS,
                          ),
                          child: Text(
                            'Aucune personne trouvée.',
                            style: c.legende,
                          ),
                        ),
                      for (final p in trouvees)
                        TablLignePersonne(
                          pseudo: p.pseudo,
                          photoUrl: p.photoUrl,
                          onPresse: () => _basculer(p.id),
                          actions: [
                            Icon(
                              widget.selection.contains(p.id)
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: widget.selection.contains(p.id)
                                  ? c.primaire
                                  : c.bordure,
                              semanticLabel: widget.selection.contains(p.id)
                                  ? 'Avec vous'
                                  : 'Pas avec vous',
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
                  TablTokens.espaceS,
                  TablTokens.espaceL - 4,
                  TablTokens.espaceM,
                ),
                child: TablBouton(
                  libelle: widget.selection.isEmpty
                      ? 'Valider'
                      : 'Valider · ${widget.selection.length}',
                  onPresse: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
