import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../bulles_personnes.dart';

/// Le titre de l'Explorer : la ville qu'on regarde, en grand, avec de
/// quoi en changer (⌄), et ce qu'on y trouve dessous.
class TablTitreExplorer extends StatelessWidget {
  const TablTitreExplorer({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.onPresse,
  });

  /// "Liège".
  final String titre;

  /// "12 adresses connues par vos proches".
  final String sousTitre;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$titre. $sousTitre. Changer de ville',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPresse,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.titreAffichage.copyWith(
                      fontSize: 34,
                      height: 1.05,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: TablTokens.texteDoux,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              sousTitre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TablTokens.legende.copyWith(
                fontSize: 13.5,
                color: TablTokens.texte.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bouton rond des filtres, avec le nombre de filtres actifs dans
/// une pastille dorée.
class TablBoutonFiltres extends StatelessWidget {
  const TablBoutonFiltres({
    super.key,
    required this.actifs,
    required this.onPresse,
  });

  final int actifs;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: actifs == 0 ? 'Filtres' : 'Filtres, $actifs actifs',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: actifs > 0
                      ? TablTokens.primaire.withValues(alpha: 0.14)
                      : const Color(0xCC161A22),
                  border: Border.all(
                    color: actifs > 0
                        ? TablTokens.primaire.withValues(alpha: 0.55)
                        : TablTokens.texte.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: actifs > 0 ? TablTokens.primaire : TablTokens.texte,
                ),
              ),
              if (actifs > 0)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TablTokens.primaire,
                      border: Border.all(color: TablTokens.fond, width: 1.5),
                    ),
                    child: Text(
                      '$actifs',
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: TablTokens.texteSurPrimaire,
                      ),
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

/// Un filtre actif, qu'on retire d'un tap sur sa croix (« Dîner ✕ »).
class TablPuceRetirable extends StatelessWidget {
  const TablPuceRetirable({
    super.key,
    required this.libelle,
    required this.onRetirer,
  });

  final String libelle;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retirer le filtre $libelle',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onRetirer,
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 12, right: 8),
          decoration: BoxDecoration(
            color: TablTokens.primaire.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(TablTokens.arrondiBouton),
            border: Border.all(
              color: TablTokens.primaire.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                libelle,
                style: TablTokens.legende.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: TablTokens.texte,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.close_rounded,
                size: 14,
                color: TablTokens.primaire,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// La photo d'un lieu, ou à défaut sa première lettre sur un fond sombre
/// — jamais une image inventée.
class TablPhotoLieu extends StatelessWidget {
  const TablPhotoLieu({
    super.key,
    required this.nom,
    required this.url,
    this.taille = 64,
    this.rayon = TablTokens.arrondiM - 2,
    this.tailleLettre,
  });

  final String nom;
  final String? url;

  /// `null` : prend toute la place qu'on lui donne.
  final double? taille;
  final double rayon;
  final double? tailleLettre;

  @override
  Widget build(BuildContext context) {
    final lettre = nom.trim().isEmpty ? '·' : nom.trim()[0].toUpperCase();
    final repli = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1C1F26), Color(0xFF0E1014)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.75, 0.65),
        child: Text(
          lettre,
          style: TablTokens.titreAffichage.copyWith(
            fontSize: tailleLettre ?? (taille ?? 120) * 0.42,
            color: TablTokens.texte.withValues(alpha: 0.12),
          ),
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: SizedBox(
        width: taille,
        height: taille,
        child: url == null
            ? repli
            : Image.network(
                url!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => repli,
              ),
      ),
    );
  }
}

/// Un bouton secondaire d'une carte de lieu (« Proposer »,
/// « Enregistrer »).
class _ActionLieu extends StatelessWidget {
  const _ActionLieu({
    required this.icone,
    required this.libelle,
    required this.onPresse,
    this.dore = false,
  });

  final IconData icone;
  final String libelle;
  final VoidCallback onPresse;
  final bool dore;

