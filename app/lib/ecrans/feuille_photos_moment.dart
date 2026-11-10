import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// « Photos du moment » : les photos du brouillon, une par ligne. On les
/// range en tirant la poignée (la première est la couverture), on en retire
/// une de la publication sans la perdre, on la supprime (récupérable 30
/// jours), ou l'on reprend des photos. Au-delà de dix photos à publier, la
/// feuille demande de choisir lesquelles retirer.
///
/// Chaque geste est écrit aussitôt dans le brouillon : fermer la feuille
/// n'a rien à sauvegarder. Rend `true` si l'on veut reprendre des photos
/// ([peutReprendre] : sinon le bouton n'est pas proposé).
Future<bool> ouvrirFeuillePhotos(
  BuildContext context, {
  required BrouillonsLocaux brouillons,
  required Brouillon brouillon,
  required bool peutReprendre,
}) async {
  final c = TablCouleurs.of(context);
  final reprendre = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: c.surface,
    showDragHandle: true,
    builder: (_) => _FeuillePhotos(
      brouillons: brouillons,
      brouillon: brouillon,
      peutReprendre: peutReprendre,
    ),
  );
  return reprendre ?? false;
}

class _FeuillePhotos extends StatefulWidget {
  const _FeuillePhotos({
    required this.brouillons,
    required this.brouillon,
    required this.peutReprendre,
  });

  final BrouillonsLocaux brouillons;
  final Brouillon brouillon;
  final bool peutReprendre;

  @override
  State<_FeuillePhotos> createState() => _FeuillePhotosState();
}

class _FeuillePhotosState extends State<_FeuillePhotos> {
  late Brouillon _brouillon = widget.brouillon;

  /// La dernière photo supprimée, que le bandeau propose de remettre.
  PhotoCorbeille? _supprimee;
  Timer? _finBandeau;

  @override
  void dispose() {
    _finBandeau?.cancel();
    super.dispose();
  }

  /// Applique [geste] au brouillon écrit sur le téléphone, puis garde ce
  /// qu'il a rendu ; en cas d'échec, relit le brouillon tel qu'il est.
  Future<void> _ecrire(Future<Brouillon?> Function() geste) async {
    try {
      final maj = await geste();
      if (maj != null && mounted) setState(() => _brouillon = maj);
    } catch (e) {
      debugPrint('FeuillePhotos: $e');
      final relu = await widget.brouillons.charger(_brouillon.id);
      if (!mounted) return;
      if (relu != null) setState(() => _brouillon = relu);
      afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _reordonner(int ancienne, int nouvelle) {
    final ids = [for (final p in _brouillon.photos) p.id];
    ids.insert(nouvelle, ids.removeAt(ancienne));
    final photos = {for (final p in _brouillon.photos) p.id: p};
    // L'ordre se voit tout de suite ; le fichier le suit.
    setState(() {
      _brouillon = _brouillon.copieAvec(
        photos: [for (final id in ids) photos[id]!],
      );
    });
    return _ecrire(
      () => widget.brouillons.reordonnerPhotos(_brouillon.id, ids),
    );
  }

  Future<void> _basculerRetrait(String photoId) {
    final retirees = {..._brouillon.horsPublicationIds};
    if (!retirees.remove(photoId)) retirees.add(photoId);
    return _ecrire(
      () => widget.brouillons.mettreAJour(
        _brouillon.id,
        (b) => b.copieAvec(horsPublicationIds: retirees),
      ),
    );
  }

  Future<void> _supprimer(String photoId) async {
    PhotoCorbeille? entree;
    await _ecrire(() async {
      entree = await widget.brouillons.supprimerPhoto(_brouillon.id, photoId);
      return widget.brouillons.charger(_brouillon.id);
    });
    if (entree == null || !mounted) return;
    _finBandeau?.cancel();
    setState(() => _supprimee = entree);
    _finBandeau = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _supprimee = null);
    });
  }

  Future<void> _remettre() async {
    final entree = _supprimee;
    if (entree == null) return;
    _finBandeau?.cancel();
    setState(() => _supprimee = null);
    await _ecrire(() => widget.brouillons.restaurerPhoto(entree.photo.id));
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final total = _brouillon.photos.length;
    final aPublier = _brouillon.photosAPublier.length;
    final consigne = consignePhotos(aPublier: aPublier, total: total);
    final publiable = nombrePhotosPublicable(aPublier);
    final trop = aPublier > nombreMaxPhotosSouvenir;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TablTokens.espaceL - 4,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      'Photos du moment',
                      style: c.titreAffichage.copyWith(fontSize: 26),
                    ),
                  ),
                  Text(
                    compteurPhotosAPublier(aPublier),
                    style: c.legende.copyWith(
                      color: trop ? c.primaire : c.texteDoux,
                    ),
                  ),
                ],
              ),
            ),
            if (consigne != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
                  TablTokens.espaceS,
                  TablTokens.espaceL - 4,
                  0,
                ),
                child: Text(
                  consigne,
                  style: c.legende.copyWith(color: c.primaire),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceM,
                  TablTokens.espaceS,
                  TablTokens.espaceXs,
                  0,
                ),
                child: TablListePhotosMoment(
                  photos: [
                    for (var i = 0; i < _brouillon.photos.length; i++)
                      (
                        id: _brouillon.photos[i].id,
                        image: widget.brouillons.imagePhoto(
                          _brouillon.id,
                          _brouillon.photos[i].id,
                        ),
                        titre: titrePhotoMoment(i),
                        retiree: _brouillon.horsPublicationIds.contains(
                          _brouillon.photos[i].id,
                        ),
                      ),
                  ],
                  libelleRetirer: 'Retirer de la publication',
                  libelleRemettre: 'Remettre dans la publication',
                  libelleSupprimer: 'Supprimer la photo',
                  libellePhotoRetiree: 'Pas dans la publication',
                  onReordonner: _reordonner,
                  onBasculerRetrait: _basculerRetrait,
                  onSupprimer: _supprimer,
                ),
              ),
            ),
            if (_supprimee != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL - 4,
                  TablTokens.espaceS,
                  TablTokens.espaceL - 4,
                  0,
                ),
                child: TablBandeauAnnulation(
                  texte: 'Photo supprimée · récupérable 30 jours',
                  libelleAnnuler: 'Annuler',
                  onAnnuler: _remettre,
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                TablTokens.espaceS,
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.peutReprendre)
                    TablBoutonTexte(
                      libelle: 'Reprendre des photos',
                      onPresse: () => Navigator.of(context).pop(true),
                    ),
                  TablBouton(
                    libelle: 'Valider',
                    onPresse: publiable
                        ? () => Navigator.of(context).pop(false)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
