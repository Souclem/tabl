import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'verre_camera.dart';

/// Un geste du rail : son nom, son icône (voir `icones_creation.dart`), et
/// `renseigne` quand il y a déjà quelque chose derrière.
typedef ActionRail = ({
  String libelle,
  Widget icone,
  bool renseigne,
  VoidCallback onPresse,
});

/// Le rail à droite de la photo à la finalisation (« Ajouter un mot »,
/// « Ce qui ressort », « Avec qui ») : son nom, puis un rond de verre de
/// 42 px, un point doré quand il est renseigné. Toute la ligne est le
/// bouton.
class TablRailFinalisation extends StatelessWidget {
  const TablRailFinalisation({super.key, required this.actions});

  static const double tailleRond = 42;

  final List<ActionRail> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
            child: _LigneRail(action: actions[i]),
          ),
      ],
    );
  }
}

class _LigneRail extends StatelessWidget {
  const _LigneRail({required this.action});

  final ActionRail action;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Semantics(
      button: true,
      label: action.libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: action.onPresse,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              action.libelle,
              maxLines: 1,
              style: TablTokens.policeCreation.copyWith(
                fontSize: 13,
                color: c.texte.withValues(alpha: 0.92),
                shadows: const [
                  Shadow(
                    blurRadius: 8,
                    offset: Offset(0, 1),
                    color: Color(0x8C000000),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 9),
            SizedBox.square(
              dimension: TablRailFinalisation.tailleRond,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: VerreCamera(
                      arrondi: TablRailFinalisation.tailleRond / 2,
                      child: Center(child: action.icone),
                    ),
                  ),
                  Positioned(
                    right: 1,
                    top: 1,
                    child: AnimatedScale(
                      scale: action.renseigne ? 1 : 0.4,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: action.renseigne ? 1 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: c.primaire,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.fond.withValues(alpha: 0.6),
                                spreadRadius: 1.5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
