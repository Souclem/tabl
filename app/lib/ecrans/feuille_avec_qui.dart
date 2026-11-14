import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// « Avec qui ? » : qui était à table. Une recherche, ceux avec qui l'on a
/// été [recentsIds] récemment en tête, puis les [personnes] suivies ou qui
/// suivent, une par ligne, avec leur photo et une case ronde. Chaque
/// personne touchée est cochée ou décochée aussitôt : [onChange] reçoit la
/// sélection entière à chaque geste, « OK » ne fait que fermer.
Future<void> ouvrirFeuilleAvecQui(
  BuildContext context, {
  required List<ProfilPublic> personnes,
  required Set<String> selection,
  required ValueChanged<Set<String>> onChange,
  List<String> recentsIds = const [],
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: voileFeuilleCreation,
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

  Widget _option(ProfilPublic p) => TablOptionCreation(
    titre: p.pseudo,
    avatar: TablAvatar(pseudo: p.pseudo, photoUrl: p.photoUrl, rayon: 18),
    coche: widget.selection.contains(p.id),
    onPresse: () => _basculer(p.id),
  );

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final personnes = widget.personnes;
    final cherche = _recherche.text.trim().isNotEmpty;
    final trouvees = filtrerPersonnes(personnes, _recherche.text);
    final parId = {for (final p in personnes) p.id: p};
    final recents = [for (final id in widget.recentsIds) ?parId[id]];
    final legende = TablTokens.policeCreation.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: c.texte.withValues(alpha: 0.6),
    );

    return TablCadreFeuilleCreation(
      titre: 'Avec qui',
      libelleAction: 'OK',
      onAction: () => Navigator.of(context).pop(),
      contenu: personnes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Personne à taguer pour l\'instant : suivez des gens '
                'pour les retrouver ici.',
                style: legende,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TablRechercheCreation(
                  controleur: _recherche,
                  indication: 'Chercher une personne',
                  onChanged: (_) => setState(() {}),
                ),
                if (!cherche && recents.isNotEmpty) ...[
                  const TablRubriqueCreation('Récemment à table avec vous'),
                  for (final p in recents) _option(p),
                ],
                TablRubriqueCreation(
                  cherche ? 'Résultats' : 'Vos abonnés et abonnements',
                ),
                if (trouvees.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucune personne trouvée.', style: legende),
                  ),
                for (final p in trouvees)
                  if (cherche || !widget.recentsIds.contains(p.id)) _option(p),
              ],
            ),
    );
  }
}
