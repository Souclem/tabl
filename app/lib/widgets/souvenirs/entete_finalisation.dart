import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';

/// Le haut de la finalisation, posé sur la photo sous « Plus tard » : le
/// lieu (touchez pour le changer), le moment du repas, et le mot quand il
/// y en a un (touchez pour le reprendre). Le texte arrive déjà prêt à
/// l'affichage.
class TablEnteteFinalisation extends StatelessWidget {
  const TablEnteteFinalisation({
    super.key,
    required this.lieu,
    required this.dateLisible,
    required this.legende,
    required this.onPresseLieu,
    required this.onPresseLegende,
    this.lieuPrive = false,
    this.hotePseudo,
    this.hotePhotoUrl,
    this.rappelLieu = false,
  });

  /// « Bibo », « Chez vous », « Chez Emma ». `null` : rien de choisi,
  /// « Où étiez-vous ? » en pointillé.
  final String? lieu;

  /// Pas un restaurant : la maison, jamais l'épingle (l'épingle veut dire
  /// « sur la carte »).
  final bool lieuPrive;

  /// Chez une personne de Tabl : sa photo à la place de la maison.
  final String? hotePseudo;
  final String? hotePhotoUrl;

  /// « Publier » grisé a été touché sans lieu : la ligne respire.
  final bool rappelLieu;
  final String dateLisible;

  /// Entre « », `null` : rien n'est encore écrit, rien ne s'affiche (le
  /// rail propose « Ajouter un mot »).
  final String? legende;
  final VoidCallback onPresseLieu;
  final VoidCallback onPresseLegende;

  static const _ombre = [Shadow(blurRadius: 10, color: Color(0x7307111F))];

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final lieu = this.lieu;
    final legende = this.legende;
    final hote = hotePseudo;
    final italique = c.titreAffichage.copyWith(
      fontSize: 21,
      height: 1.24,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w400,
      shadows: _ombre,
    );
    final texteLieu = TablTokens.policeCreation.copyWith(
      fontSize: 17,
      letterSpacing: -0.17,
      shadows: _ombre,
    );
    final ligne = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hote != null)
          SizedBox.square(
            dimension: 20,
            child: TablAvatar(pseudo: hote, photoUrl: hotePhotoUrl, rayon: 10),
          )
        else
          Icon(
            lieuPrive ? Icons.home_outlined : Icons.place_outlined,
            size: 15,
            color: c.primaire,
            shadows: _ombre,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            lieu ?? 'Où étiez-vous ?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texteLieu,
          ),
        ),
        if (lieu != null) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: c.texte.withValues(alpha: 0.7),
            shadows: _ombre,
          ),
        ],
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onPresseLieu,
              behavior: HitTestBehavior.opaque,
              child: _Respire(
                actif: rappelLieu,
                child: lieu != null
                    ? ligne
                    : CustomPaint(
                        painter: _Pointilles(
                          couleur: c.texte.withValues(alpha: 0.55),
                        ),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(9, 5, 12, 5),
                          decoration: BoxDecoration(
                            color: const Color(0x5907111F),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: ligne,
                        ),
                      ),
              ),
            ),
          ),
          if (dateLisible.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              dateLisible,
              style: TablTokens.policeCreation.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.texte.withValues(alpha: 0.74),
                shadows: _ombre,
              ),
            ),
          ],
          if (legende != null)
            Semantics(
              button: true,
              child: GestureDetector(
                onTap: onPresseLegende,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    legende,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: italique,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grossit un peu puis revient, deux fois, quand [actif] passe à `true`
/// (ou un contour doré si l'on a réduit les animations).
class _Respire extends StatefulWidget {
  const _Respire({required this.actif, required this.child});

  final bool actif;
  final Widget child;

  @override
  State<_Respire> createState() => _RespireState();
}

class _RespireState extends State<_Respire>
    with SingleTickerProviderStateMixin {
  late final _controleur = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  late final _echelle = TweenSequence<double>([
    for (var i = 0; i < 2; i++) ...[
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.08), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 0.98), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.98, end: 1), weight: 40),
    ],
  ]).animate(CurvedAnimation(parent: _controleur, curve: Curves.easeInOut));

  @override
  void didUpdateWidget(_Respire ancien) {
    super.didUpdateWidget(ancien);
    if (widget.actif && !ancien.actif) _controleur.forward(from: 0);
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: widget.actif
              ? Border.all(color: TablCouleurs.sombre.primaire, width: 2)
              : null,
        ),
        child: widget.child,
      );
    }
    return ScaleTransition(
      scale: _echelle,
      alignment: Alignment.centerLeft,
      child: widget.child,
    );
  }
}

/// Le contour en pointillé de « Où étiez-vous ? ».
class _Pointilles extends CustomPainter {
  const _Pointilles({required this.couleur});

  final Color couleur;

  @override
  void paint(Canvas canvas, Size size) {
    final contour = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(size.height / 2),
        ),
      );
    final pinceau = Paint()
      ..color = couleur
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final mesure in contour.computeMetrics()) {
      for (var d = 0.0; d < mesure.length; d += 7) {
        canvas.drawPath(mesure.extractPath(d, d + 4), pinceau);
      }
    }
  }

  @override
  bool shouldRepaint(_Pointilles ancien) => ancien.couleur != couleur;
}
