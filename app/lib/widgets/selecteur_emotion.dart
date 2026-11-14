import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'souvenirs/verre_camera.dart';

/// Sélecteur d'émotion à la finalisation d'un moment : "Comment
/// c'était ?", de vrais emoji, celui choisi grossit légèrement pour se
/// détacher des autres (voir
/// `instruction/Clément (2)/scraps/clement.txt`, B9). On touche un
/// visage, ou on pose le doigt puis on glisse de l'un à l'autre.
///
/// Composant pur : ne connaît aucune notion d'"émotion" métier, juste une
/// liste d'emoji parmi lesquels un seul peut être sélectionné — c'est
/// l'écran appelant qui fait le lien avec son propre modèle.
class TablSelecteurEmotion extends StatelessWidget {
  const TablSelecteurEmotion({
    super.key,
    required this.emojis,
    required this.selection,
    required this.onSelection,
    this.libelles = const [],
    this.montrerNoms = false,
    this.enCapsule = false,
  });

  final List<String> emojis;

  /// L'emoji actuellement sélectionné, ou `null`.
  final String? selection;

  /// Appelé au toucher, et à chaque nouveau visage survolé en glissant
  /// (jamais pour celui déjà choisi).
  final ValueChanged<String> onSelection;

  /// Le nom de chaque emoji, dans le même ordre ; affiché sous celui qui
  /// est choisi. Vide : aucun nom.
  final List<String> libelles;

  /// Tous les noms d'un coup, et la rangée « respire » : on rappelle
  /// qu'un choix manque.
  final bool montrerNoms;

  /// Posé sur une photo (finalisation) : les visages dans une capsule de
  /// verre, chacun dans une case de 54 px, les noms dessous.
  final bool enCapsule;

  static const double _largeurCase = 54;

  void _glisser(double dx, double largeur) {
    final rang = (dx / (largeur / emojis.length)).floor().clamp(
      0,
      emojis.length - 1,
    );
    if (emojis[rang] != selection) onSelection(emojis[rang]);
  }

  @override
  Widget build(BuildContext context) {
    if (enCapsule) return _capsule();
    return LayoutBuilder(
      builder: (context, contraintes) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (d) =>
            _glisser(d.localPosition.dx, contraintes.maxWidth),
        onHorizontalDragUpdate: (d) =>
            _glisser(d.localPosition.dx, contraintes.maxWidth),
        child: Row(
          children: [
            for (var i = 0; i < emojis.length; i++)
              Expanded(
                child: _BoutonEmotion(
                  emoji: emojis[i],
                  libelle: i < libelles.length ? libelles[i] : null,
                  actif: emojis[i] == selection,
                  nomVisible: montrerNoms || emojis[i] == selection,
                  respire: montrerNoms,
                  onPresse: () => onSelection(emojis[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _capsule() {
    final cases = [
      for (var i = 0; i < emojis.length; i++)
        SizedBox(
          width: _largeurCase,
          child: _CaseCapsule(
            emoji: emojis[i],
            libelle: i < libelles.length ? libelles[i] : null,
            actif: emojis[i] == selection,
            estompe: selection != null && emojis[i] != selection,
            nomVisible: montrerNoms || emojis[i] == selection,
            respire: montrerNoms,
            onPresse: () => onSelection(emojis[i]),
          ),
        ),
    ];
    final largeurCases =
        _largeurCase * emojis.length + 4.0 * (emojis.length - 1);
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 58,
            child: const IgnorePointer(
              child: VerreCamera(arrondi: 30, child: SizedBox.expand()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) =>
                  _glisser(d.localPosition.dx, largeurCases),
              onHorizontalDragUpdate: (d) =>
                  _glisser(d.localPosition.dx, largeurCases),
              child: SizedBox(
                width: largeurCases,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: cases,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un visage de la capsule : 54 × 58, le nom 14 px sous la capsule.
class _CaseCapsule extends StatelessWidget {
  const _CaseCapsule({
    required this.emoji,
    required this.libelle,
    required this.actif,
    required this.estompe,
    required this.nomVisible,
    required this.respire,
    required this.onPresse,
  });

  final String emoji;
  final String? libelle;
  final bool actif;
  final bool estompe;
  final bool nomVisible;
  final bool respire;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    return Semantics(
      button: true,
      selected: actif,
      label: libelle,
      excludeSemantics: libelle != null,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 58,
              child: Center(
                child: AnimatedScale(
                  scale: actif ? 1.18 : (respire ? 1.1 : 1.0),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          c.texte.withValues(alpha: actif ? 0.22 : 0),
                          c.texte.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.68],
                      ),
                    ),
                    child: AnimatedOpacity(
                      opacity: estompe ? 0.55 : 1,
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 30, height: 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (libelle != null)
              AnimatedOpacity(
                opacity: nomVisible ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    libelle!,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TablTokens.policeCreation.copyWith(
                      fontSize: 10,
                      color: actif
                          ? c.primaire
                          : c.texte.withValues(alpha: 0.85),
                      shadows: const [
                        Shadow(
                          blurRadius: 6,
                          offset: Offset(0, 1),
                          color: Color(0x99000000),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BoutonEmotion extends StatelessWidget {
  const _BoutonEmotion({
    required this.emoji,
    required this.libelle,
    required this.actif,
    required this.nomVisible,
    required this.respire,
    required this.onPresse,
  });

  final String emoji;
  final String? libelle;
  final bool actif;
  final bool nomVisible;
  final bool respire;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: actif,
      label: libelle,
      excludeSemantics: libelle != null,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: actif ? 1.35 : (respire ? 1.12 : 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(TablTokens.espaceS),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: actif
                      ? c.primaire.withValues(alpha: 0.14)
                      : Colors.transparent,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),
            if (libelle != null)
              AnimatedOpacity(
                opacity: nomVisible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Padding(
                  padding: const EdgeInsets.only(top: TablTokens.espaceXs),
                  child: Text(
                    libelle!,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: c.legende.copyWith(
                      fontSize: 12,
                      color: actif ? c.primaire : c.texteDoux,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
