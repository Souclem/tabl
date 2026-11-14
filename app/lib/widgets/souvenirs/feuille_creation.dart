import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import 'commandes_finalisation.dart';
import 'verre_camera.dart';

// Les feuilles de la finalisation (« Où et quand », « Ce qui ressort »,
// « Avec qui »…), dans le style du prototype « Création V5 » : verre sombre
// posé sur la photo, titre court, rubriques en petites capitales, lignes à
// cocher, et le bouton en bas à droite. Toujours sombres, comme la caméra.

const _c = TablCouleurs.sombre;
const _marge = 20.0;

/// Le voile posé sur la photo derrière une feuille.
const voileFeuilleCreation = Color(0x3807111F);

/// Le cadre d'une feuille : la poignée, le [titre] (et une [note] à droite,
/// « facultatif »), le [contenu] qui défile, le [pied] qui reste toujours
/// visible, puis le bouton [libelleAction] en bas à droite ([dore] : en or
/// plutôt qu'en verre). [chaud] : le verre se réchauffe (« Où et quand »
/// hors restaurant).
class TablCadreFeuilleCreation extends StatelessWidget {
  const TablCadreFeuilleCreation({
    super.key,
    required this.titre,
    required this.contenu,
    this.note,
    this.libelleAction,
    this.onAction,
    this.pied,
    this.dore = false,
    this.chaud = false,
    this.hauteurMax = 0.85,
  });

  final String titre;
  final String? note;
  final Widget contenu;
  final Widget? pied;
  final String? libelleAction;
  final VoidCallback? onAction;
  final bool dore;
  final bool chaud;

