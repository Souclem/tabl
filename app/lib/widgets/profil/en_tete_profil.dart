import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';

/// Un chiffre du haut de profil : moments, abonnés, abonnements.
class CompteurProfil {
  const CompteurProfil({
    required this.nombre,
    required this.libelle,
    this.onPresse,
    this.pastille = false,
  });

  /// `null` tant qu'il n'est pas connu : un tiret s'affiche.
  final int? nombre;

  /// "moments", "abonnés"…
  final String libelle;

  /// Ouvre la liste correspondante ; `null` : pas touchable.
  final VoidCallback? onPresse;

  /// Petit point doré : des demandes attendent une réponse.
  final bool pastille;
}

/// Le haut d'un profil, le sien comme celui d'un autre, fait pour être
/// le `flexibleSpace` d'une `SliverAppBar` épinglée : une photo de
/// couverture qui glisse moins vite que le reste puis s'efface, la photo
/// de profil cerclée d'or, le prénom en grand et trois chiffres. En
/// défilant, le tout se range en une barre compacte (photo + prénom).
///
/// Composant pur : les chiffres, les photos et l'action (« Suivre »…)
/// arrivent prêts ; les gestes repartent par callbacks.
class TablEnTeteProfil extends StatelessWidget {
  const TablEnTeteProfil({
    super.key,
    required this.pseudo,
    required this.compteurs,
    this.photoUrl,
    this.couvertureUrl,
    this.onModifier,
    this.action,
    this.avecRetour = false,
  });

  final String pseudo;
  final String? photoUrl;

  /// La photo de fond ; `null` : un simple dégradé.
  final String? couvertureUrl;
  final List<CompteurProfil> compteurs;

  /// Pastille crayon sur la photo (son propre profil) ; `null` : aucune.
  final VoidCallback? onModifier;

  /// Sous les chiffres (« Suivre », « Abonné »…).
  final Widget? action;

  /// Un bouton retour occupe la gauche de la barre compacte.
  final bool avecRetour;

  static const double _airAuDessus = 40;
  static const double _hauteurBloc = 96 + 18 + 76;
  static const double _hauteurAction = 46 + 16;
  static const double _margeBas = 18;

  /// La hauteur dépliée à donner à la `SliverAppBar`.
  static double hauteurDepliee(
    BuildContext context, {
    required bool avecAction,
  }) =>
      MediaQuery.paddingOf(context).top +
      kToolbarHeight +
      _airAuDessus +
      _hauteurBloc +
      (avecAction ? _hauteurAction : 0) +
      _margeBas;

  @override
  Widget build(BuildContext context) {
    final reglages = context
        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final max = reglages?.maxExtent ?? 0;
    final actuel = reglages?.currentExtent ?? max;
    final min = reglages?.minExtent ?? 0;
    final replie = max - actuel;
    // 0 : déplié, 1 : rangé en barre compacte.
    final t = max <= min ? 0.0 : (replie / (max - min)).clamp(0.0, 1.0);
    final haut = MediaQuery.paddingOf(context).top;
    final c = TablCouleurs.of(context);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: -replie * 0.5,
          height: max == 0 ? 400 : max * 0.95,
          child: Opacity(
            opacity: (1 - t * 1.1).clamp(0.0, 1.0),
            child: _Couverture(url: couvertureUrl),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: c.fond.withValues(
                alpha: ((t - 0.6) / 0.4).clamp(0.0, 1.0),
              ),
            ),
          ),
        ),
        Positioned(
          left: TablTokens.espaceL - 4,
          right: TablTokens.espaceL - 4,
          bottom: _margeBas,
          child: Opacity(
            opacity: (1 - t * 1.6).clamp(0.0, 1.0),
            child: IgnorePointer(
              ignoring: t > 0.5,
              child: _Identite(
                pseudo: pseudo,
                photoUrl: photoUrl,
                compteurs: compteurs,
                onModifier: onModifier,
                action: action,
              ),
            ),
          ),
        ),
        Positioned(
          left: avecRetour ? 64 : TablTokens.espaceL - 4,
          right: 64,
          top: haut,
          height: kToolbarHeight,
          child: IgnorePointer(
            child: Opacity(
              opacity: ((t - 0.78) / 0.22).clamp(0.0, 1.0),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: c.primaire),
                    ),
                    child: TablAvatar(
                      pseudo: pseudo,
                      photoUrl: photoUrl,
                      rayon: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      pseudo,
                      overflow: TextOverflow.ellipsis,
                      style: c.titreAffichage.copyWith(fontSize: 19),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Couverture extends StatelessWidget {
  const _Couverture({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: c.surface),
        if (url != null)
          Image.network(
            url!,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.38),
            colorBlendMode: BlendMode.darken,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                c.fond.withValues(alpha: 0.45),
                c.fond.withValues(alpha: 0.05),
                c.fond.withValues(alpha: 0.8),
                c.fond,
              ],
              stops: const [0, 0.3, 0.72, 0.96],
            ),
          ),
        ),
      ],
    );
  }
}

