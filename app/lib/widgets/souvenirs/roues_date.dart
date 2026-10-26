import 'package:flutter/cupertino.dart';

import '../../theme/tokens.dart';

/// Une case du « Quand ? » d'un souvenir (« Mars », « 2023 », « Jour ·
/// facultatif ») : un tap ouvre les roues.
class TablCaseDate extends StatelessWidget {
  const TablCaseDate({
    super.key,
    required this.texte,
    required this.onPresse,
    this.vide = false,
  });

  final String texte;

  /// Rien de choisi : le texte est une indication, en plus doux.
  final bool vide;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onPresse,
        child: Container(
          height: TablTokens.hauteurControle,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceS),
          decoration: BoxDecoration(
            color: TablTokens.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
            border: Border.all(color: TablTokens.bordure),
          ),
          child: Text(
            texte,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: vide
                ? TablTokens.legende
                : TablTokens.corps.copyWith(color: TablTokens.texte),
          ),
        ),
      ),
    );
  }
}

/// Les roues jour / mois / année d'un souvenir, côte à côte. Chaque roue
/// reçoit ses libellés prêts (« — » pour « pas de jour ») et l'index
/// choisi ; un changement repart par son callback.
class TablRouesDate extends StatelessWidget {
  const TablRouesDate({
    super.key,
    required this.jours,
    required this.indexJour,
    required this.onJour,
    required this.mois,
    required this.indexMois,
    required this.onMois,
    required this.annees,
    required this.indexAnnee,
    required this.onAnnee,
  });

  final List<String> jours;
  final int indexJour;
  final ValueChanged<int> onJour;
  final List<String> mois;
  final int indexMois;
  final ValueChanged<int> onMois;
  final List<String> annees;
  final int indexAnnee;
  final ValueChanged<int> onAnnee;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(flex: 2, child: _Roue(jours, indexJour, onJour)),
          Expanded(flex: 4, child: _Roue(mois, indexMois, onMois)),
          Expanded(flex: 3, child: _Roue(annees, indexAnnee, onAnnee)),
        ],
      ),
    );
  }
}

class _Roue extends StatefulWidget {
  const _Roue(this.libelles, this.index, this.onChange);

  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChange;

  @override
  State<_Roue> createState() => _RoueState();
}

class _RoueState extends State<_Roue> {
  late final _controleur = FixedExtentScrollController(
    initialItem: widget.index,
  );

  @override
  void didUpdateWidget(_Roue ancien) {
    super.didUpdateWidget(ancien);
    // Un jour qui n'existe plus (31 → février) : la roue suit l'index
    // corrigé.
    if (widget.index != _controleur.selectedItem) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controleur.hasClients) {
          _controleur.jumpToItem(widget.index);
        }
      });
    }
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: _controleur,
      itemExtent: 38,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: TablTokens.primaire.withValues(alpha: 0.13),
      ),
      onSelectedItemChanged: widget.onChange,
      children: [
        for (final libelle in widget.libelles)
          Center(
            child: Text(
              libelle,
              style: TablTokens.corps.copyWith(color: TablTokens.texte),
            ),
          ),
      ],
    );
  }
}