  @override
  Widget build(BuildContext context) {
    final couleur = dore ? TablTokens.primaire : TablTokens.texte;
    return Expanded(
      child: Semantics(
        button: true,
        label: libelle,
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onPresse,
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: dore
                  ? TablTokens.primaire.withValues(alpha: 0.1)
                  : const Color(0xFF1A1C21),
              borderRadius: BorderRadius.circular(TablTokens.arrondiM - 4),
              border: Border.all(
                color: dore
                    ? TablTokens.primaire.withValues(alpha: 0.3)
                    : TablTokens.texte.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 16, color: couleur),
                const SizedBox(width: 6),
                Text(
                  libelle,
                  style: TablTokens.legende.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: couleur,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le lieu touché sur la carte, en carte posée en bas : sa photo, son
/// nom, qui le connaît et pourquoi il compte ; « Plus de détails » y
/// ajoute ce qu'ils en ont retenu. Puis « Voir la fiche » et les
/// actions rapides. Balayer la carte de côté passe au lieu voisin
/// ([onSuivant], [onPrecedent]).
///
/// Composant pur : tout arrive prêt à afficher.
class TablApercuLieu extends StatefulWidget {
  const TablApercuLieu({
    super.key,
    required this.nom,
    required this.detail,
    required this.photoUrl,
    required this.visages,
    required this.quiLaConnait,
    required this.onFermer,
    required this.onVoirFiche,
    required this.enregistre,
    required this.onEnregistrer,
    this.signal,
    this.ressentis = const [],
    this.dejaAlle,
    this.onProposer,
    this.onDemander,
    this.onSuivant,
    this.onPrecedent,
  });

  final String nom;

  /// "Italien · Hors-Château · 1,2 km".
  final String detail;
  final String? photoUrl;
  final List<BullePersonne> visages;

  /// "Emma, Martin +1 la connaissent".
  final String quiLaConnait;

  /// "Votre cercle revient ici".
  final String? signal;

  /// Leurs ressentis (emoji), pour « Ce qu'ils en ont retenu ».
  final List<String> ressentis;

  /// "Vous y êtes allé 3 fois, la dernière il y a 2 mois".
  final String? dejaAlle;
  final bool enregistre;
  final VoidCallback onFermer;
  final VoidCallback onVoirFiche;
  final VoidCallback onEnregistrer;

  /// `null` : pas de Table à qui le proposer.
  final VoidCallback? onProposer;

  /// `null` : personne à qui demander.
  final VoidCallback? onDemander;
  final VoidCallback? onSuivant;
  final VoidCallback? onPrecedent;

  @override
  State<TablApercuLieu> createState() => _TablApercuLieuState();
}

class _TablApercuLieuState extends State<TablApercuLieu> {
  bool _details = false;

  @override
  void didUpdateWidget(TablApercuLieu ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.nom != widget.nom) _details = false;
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final aDesDetails = w.ressentis.isNotEmpty || w.dejaAlle != null;
    return GestureDetector(
      onHorizontalDragEnd: (fin) {
        final vitesse = fin.primaryVelocity ?? 0;
        if (vitesse < -250) w.onSuivant?.call();
        if (vitesse > 250) w.onPrecedent?.call();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TablTokens.arrondiL),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xF20F1014),
              borderRadius: BorderRadius.circular(TablTokens.arrondiL),
              border: Border.all(
                color: TablTokens.texte.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TablPhotoLieu(nom: w.nom, url: w.photoUrl, taille: 62),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            w.nom,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TablTokens.titreAffichage.copyWith(
                              fontSize: 23,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            w.detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TablTokens.legende.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Fermer',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: w.onFermer,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TablTokens.texte.withValues(alpha: 0.06),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: TablTokens.texteDoux,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (w.visages.isNotEmpty) ...[
                      TablBullesPersonnes(bulles: w.visages, taille: 24),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        w.quiLaConnait,
                        style: TablTokens.corps.copyWith(
                          fontSize: 14,
                          color: TablTokens.texte,
                        ),
                      ),
                    ),
                  ],
                ),
                if (w.signal != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    '✦  ${w.signal}',
                    style: TablTokens.legende.copyWith(
                      fontSize: 13,
                      color: TablTokens.primaire,
                    ),
                  ),
                ],
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_details
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(
                                height: 1,
                                color: TablTokens.surface,
                              ),
                              if (w.dejaAlle != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  w.dejaAlle!,
                                  style: TablTokens.corps.copyWith(
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                              if (w.ressentis.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text(
                                      w.ressentis.take(5).join(' '),
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Ce qu\'ils en ont retenu',
                                      style: TablTokens.legende.copyWith(
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
                if (aDesDetails)
                  Center(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _details = !_details),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _details ? 'Réduire' : 'Plus de détails',
                              style: TablTokens.legende.copyWith(
                                fontSize: 12.5,
                                color: TablTokens.texte.withValues(alpha: 0.75),
                              ),
                            ),
                            Icon(
                              _details
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: TablTokens.texteDoux,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),
                Semantics(
                  button: true,
                  label: 'Voir la fiche de ${w.nom}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: w.onVoirFiche,
                    child: Container(
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TablTokens.primaire,
                        borderRadius: BorderRadius.circular(
                          TablTokens.arrondiM - 2,
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Voir la fiche',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: TablTokens.texteSurPrimaire,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 17,
                            color: TablTokens.texteSurPrimaire,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (w.onDemander != null) ...[
                      _ActionLieu(
                        icone: Icons.chat_bubble_outline_rounded,
                        libelle: 'Demander',
                        onPresse: w.onDemander!,
                        dore: true,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (w.onProposer != null) ...[
                      _ActionLieu(
                        icone: Icons.person_add_alt_1_outlined,
                        libelle: 'Proposer',
                        onPresse: w.onProposer!,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _ActionLieu(
                      icone: w.enregistre
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      libelle: w.enregistre ? 'Enregistré' : 'Enregistrer',
                      onPresse: w.onEnregistrer,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Le premier lieu de la liste, en grand : sa photo, son nom, et sous
/// une vitre qui le connaît et pourquoi il est là.
class TablCarteVedette extends StatelessWidget {
  const TablCarteVedette({
    super.key,
    required this.nom,
    required this.photoUrl,
    required this.quiLaConnait,
    required this.raison,
    required this.enregistre,
    required this.onPresse,
    required this.onEnregistrer,
    required this.onOptions,
  });

  final String nom;
  final String? photoUrl;
  final String quiLaConnait;

  /// Selon le tri : "Dernière visite il y a 3 jours", "4 proches y
  /// retournent"…
  final String? raison;
  final bool enregistre;
  final VoidCallback onPresse;
  final VoidCallback onEnregistrer;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$nom. $quiLaConnait',
      child: GestureDetector(
        onTap: onPresse,
        child: AspectRatio(
          aspectRatio: 1.25,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TablPhotoLieu(
                nom: nom,
                url: photoUrl,
                taille: null,
                rayon: TablTokens.arrondiL + 2,
                tailleLettre: 96,
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(TablTokens.arrondiL + 2),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Color(0x00000000), Color(0xD9000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6, bottom: 10),
                        child: Text(
                          nom,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TablTokens.titreAffichage.copyWith(
                            fontSize: 30,
                            height: 1.08,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 12),
                            ],
                          ),
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          TablTokens.arrondiM,
                        ),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                            color: const Color(0xB3121318),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        quiLaConnait,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TablTokens.corps.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: TablTokens.texte,
                                        ),
                                      ),
                                      if (raison != null)
                                        Text(
                                          raison!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TablTokens.legende.copyWith(
                                            fontSize: 13,
                                            color: TablTokens.primaire,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: onEnregistrer,
                                  tooltip: enregistre
                                      ? 'Retirer de mes envies'
                                      : 'Enregistrer',
                                  icon: Icon(
                                    enregistre
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_border_rounded,
                                    size: 20,
                                    color: enregistre
                                        ? TablTokens.primaire
                                        : TablTokens.texte,
                                  ),
                                ),
                                IconButton(
                                  onPressed: onOptions,
                                  tooltip: 'Plus',
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 20,
                                    color: TablTokens.texteDoux,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

/// Un lieu de « La suite » : vignette, nom, ce qui explique sa place, sa
/// cuisine et son quartier.
class TablLigneCercle extends StatelessWidget {
  const TablLigneCercle({
    super.key,
    required this.nom,
    required this.photoUrl,
    required this.raison,
    required this.detail,
    required this.onPresse,
    required this.onOptions,
  });

  final String nom;
  final String? photoUrl;

  /// "Emma la connaît · il y a 3 jours".
  final String? raison;

  /// "Italien · Hors-Château".
  final String detail;
  final VoidCallback onPresse;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPresse,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            TablPhotoLieu(nom: nom, url: photoUrl, taille: 66),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TablTokens.titreAffichage.copyWith(fontSize: 19),
                  ),
                  if (raison != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      raison!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.corps.copyWith(
                        fontSize: 13,
                        color: TablTokens.texte,
                      ),
                    ),
                  ],
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.legende.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: onOptions,
              tooltip: 'Plus',
              icon: const Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: TablTokens.texteDoux,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Les chiffres de ma Constellation, posés en bas de la carte (« 35
/// repas · 5 villes »).
class TablCompteursConstellation extends StatelessWidget {
  const TablCompteursConstellation({super.key, required this.chiffres});

  final List<({String nombre, String libelle})> chiffres;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < chiffres.length; i++) ...[
            if (i > 0) const SizedBox(width: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  chiffres[i].nombre,
                  style: TablTokens.titreAffichage.copyWith(
                    fontSize: 30,
                    height: 1,
                    color: TablTokens.primaire,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 10),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  chiffres[i].libelle.toUpperCase(),
                  style: TablTokens.legende.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w700,
                    color: TablTokens.texte.withValues(alpha: 0.7),
                    shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
