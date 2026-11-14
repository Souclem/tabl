import 'package:flutter/material.dart';

import '../../theme/tokens.dart';
import '../tremblement.dart';

/// Un brouillon de la liste, prêt à l'affichage.
typedef BrouillonAffiche = ({
  String id,

  /// Sa couverture.
  ImageProvider image,

  /// Le lieu, ou « Repas en cours ».
  String titre,

  /// « Aujourd'hui · déjeuner · 12 h 30 · 3 photos ».
  String detail,
});

/// Ce que propose « + » quand des moments sont en cours : les brouillons,
/// un par ligne (toute la ligne le reprend, la corbeille le supprime), puis
/// « Nouveau moment » en dernier. [libelleLimite] remplace « Nouveau
/// moment » d'un mot d'explication quand il n'est pas possible ; le
/// toucher quand même fait grossir et trembler la ligne, et vibrer le
/// téléphone.
///
/// Toujours sombre, comme la caméra où elle mène.
class TablListeBrouillons extends StatelessWidget {
  const TablListeBrouillons({
    super.key,
    required this.brouillons,
    required this.libelleNouveau,
    required this.libelleSupprimer,
    required this.onReprendre,
    required this.onSupprimer,
    required this.onNouveau,
    this.libelleLimite,
  });

  static const double largeurMiniature = 44;
  static const double hauteurMiniature = 58;

  final List<BrouillonAffiche> brouillons;

  /// « Nouveau moment ».
  final String libelleNouveau;

  /// Lu par les lecteurs d'écran sur la corbeille.
  final String libelleSupprimer;

  /// Non nul : « Nouveau moment » est grisé, et ce texte dit pourquoi.
  final String? libelleLimite;

  final ValueChanged<String> onReprendre;

  /// La corbeille ; la confirmation est à l'écran.
  final ValueChanged<String> onSupprimer;
  final VoidCallback onNouveau;

  @override
  Widget build(BuildContext context) {
    final limite = libelleLimite;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in brouillons)
          _LigneBrouillon(
            key: ValueKey(b.id),
            brouillon: b,
            libelleSupprimer: libelleSupprimer,
            onReprendre: () => onReprendre(b.id),
            onSupprimer: () => onSupprimer(b.id),
          ),
        _LigneNouveau(
          libelle: libelleNouveau,
          limite: limite,
          onNouveau: onNouveau,
        ),
      ],
    );
  }
}

class _LigneBrouillon extends StatelessWidget {
  const _LigneBrouillon({
    super.key,
    required this.brouillon,
    required this.libelleSupprimer,
    required this.onReprendre,
    required this.onSupprimer,
  });

  final BrouillonAffiche brouillon;
  final String libelleSupprimer;
  final VoidCallback onReprendre;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final vide = ColoredBox(
      color: c.texte.withValues(alpha: 0.08),
      child: Icon(Icons.photo_outlined, color: c.texteDoux, size: 20),
    );
    return InkWell(
      onTap: onReprendre,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: c.texte.withValues(alpha: 0.07)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: c.texte.withValues(alpha: 0.6),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: TablListeBrouillons.largeurMiniature,
                    height: TablListeBrouillons.hauteurMiniature,
                    child: Image(
                      image: brouillon.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => vide,
                    ),
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
                      brouillon.titre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.policeCreation.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      brouillon.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TablTokens.policeCreation.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: c.texte.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onSupprimer,
                tooltip: libelleSupprimer,
                icon: const Icon(Icons.delete_outline_rounded, size: 21),
                color: c.texte.withValues(alpha: 0.62),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Nouveau moment ». Grisé ([limite] non nul), un toucher ne crée rien :
/// la ligne grossit, tremble de gauche à droite et le téléphone vibre, pour
/// dire que ce n'est pas possible — l'explication est juste dessous.
class _LigneNouveau extends StatefulWidget {
  const _LigneNouveau({
    required this.libelle,
    required this.limite,
    required this.onNouveau,
  });

  final String libelle;
  final String? limite;
  final VoidCallback onNouveau;

  @override
  State<_LigneNouveau> createState() => _LigneNouveauState();
}

class _LigneNouveauState extends State<_LigneNouveau> {
  var _refus = 0;

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final limite = widget.limite;
    final libelleNouveau = widget.libelle;
    return Semantics(
      button: true,
      enabled: limite == null,
      child: InkWell(
        onTap: limite == null
            ? widget.onNouveau
            : () => setState(() => _refus++),
        child: TablTremblement(
          refus: _refus,
          alignement: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: TablListeBrouillons.largeurMiniature,
                  height: TablListeBrouillons.hauteurMiniature,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: limite == null
                          ? c.primaire
                          : c.texte.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: limite == null
                          ? c.texteSurPrimaire
                          : c.texte.withValues(alpha: 0.45),
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
                        libelleNouveau,
                        style: TablTokens.policeCreation.copyWith(
                          fontSize: 15,
                          color: limite == null
                              ? c.texte
                              : c.texte.withValues(alpha: 0.45),
                        ),
                      ),
                      if (limite != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          limite,
                          style: TablTokens.policeCreation.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w400,
                            color: c.texte.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ],
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
