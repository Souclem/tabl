import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bouton "j'aime" animé : une cloche qui s'ouvre et laisse jaillir un
/// cœur qui disparaît, en 5 étapes (inspiré de l'identité de marque
/// Tabl — cloche + cœur). La cloche reste "active" (remplie, dorée)
/// après coup si [actif] est vrai ; l'animation ne joue qu'au tap, elle
/// ne pilote pas l'état persistant.
///
/// Composant pur : ne décide jamais lui-même s'il faut réagir ou pas,
/// se contente de jouer l'animation et de prévenir via [onPresse].
class TablBoutonReaction extends StatefulWidget {
  const TablBoutonReaction({
    super.key,
    required this.actif,
    required this.onPresse,
  });

  final bool actif;
  final VoidCallback onPresse;

  @override
  State<TablBoutonReaction> createState() => _TablBoutonReactionState();
}

class _TablBoutonReactionState extends State<TablBoutonReaction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  // Étapes de la chorégraphie, en fraction de la durée totale.
  static const _appui = Interval(0.0, 0.15, curve: Curves.easeOut);
  static const _ouverture = Interval(0.15, 0.30, curve: Curves.easeOut);
  static const _coeurJaillit = Interval(0.25, 0.55, curve: Curves.easeOut);
  static const _disparition = Interval(0.55, 1.0, curve: Curves.easeIn);

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _declencher() {
    widget.onPresse();
    _controleur.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final couleur = widget.actif ? TablTokens.primaire : TablTokens.texteDoux;

    return GestureDetector(
      onTap: _declencher,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 40,
        height: 40,
        child: AnimatedBuilder(
          animation: _controleur,
          builder: (context, _) {
            final t = _controleur.value;

            // Appui : la cloche se tasse légèrement puis revient à sa
            // taille normale pendant l'ouverture.
            final pressage = _appui.transform(t) - _ouverture.transform(t);
            final echelleCloche = 1 - 0.12 * pressage;

            // Cœur : fondu entrant avec léger dépassement d'échelle,
            // puis translation continue vers le haut jusqu'à disparaître.
            final apparition = _coeurJaillit.transform(t);
            final effacement = _disparition.transform(t);
            final opaciteCoeur = apparition * (1 - effacement);
            final echelleCoeur = 0.6 + 0.7 * apparition;
            final decalageCoeur = -18 * apparition - 16 * effacement;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: echelleCloche,
                  child: Icon(
                    widget.actif
                        ? Icons.notifications_rounded
                        : Icons.notifications_outlined,
                    color: couleur,
                    size: 22,
                  ),
                ),
                if (opaciteCoeur > 0)
                  Transform.translate(
                    offset: Offset(0, decalageCoeur),
                    child: Transform.scale(
                      scale: echelleCoeur,
                      child: Opacity(
                        opacity: opaciteCoeur.clamp(0, 1),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: TablTokens.primaire,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