class _Identite extends StatelessWidget {
  const _Identite({
    required this.pseudo,
    required this.photoUrl,
    required this.compteurs,
    required this.onModifier,
    required this.action,
  });

  final String pseudo;
  final String? photoUrl;
  final List<CompteurProfil> compteurs;
  final VoidCallback? onModifier;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final trait = BorderSide(color: c.bordure.withValues(alpha: 0.7));
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _PhotoCerclee(
              pseudo: pseudo,
              photoUrl: photoUrl,
              onModifier: onModifier,
            ),
            const SizedBox(width: TablTokens.espaceM),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  pseudo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: c.titreAffichage.copyWith(
                    fontSize: 40,
                    height: 1.05,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: trait, bottom: trait),
          ),
          child: Row(
            children: [
              for (final compteur in compteurs)
                Expanded(child: _Compteur(compteur: compteur)),
            ],
          ),
        ),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    );
  }
}

class _Compteur extends StatelessWidget {
  const _Compteur({required this.compteur});

  final CompteurProfil compteur;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final nombre = compteur.nombre;
    final contenu = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Les chiffres montent jusqu'à leur valeur à l'arrivée.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (nombre ?? 0).toDouble()),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, valeur, _) => Text(
              nombre == null ? '—' : '${valeur.round()}',
              style: c.titreAffichage.copyWith(fontSize: 26, height: 1.1),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Flexible(
                child: Text(
                  compteur.libelle.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: c.legende.copyWith(fontSize: 11, letterSpacing: 1.3),
                ),
              ),
              if (compteur.pastille) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: c.primaire,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (compteur.onPresse == null) {
      return Semantics(
        label: '${nombre ?? ''} ${compteur.libelle}',
        excludeSemantics: true,
        child: contenu,
      );
    }
    return Semantics(
      button: true,
      label: '${nombre ?? ''} ${compteur.libelle}',
      excludeSemantics: true,
      child: InkWell(
        onTap: compteur.onPresse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiS),
        child: contenu,
      ),
    );
  }
}

/// La photo de profil, cerclée d'un anneau doré qui se dessine à
/// l'arrivée ; la pastille crayon pour modifier son profil.
class _PhotoCerclee extends StatelessWidget {
  const _PhotoCerclee({
    required this.pseudo,
    required this.photoUrl,
    required this.onModifier,
  });

  final String pseudo;
  final String? photoUrl;
  final VoidCallback? onModifier;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1300),
              curve: Curves.easeInOutCubic,
              builder: (context, avancee, _) =>
                  CustomPaint(painter: _PeintreAnneau(avancee, c.primaire)),
            ),
          ),
          Center(
            child: TablAvatar(pseudo: pseudo, photoUrl: photoUrl, rayon: 42),
          ),
          if (onModifier != null)
            Positioned(
              right: -4,
              bottom: -4,
              child: Semantics(
                button: true,
                label: 'Modifier le profil',
                excludeSemantics: true,
                child: Material(
                  color: c.primaire,
                  shape: CircleBorder(
                    side: BorderSide(color: c.fond, width: 3),
                  ),
                  child: InkWell(
                    onTap: onModifier,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: c.texteSurPrimaire,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeintreAnneau extends CustomPainter {
  _PeintreAnneau(this.avancee, this.couleur);

  final double avancee;
  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * avancee,
      false,
      Paint()
        ..color = couleur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_PeintreAnneau ancien) =>
      ancien.avancee != avancee || ancien.couleur != couleur;
}
