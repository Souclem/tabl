import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../avatar.dart';

/// La feuille des filtres de l'Explorer, sur papier clair (« A ·
/// Carnet », maquette de Martin) : le titre et le nombre d'adresses en
/// haut, une ligne par filtre, puis « Tout effacer » et « Voir 12
/// adresses ». Rien ne s'applique avant ce bouton ; « Fermer » renonce.
///
/// Composant pur : les lignes arrivent toutes faites ([lignes]), les
/// libellés prêts à afficher.
class TablFeuilleCarnet extends StatelessWidget {
  const TablFeuilleCarnet({
    super.key,
    required this.lignes,
    required this.libelleVoir,
    required this.onVoir,
    required this.onFermer,
    this.compte,
    this.onToutEffacer,
  });

  /// "12 adresses" ; `null` pendant qu'on compte.
  final String? compte;

  /// Des [TablLigneCarnet] et [TablInterrupteurCarnet], de haut en bas.
  final List<Widget> lignes;

  /// "Voir 12 adresses", "Aucune adresse".
  final String libelleVoir;
  final VoidCallback onVoir;
  final VoidCallback onFermer;

  /// `null` : aucun filtre à effacer.
  final VoidCallback? onToutEffacer;

  @override
  Widget build(BuildContext context) {
    final compte = this.compte;
    final c = TablCouleurs.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 7),
            width: 38,
            height: 5,
            decoration: BoxDecoration(
              color: c.texte.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 10, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Filtres',
                style: c.titreAffichage.copyWith(fontSize: 25, color: c.texte),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: compte == null
                    ? const SizedBox.shrink()
                    : Text(
                        compte,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: c.titreAffichage.copyWith(
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
                          color: c.texteDoux,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
              ),
              TextButton(
                onPressed: onFermer,
                style: TextButton.styleFrom(foregroundColor: c.texteDoux),
                child: Text(
                  'Fermer',
                  style: c.corps.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.texteDoux,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < lignes.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: c.texte.withValues(alpha: 0.08)),
                  lignes[i],
                ],
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: c.texte.withValues(alpha: 0.08)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                TextButton(
                  onPressed: onToutEffacer,
                  style: TextButton.styleFrom(foregroundColor: c.texteDoux),
                  child: Text(
                    'Tout effacer',
                    style: c.corps.copyWith(
                      fontWeight: FontWeight.w600,
                      color: c.texteDoux.withValues(
                        alpha: onToutEffacer == null ? 0.35 : 1,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onVoir,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.texte,
                    foregroundColor: c.fond,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    libelleVoir,
                    style: TablTokens.libelleBouton.copyWith(
                      color: c.fond,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Un filtre sur une ligne : son nom, sa valeur à droite, un chevron ;
/// un toucher déplie de quoi le régler ([contenu]). Un point doré dit
/// qu'il est actif.
class TablLigneCarnet extends StatelessWidget {
  const TablLigneCarnet({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.ouverte,
    required this.onPresse,
    required this.contenu,
    this.actif = false,
  });

  final String libelle;

  /// "Toutes", "Italien +2".
  final String valeur;
  final bool actif;
  final bool ouverte;
  final VoidCallback onPresse;

  /// Ce qui se déplie ; construit seulement quand la ligne est ouverte.
  final Widget contenu;

  static const _courbe = Cubic(0.2, 1, 0.3, 1);

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: ouverte,
          child: InkWell(
            onTap: onPresse,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Row(
                children: [
                  Text(
                    libelle,
                    style: c.corps.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.texte,
                    ),
                  ),
                  if (actif)
                    Container(
                      margin: const EdgeInsets.only(left: 7, bottom: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: c.primaire,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      valeur,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.corps.copyWith(
                        fontSize: 14.5,
                        fontWeight: actif ? FontWeight.w600 : FontWeight.w400,
                        color: actif ? c.texte : c.texteDoux,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: ouverte ? 0.5 : 0,
                    duration: const Duration(milliseconds: 350),
                    curve: _courbe,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: c.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: _courbe,
          alignment: Alignment.topCenter,
          child: ouverte
              ? Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 16),
                  child: contenu,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Un filtre qui s'allume ou s'éteint (« Dans mes envies »).
class TablInterrupteurCarnet extends StatelessWidget {
  const TablInterrupteurCarnet({
    super.key,
    required this.libelle,
    required this.actif,
    required this.onChanger,
  });

  final String libelle;
  final bool actif;
  final VoidCallback onChanger;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      toggled: actif,
      label: libelle,
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanger,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  libelle,
                  style: c.corps.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.texte,
                  ),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 46,
                height: 28,
                padding: const EdgeInsets.all(3),
                alignment: actif ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: actif ? c.texte : c.bordure,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0x33000000), blurRadius: 3),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Un choix parmi quelques-uns, en cases de même largeur sur un fond de
/// lin (« 3 derniers mois · 1 an · Tout »).
class TablSegmentsCarnet extends StatelessWidget {
  const TablSegmentsCarnet({
    super.key,
    required this.options,
    required this.choisi,
    required this.onChoisir,
  });

  final List<String> options;
  final int choisi;
  final ValueChanged<int> onChoisir;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.fond,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              child: Semantics(
                button: true,
                selected: i == choisi,
                label: options[i],
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChoisir(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == choisi ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: i == choisi
                          ? [
                              BoxShadow(
                                color: c.texte.withValues(alpha: 0.14),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      options[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: c.legende.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: i == choisi ? c.texte : c.texteDoux,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Des pastilles à choisir, une ou plusieurs (cuisines, Tables).
class TablPastillesCarnet extends StatelessWidget {
  const TablPastillesCarnet({
    super.key,
    required this.options,
    required this.choisies,
    required this.onBasculer,
  });

  final List<String> options;
  final Set<int> choisies;
  final ValueChanged<int> onBasculer;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < options.length; i++)
          _Pastille(
            libelle: options[i],
            choisie: choisies.contains(i),
            onPresse: () => onBasculer(i),
          ),
      ],
    );
  }
}

/// De grandes cases avec une icône, pour le moment du repas.
class TablTuilesCarnet extends StatelessWidget {
  const TablTuilesCarnet({
    super.key,
    required this.options,
    required this.choisies,
    required this.onBasculer,
  });

  final List<({String libelle, IconData icone})> options;
  final Set<int> choisies;
  final ValueChanged<int> onBasculer;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              button: true,
              selected: choisies.contains(i),
              label: options[i].libelle,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onBasculer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: _fondChoix(c, choisies.contains(i), 14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        options[i].icone,
                        size: 20,
                        color: _encreChoix(c, choisies.contains(i)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        options[i].libelle,
                        style: c.legende.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _encreChoix(c, choisies.contains(i)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Un proche, prêt à afficher dans [TablRechercheProche].
class ProcheAffiche {
  const ProcheAffiche({
    required this.pseudo,
    required this.onPresse,
    this.photoUrl,
    this.lettresSoulignees = 0,
    this.choisi = false,
  });

  final String pseudo;
  final String? photoUrl;

  /// Combien de lettres du début du pseudo correspondent à la recherche.
  final int lettresSoulignees;
  final bool choisi;
  final VoidCallback onPresse;
}

/// « Un proche » : une loupe, ce qu'on tape, les proches qui y
/// correspondent ; celui qu'on a choisi porte une coche.
class TablRechercheProche extends StatelessWidget {
  const TablRechercheProche({
    super.key,
    required this.controleur,
    required this.onChanged,
    required this.proches,
    this.aide,
  });

  final TextEditingController controleur;
  final ValueChanged<String> onChanged;
  final List<ProcheAffiche> proches;

  /// Sous la liste : "Et 3 autres · précisez", "Aucun proche ne
  /// s'appelle « x »."
  final String? aide;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 44,
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: c.surfaceBasse,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.texte.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 18, color: c.texteDoux),
              const SizedBox(width: 9),
              Expanded(
                child: TextField(
                  controller: controleur,
                  onChanged: onChanged,
                  autocorrect: false,
                  cursorColor: c.texte,
                  style: c.corps.copyWith(fontSize: 16, color: c.texte),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Chercher un proche',
                    hintStyle: c.corps.copyWith(
                      fontSize: 16,
                      color: c.texteDoux,
                    ),
                  ),
                ),
              ),
              if (controleur.text.isNotEmpty)
                IconButton(
                  tooltip: 'Effacer la recherche',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    controleur.clear();
                    onChanged('');
                  },
                  icon: Icon(Icons.close_rounded, size: 16, color: c.texteDoux),
                ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        for (final p in proches) _LigneProche(proche: p),
        if (aide != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
            child: Text(
              aide!,
              style: c.legende.copyWith(fontSize: 12.5, color: c.texteDoux),
            ),
          ),
      ],
    );
  }
}

class _LigneProche extends StatelessWidget {
  const _LigneProche({required this.proche});

  final ProcheAffiche proche;

  @override
  Widget build(BuildContext context) {
    final p = proche;
    final c = TablCouleurs.of(context);
    final style = c.corps.copyWith(fontWeight: FontWeight.w600);
    final n = p.lettresSoulignees.clamp(0, p.pseudo.length);
    return Semantics(
      button: true,
      selected: p.choisi,
      label: p.pseudo,
      excludeSemantics: true,
      child: InkWell(
        onTap: p.onPresse,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Row(
            children: [
              TablAvatar(pseudo: p.pseudo, photoUrl: p.photoUrl, rayon: 15),
              const SizedBox(width: 11),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [
                      TextSpan(
                        text: p.pseudo.substring(0, n),
                        style: TextStyle(
                          decoration: TextDecoration.underline,
                          decorationColor: c.primaire,
                          decorationThickness: 2,
                        ),
                      ),
                      TextSpan(text: p.pseudo.substring(n)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (p.choisi) Icon(Icons.check_rounded, size: 22, color: c.texte),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pastille extends StatelessWidget {
  const _Pastille({
    required this.libelle,
    required this.choisie,
    required this.onPresse,
  });

  final String libelle;
  final bool choisie;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      selected: choisie,
      label: libelle,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: _fondChoix(c, choisie, 18),
          // Une Row plutôt qu'un alignement : la pastille garde la largeur
          // de son texte au lieu de prendre toute la ligne.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                libelle,
                style: c.legende.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: choisie ? c.fond : c.texte,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _fondChoix(TablCouleurs c, bool choisi, double arrondi) =>
    BoxDecoration(
      color: choisi ? c.texte : c.surfaceBasse,
      borderRadius: BorderRadius.circular(arrondi),
      border: choisi ? null : Border.all(color: c.bordure),
    );

Color _encreChoix(TablCouleurs c, bool choisi) => choisi ? c.fond : c.texteDoux;
