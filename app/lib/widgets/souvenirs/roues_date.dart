import 'package:flutter/cupertino.dart';

import '../../theme/tokens.dart';

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
          // Une seule bande de sélection pour les trois, comme les roues
          // de date d'iOS : arrondie aux deux bouts seulement.
          Expanded(
            flex: 2,
            child: _Roue(jours, indexJour, onJour, arrondiFin: false),
          ),
          Expanded(
            flex: 4,
            child: _Roue(
              mois,
              indexMois,
              onMois,
              arrondiDebut: false,
              arrondiFin: false,
            ),
          ),
          Expanded(
            flex: 3,
            child: _Roue(annees, indexAnnee, onAnnee, arrondiDebut: false),
          ),
        ],
      ),
    );
  }
}

class _Roue extends StatefulWidget {
  const _Roue(
    this.libelles,
    this.index,
    this.onChange, {
    this.arrondiDebut = true,
    this.arrondiFin = true,
  });

  final List<String> libelles;
  final int index;
  final ValueChanged<int> onChange;
  final bool arrondiDebut;
  final bool arrondiFin;

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
    final c = TablCouleurs.of(context);
    return CupertinoPicker(
      scrollController: _controleur,
      itemExtent: 38,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: c.primaire.withValues(alpha: 0.13),
        capStartEdge: widget.arrondiDebut,
        capEndEdge: widget.arrondiFin,
      ),
      onSelectedItemChanged: widget.onChange,
      children: [
        for (final libelle in widget.libelles)
          Center(
            child: Text(libelle, style: c.corps.copyWith(color: c.texte)),
          ),
      ],
    );
  }
}
