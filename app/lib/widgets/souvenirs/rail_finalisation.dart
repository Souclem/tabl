import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bouton_verre.dart';

/// Un geste du rail : son nom, son icône, et `renseigne` quand il y a
/// déjà quelque chose derrière.
typedef ActionRail = ({
  String libelle,
  IconData icone,
  bool renseigne,
  VoidCallback onPresse,
});

/// Le rail à droite de la photo à la finalisation (« Ajouter un mot »,
/// « Ce qui ressort », « Avec qui ») : un bouton en verre par geste, son
/// nom à gauche, un point doré quand il est renseigné.
class TablRailFinalisation extends StatelessWidget {
  const TablRailFinalisation({super.key, required this.actions});

  final List<ActionRail> actions;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.only(top: TablTokens.espaceS),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: action.onPresse,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    action.libelle,
                    style: c.legende.copyWith(
                      color: c.texte,
                      shadows: const [
                        Shadow(blurRadius: 8, color: Color(0xCC000000)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: TablTokens.espaceS),
                TablBoutonVerre(
                  icone: action.icone,
                  libelle: action.libelle,
                  pastille: action.renseigne,
                  onPresse: action.onPresse,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
