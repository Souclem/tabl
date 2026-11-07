import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Le mini-calendrier de sélection de jours candidats (megaprompt Bloc
/// 4, règles 8-9) : grille mensuelle sobre façon Apple/Android, habillée
/// Tabl. Tap pour sélectionner, tap à nouveau pour désélectionner —
/// jamais de long press ni de drag (règle 9).
///
/// Composant pur : ne sait pas si c'est le creator qui choisit des dates
/// candidates ou un participant ses disponibilités, juste une grille de
/// jours avec un état sélectionné/désactivé par jour.
class TablCalendrierJours extends StatelessWidget {
  const TablCalendrierJours({
    super.key,
    required this.mois,
    required this.joursSelectionnes,
    required this.joursDesactives,
    required this.onToggleJour,
    required this.onMoisPrecedent,
    required this.onMoisSuivant,
  });

  /// Premier jour du mois affiché.
  final DateTime mois;
  final Set<DateTime> joursSelectionnes;

  /// Jours non sélectionnables (passés, ou hors des dates candidates
  /// selon le contexte d'appel) — affichés en sourdine (règle 8).
  final Set<DateTime> joursDesactives;

  final ValueChanged<DateTime> onToggleJour;
  final VoidCallback onMoisPrecedent;
  final VoidCallback onMoisSuivant;

  static const _moisNoms = [
    'Janvier',
    'Février',
    'Mars',
    'Avril',
    'Mai',
    'Juin',
    'Juillet',
    'Août',
    'Septembre',
    'Octobre',
    'Novembre',
    'Décembre',
  ];
  static const _joursEntete = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  bool _memeJour(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final premierJourMois = DateTime(mois.year, mois.month, 1);
    final nombreJours = DateTime(mois.year, mois.month + 1, 0).day;
    // 1 (lundi) à 7 (dimanche) — décalage pour placer le 1er du mois à
    // sa bonne colonne dans la grille.
    final decalage = premierJourMois.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onMoisPrecedent,
              icon: Icon(Icons.chevron_left, color: c.texte),
            ),
            Expanded(
              child: Text(
                '${_moisNoms[mois.month - 1]} ${mois.year}',
                style: c.sousTitre,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              onPressed: onMoisSuivant,
              icon: Icon(Icons.chevron_right, color: c.texte),
            ),
          ],
        ),
        Row(
          children: [
            for (final j in _joursEntete)
              Expanded(
                child: Center(
                  child: Text(j, style: c.legende.copyWith(color: c.texteDoux)),
                ),
              ),
          ],
        ),
        const SizedBox(height: TablTokens.espaceXs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: decalage + nombreJours,
          itemBuilder: (context, index) {
            if (index < decalage) return const SizedBox.shrink();
            final jour = DateTime(mois.year, mois.month, index - decalage + 1);
            final selectionne = joursSelectionnes.any(
              (d) => _memeJour(d, jour),
            );
            final desactive = joursDesactives.any((d) => _memeJour(d, jour));
            return _JourCase(
              jour: jour.day,
              selectionne: selectionne,
              desactive: desactive,
              onTap: desactive ? null : () => onToggleJour(jour),
            );
          },
        ),
      ],
    );
  }
}

class _JourCase extends StatelessWidget {
  const _JourCase({
    required this.jour,
    required this.selectionne,
    required this.desactive,
    required this.onTap,
  });

  final int jour;
  final bool selectionne;
  final bool desactive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: selectionne,
      label: '$jour${desactive ? ', date passée' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: AspectRatio(
            aspectRatio: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selectionne ? c.primaire.withValues(alpha: 0.18) : null,
                border: selectionne
                    ? Border.all(color: c.primaire, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '$jour',
                  style: c.corps.copyWith(
                    color: desactive
                        ? c.texteDoux.withValues(alpha: 0.5)
                        : c.texte,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