  /// La part de l'écran que la feuille peut prendre au plus.
  final double hauteurMax;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final action = libelleAction;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: flouVerre,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: chaud
                ? const Color(0xB82E1E10)
                : const Color(0xFF07111F).withValues(alpha: teinteVerre),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: chaud
                    ? _c.primaire.withValues(alpha: 0.45)
                    : _c.texte.withValues(alpha: 0.12),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: media.size.height * hauteurMax,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: _c.texte.withValues(alpha: 0.26),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(_marge, 10, _marge, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            titre,
                            style: TablTokens.policeCreation.copyWith(
                              fontSize: 17,
                              letterSpacing: -0.17,
                            ),
                          ),
                        ),
                        if (note case final note?)
                          Text(
                            note,
                            style: TablTokens.policeCreation.copyWith(
                              fontSize: 13,
                              color: _c.texte.withValues(alpha: 0.66),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(_marge, 0, _marge, 6),
                      child: contenu,
                    ),
                  ),
                  if (pied case final pied?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(_marge, 0, _marge, 0),
                      child: pied,
                    ),
                  if (action != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        14,
                        8,
                        14,
                        14 +
                            (media.viewInsets.bottom > 0
                                ? 0
                                : media.padding.bottom),
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TablBoutonPrincipalFinalisation(
                          libelle: action,
                          vitre: !dore,
                          onPresse: onAction,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: 14 + media.padding.bottom),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// « PRÈS DE VOS PHOTOS » : une rubrique de feuille.
class TablRubriqueCreation extends StatelessWidget {
  const TablRubriqueCreation(this.texte, {super.key, this.premiere = false});

  final String texte;

  /// La première de la feuille : collée au titre.
  final bool premiere;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: premiere ? 2 : 14, bottom: 8),
      child: Text(
        texte.toUpperCase(),
        style: TablTokens.policeCreation.copyWith(
          fontSize: 11,
          letterSpacing: 0.88,
          color: _c.texte.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

/// Le champ de recherche d'une feuille : une pilule de 44 px. Sert aussi
/// à écrire un nom ([icone] autre que la loupe, [actionClavier] « OK »).
class TablRechercheCreation extends StatelessWidget {
  const TablRechercheCreation({
    super.key,
    required this.controleur,
    required this.indication,
    required this.onChanged,
    this.onSoumis,
    this.icone = Icons.search_rounded,
    this.autofocus = false,
    this.actionClavier = TextInputAction.search,
    this.erreur,
  });

  final TextEditingController controleur;
  final String indication;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSoumis;
  final IconData icone;
  final bool autofocus;
  final TextInputAction actionClavier;

  /// Sous le champ, en rouge (un nom qui ne va pas).
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final style = TablTokens.policeCreation.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );
    final erreur = this.erreur;
    if (erreur == null) return _champ(style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _champ(style),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 4),
          child: Text(
            erreur,
            style: TablTokens.policeCreation.copyWith(
              fontSize: 12.5,
              color: _c.erreur,
            ),
          ),
        ),
      ],
    );
  }

  Widget _champ(TextStyle style) {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _c.texte.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: _c.texte.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controleur,
              onChanged: onChanged,
              onSubmitted: onSoumis,
              autofocus: autofocus,
              style: style,
              cursorColor: _c.primaire,
              // Un nom s'écrit avec sa majuscule ; une recherche, non.
              textCapitalization: actionClavier == TextInputAction.search
                  ? TextCapitalization.none
                  : TextCapitalization.sentences,
              textInputAction: actionClavier,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: indication,
                hintStyle: style.copyWith(
                  color: _c.texte.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La maison, à droite de la recherche d'« Où et quand » : touchée, la
/// feuille quitte les restaurants ([actif] : dorée).
class TablBoutonMaisonCreation extends StatelessWidget {
  const TablBoutonMaisonCreation({
    super.key,
    required this.actif,
    required this.onPresse,
  });

  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: actif,
      label: 'Pas au restaurant',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: actif ? _c.primaire : _c.texte.withValues(alpha: 0.08),
            border: Border.all(
              color: actif ? _c.primaire : _c.texte.withValues(alpha: 0.16),
            ),
          ),
          // La maison change avec un petit rebond (pleine quand elle est
          // touchée).
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            transitionBuilder: (enfant, animation) => ScaleTransition(
              scale: Tween<double>(begin: 0.4, end: 1).animate(animation),
              child: RotationTransition(
                turns: Tween<double>(begin: -0.08, end: 0).animate(animation),
                child: FadeTransition(opacity: animation, child: enfant),
              ),
            ),
            child: Icon(
              actif ? Icons.home_rounded : Icons.home_outlined,
              key: ValueKey(actif),
              size: 20,
              color: actif
                  ? const Color(0xFF07111F)
                  : _c.texte.withValues(alpha: 0.62),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un choix en rond, dans une rangée qui défile de côté (« Chez qui ? ») :
/// une photo ([avatar]) ou une [icone], le [libelle] dessous, et quand il
/// est [choisi], un anneau doré et une coche. [semantique] : ce que lit
/// VoiceOver (« Chez emma »), quand le libellé seul ne suffit pas.
class TablRondChoixCreation extends StatelessWidget {
  const TablRondChoixCreation({
    super.key,
    required this.libelle,
    required this.choisi,
    required this.onPresse,
    this.avatar,
    this.icone,
    this.semantique,
  });

  final String libelle;
  final bool choisi;
  final VoidCallback onPresse;
  final Widget? avatar;
  final IconData? icone;
  final String? semantique;

  static const double largeur = 68;
  static const double _diametre = 52;

  /// La hauteur d'une rangée de ronds, libellé compris (qui grandit avec
  /// la taille du texte choisie sur le téléphone).
  static double hauteur(BuildContext context) =>
      _diametre +
      6 +
      4 +
      MediaQuery.textScalerOf(context).scale(12.5 * 1.5) +
      2;

  @override
  Widget build(BuildContext context) {
    final avatar = this.avatar;
    return Semantics(
      button: true,
      selected: choisi,
      label: semantique ?? libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: largeur,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _diametre + 6,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: choisi ? _c.primaire : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Container(
                        width: _diametre - 4,
                        height: _diametre - 4,
                        alignment: Alignment.center,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _c.texte.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: avatar != null
                            ? SizedBox.expand(child: avatar)
                            : Icon(icone, size: 20, color: _c.texte),
                      ),
                    ),
                    if (choisi)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _c.texte,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF07111F),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: Color(0xFF07111F),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                libelle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TablTokens.policeCreation.copyWith(
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: choisi ? FontWeight.w600 : FontWeight.w400,
                  color: _c.texte.withValues(alpha: choisi ? 1 : 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une ligne à choisir : un rond (initiales, photo ou « + »), le [titre] et
/// son [detail], et la case ronde à droite ([coche] `null` : pas de case).
class TablOptionCreation extends StatelessWidget {
  const TablOptionCreation({
    super.key,
    required this.titre,
    required this.onPresse,
    this.detail,
    this.initiales,
    this.avatar,
    this.icone,
    this.coche,
  });

  final String titre;
  final String? detail;

  /// Dans le rond, au choix : les [initiales], un [avatar] (une personne,
  /// avec sa photo), une [icone].
  final String? initiales;
  final Widget? avatar;
  final IconData? icone;
  final bool? coche;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final coche = this.coche;
    final avatar = this.avatar;
    return Semantics(
      button: true,
      checked: coche,
      label: titre,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPresse,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _c.texte.withValues(alpha: 0.07)),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: _c.texte.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: avatar != null
                    ? SizedBox.expand(child: avatar)
                    : icone != null
                    ? Icon(icone, size: 17, color: _c.texte)
                    : Text(
                        initiales ?? '',
                        style: TablTokens.policeCreation.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.policeCreation.copyWith(fontSize: 15),
                    ),
                    if (detail case final detail?) ...[
                      const SizedBox(height: 1),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TablTokens.policeCreation.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w400,
                          color: _c.texte.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (coche != null) ...[
                const SizedBox(width: 12),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: coche ? _c.texte : Colors.transparent,
                    border: coche
                        ? null
                        : Border.all(
                            color: _c.texte.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                  ),
                  child: coche
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Color(0xFF07111F),
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Une pastille à choisir (« Déjeuner ») : choisie, elle passe en ivoire
/// avec une coche.
class TablPastilleCreation extends StatelessWidget {
  const TablPastilleCreation({
    super.key,
    required this.libelle,
    required this.choisie,
    required this.onPresse,
  });

  final String libelle;
  final bool choisie;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final encre = choisie ? const Color(0xFF07111F) : _c.texte;
    return Semantics(
      button: true,
      selected: choisie,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: choisie ? _c.texte : _c.texte.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(17),
            border: choisie
                ? null
                : Border.all(
                    color: _c.texte.withValues(alpha: 0.18),
                    width: 0.5,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choisie) ...[
                Icon(Icons.check_rounded, size: 14, color: encre),
                const SizedBox(width: 6),
              ],
              Text(
                libelle,
                style: TablTokens.policeCreation.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: encre,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La barre d'« Ajouter un mot », posée juste au-dessus du clavier : le
/// champ, le compte des caractères quand il approche de la limite, et
/// « OK ».
class TablBarreMot extends StatelessWidget {
  const TablBarreMot({
    super.key,
    required this.controleur,
    required this.indication,
    required this.onChanged,
    required this.onValider,
    this.compteur,
    this.erreur,
  });

  final TextEditingController controleur;
  final String indication;
  final ValueChanged<String> onChanged;
  final VoidCallback onValider;

  /// « 280 / 300 », quand la limite approche.
  final String? compteur;
  final String? erreur;

  @override
  Widget build(BuildContext context) {
    final style = TablTokens.policeCreation.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 22 / 16,
    );
    final erreur = this.erreur;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (erreur != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
              child: Text(
                erreur,
                style: TablTokens.policeCreation.copyWith(
                  fontSize: 12.5,
                  color: _c.erreur,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Color(0x99000000)),
                  ],
                ),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: flouVerre,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 5, 5, 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF07111F).withValues(alpha: teinteVerre),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _c.texte.withValues(alpha: 0.12)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: TextField(
                          controller: controleur,
                          autofocus: true,
                          minLines: 1,
                          maxLines: 4,
                          onChanged: onChanged,
                          style: style,
                          cursorColor: _c.primaire,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: indication,
                            hintStyle: style.copyWith(
                              color: _c.texte.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (compteur case final compteur?)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 4, 12),
                        child: Text(
                          compteur,
                          style: TablTokens.policeCreation.copyWith(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: _c.texte.withValues(alpha: 0.6),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'OK',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: onValider,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _c.texte,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'OK',
                            style: TablTokens.policeCreation.copyWith(
                              fontSize: 15,
                              color: const Color(0xFF07111F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
