import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Une option de [TablGrilleChoix].
class OptionChoix {
  const OptionChoix({
    required this.icone,
    required this.libelle,
    required this.description,
  });

  final IconData icone;

  /// "Un bug".
  final String libelle;

  /// "Quelque chose ne marche pas".
  final String description;
}

/// Des cartes à toucher, deux par rangée, une seule choisie à la fois
/// (bordure et pastille dorées).
class TablGrilleChoix extends StatelessWidget {
  const TablGrilleChoix({
    super.key,
    required this.options,
    required this.index,
    required this.onChoisir,
  });

  final List<OptionChoix> options;

  /// `null` : rien de choisi.
  final int? index;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var debut = 0; debut < options.length; debut += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            // Les deux cartes d'une rangée à la même hauteur, quelle que
            // soit la longueur de leur description.
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = debut; i < debut + 2; i++) ...[
                    if (i > debut) const SizedBox(width: 10),
                    Expanded(
                      child: i < options.length
                          ? _CarteChoix(
                              option: options[i],
                              choisie: i == index,
                              onPresse: () => onChoisir(i),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CarteChoix extends StatelessWidget {
  const _CarteChoix({
    required this.option,
    required this.choisie,
    required this.onPresse,
  });

  final OptionChoix option;
  final bool choisie;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    const duree = Duration(milliseconds: 220);
    return Semantics(
      button: true,
      selected: choisie,
      label: option.libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: duree,
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: choisie ? c.primaire.withValues(alpha: 0.1) : c.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiM),
            border: Border.all(
              color: choisie ? c.primaire : c.bordure,
              width: choisie ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: duree,
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: choisie ? c.primaire : c.surface,
                ),
                child: Icon(
                  option.icone,
                  size: 18,
                  color: choisie ? c.texteSurPrimaire : c.primaire,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                option.libelle,
                style: c.corps.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.description,
                style: c.legende.copyWith(fontSize: 12.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Les captures d'écran jointes à un message, en vignettes qu'on peut
/// retirer, suivies d'une case « Ajouter » tant qu'il reste de la place.
class TablVignettesCaptures extends StatelessWidget {
  const TablVignettesCaptures({
    super.key,
    required this.images,
    required this.maximum,
    required this.onAjouter,
    required this.onRetirer,
  });

  final List<Uint8List> images;
  final int maximum;
  final VoidCallback onAjouter;
  final ValueChanged<int> onRetirer;

  static const _largeur = 76.0;
  static const _hauteur = 124.0;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final rayon = BorderRadius.circular(TablTokens.arrondiS + 4);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < images.length; i++)
          SizedBox(
            width: _largeur,
            height: _hauteur,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: rayon,
                  child: Image.memory(images[i], fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Tooltip(
                    message: 'Retirer la capture',
                    child: GestureDetector(
                      onTap: () => onRetirer(i),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.65),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (images.length < maximum)
          Tooltip(
            message: 'Ajouter une capture d’écran',
            child: InkWell(
              onTap: onAjouter,
              borderRadius: rayon,
              child: Container(
                width: _largeur,
                height: _hauteur,
                decoration: BoxDecoration(
                  borderRadius: rayon,
                  color: c.surfaceBasse,
                  border: Border.all(color: c.bordure),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: c.primaire),
                    const SizedBox(height: 6),
                    Text('Ajouter', style: c.legende.copyWith(fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ce qui remplace un formulaire une fois envoyé : une coche dorée qui
/// apparaît, un mot de remerciement, de quoi revenir.
class TablConfirmationEnvoi extends StatelessWidget {
  const TablConfirmationEnvoi({
    super.key,
    required this.titre,
    required this.message,
    required this.libelleBouton,
    required this.onPresse,
  });

  final String titre;
  final String message;
  final String libelleBouton;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, echelle, enfant) =>
                Transform.scale(scale: echelle, child: enfant),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.primaire,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 40,
                color: c.texteSurPrimaire,
              ),
            ),
          ),
          const SizedBox(height: TablTokens.espaceL),
          Text(
            titre,
            textAlign: TextAlign.center,
            style: c.titreAffichage.copyWith(fontSize: 30),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Text(
            message,
            textAlign: TextAlign.center,
            style: c.corps.copyWith(color: c.texteDoux),
          ),
          const SizedBox(height: TablTokens.espaceXl),
          TextButton(
            onPressed: onPresse,
            child: Text(
              libelleBouton,
              style: c.corps.copyWith(
                color: c.primaire,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
