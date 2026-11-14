import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';

/// La caméra de la création d'un moment : plein écran, toujours sombre
/// (quelle que soit l'apparence de l'app). Elle travaille sur un seul
/// brouillon — [brouillon], choisi dans « Brouillons », ou un nouveau —
/// et chaque photo prise ou importée s'y ajoute à la suite, dès qu'elle est
/// prise ; fermer l'écran ne perd rien.
///
/// Toucher la pile déploie l'éventail des photos, dans l'ordre de
/// publication : agrandir une photo, la retirer (×, ou en la glissant vers
/// la corbeille), ou la déplacer (appui long, puis la glisser à sa nouvelle
/// place). Une photo retirée reste 30 jours dans la corbeille du téléphone ;
/// « Annuler » la remet aussitôt.
class EcranCamera extends StatefulWidget {
  const EcranCamera({
    super.key,
    required this.camera,
    required this.brouillons,
    required this.surContinuer,
    this.brouillon,
    this.positionService,
    this.choisirPhotos = photosDuTelephone,
    this.maintenant,
  });

  /// La vraie caméra en production, [FausseCamera] dans les tests.
  final CameraService camera;
  final BrouillonsLocaux brouillons;

  /// Le brouillon repris ; `null` : un nouveau moment, créé à la première
  /// photo.
  final Brouillon? brouillon;

  /// « Continuer » : le brouillon est prêt à être complété.
  final void Function(Brouillon brouillon) surContinuer;

  /// Pour dater et situer les photos prises ; sans lui, elles n'ont pas de
  /// position.
  final PositionService? positionService;

  /// Ouvre la photothèque ; déjà réduites, les photos gardent leur date et
  /// leur position.
  final ChoisirPhotos choisirPhotos;

  final DateTime Function()? maintenant;

  @override
  State<EcranCamera> createState() => _EcranCameraState();
}

/// Une photo prise : visible dans la pile dès qu'elle a atterri, « mouillée »
/// tant qu'elle n'est pas enregistrée.
class _PhotoEnAttente {
  _PhotoEnAttente(this.octets);

  final Uint8List octets;

  /// Connu une fois la photo enregistrée dans le brouillon.
  String? photoId;

  /// Elle s'envole encore du viseur vers la pile.
  var enVol = true;

  bool get terminee => photoId != null && !enVol;
}

class _EcranCameraState extends State<EcranCamera>
    with SingleTickerProviderStateMixin {
  late final SessionCamera _session = SessionCamera(
    widget.brouillons,
    actif: widget.brouillon,
    positionService: widget.positionService,
    maintenant: widget.maintenant,
  );
  late final AnimationController _eclair = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 80),
    value: 1,
  );

  final _enAttente = <_PhotoEnAttente>[];
  Timer? _delaiCompteur;
  var _compteurVisible = false;
  var _importEnCours = false;
  var _eventailOuvert = false;
  var _indiceEventailVu = false;
  int? _visionneuse;
  late ModeFlash _flash = widget.camera.flash;

  @override
  void initState() {
    super.initState();
    unawaited(widget.camera.demarrer());
    unawaited(_session.actualiserPosition());
  }

  @override
  void dispose() {
    _delaiCompteur?.cancel();
    _eclair.dispose();
    unawaited(widget.camera.fermer());
    super.dispose();
  }

  Future<void> _declencher() async {
    HapticFeedback.lightImpact();
    _eclair.forward(from: 0);
    final photo = await widget.camera.prendrePhoto();
    if (photo == null || !mounted) return;
    final attente = _PhotoEnAttente(photo.octets);
    if (MediaQuery.disableAnimationsOf(context)) attente.enVol = false;
    setState(() => _enAttente.add(attente));
    if (!attente.enVol) _afficherCompteur();
    try {
      final brouillon = await _session.ajouter(
        octets: photo.octets,
        priseLe: photo.priseLe,
      );
      attente.photoId = brouillon.photos.last.id;
      HapticFeedback.selectionClick();
    } catch (_) {
      _enAttente.remove(attente);
      if (mounted) {
        setState(() {});
        _message("La photo n'a pas pu être gardée. Réessayez.");
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (attente.terminee) _enAttente.remove(attente);
    });
  }

  void _volTermine(_PhotoEnAttente attente) {
    if (!mounted) return;
    setState(() {
      attente.enVol = false;
      if (attente.terminee) _enAttente.remove(attente);
    });
    _afficherCompteur();
  }

  void _afficherCompteur() {
    _delaiCompteur?.cancel();
    setState(() => _compteurVisible = true);
    _delaiCompteur = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _compteurVisible = false);
    });
  }

  Future<void> _importer(int restant) async {
    if (_importEnCours || restant <= 0) return;
    _importEnCours = true;
    try {
      final octets = await widget.choisirPhotos(restant);
      if (octets.isEmpty || !mounted) return;
      final photos = await lirePhotos(octets);
      await _session.ajouterImportees(photos);
      if (!mounted) return;
      _afficherCompteur();
    } catch (_) {
      if (mounted) _message("Les photos n'ont pas pu être importées.");
    } finally {
      _importEnCours = false;
    }
  }

  void _ouvrirEventail() {
    setState(() => _eventailOuvert = true);
  }

  void _fermerEventail() {
    setState(() {
      _eventailOuvert = false;
      _indiceEventailVu = true;
    });
  }

  Future<void> _importerDepuisEventail() async {
    _fermerEventail();
    await _importer(nombreMaxPhotosSouvenir);
  }

  Future<void> _retirerPhoto(String photoId) async {
    PhotoCorbeille? retiree;
    try {
      retiree = await _session.retirer(photoId);
    } catch (_) {
      retiree = null;
    }
    if (!mounted) return;
    if (retiree == null) {
      _message("La photo n'a pas pu être supprimée.");
      return;
    }
    final reste = _session.actif?.photos.isNotEmpty ?? false;
    setState(() {
      if (!reste) {
        _eventailOuvert = false;
        _visionneuse = null;
      }
    });
    final id = retiree.photo.id;
    _message(
      'Photo supprimée',
      action: SnackBarAction(
        label: 'Annuler',
        textColor: TablCouleurs.sombre.primaire,
        onPressed: () => _restaurerPhoto(id),
      ),
    );
  }

  /// L'éventail rend l'ordre de [visibles] (les dernières photos) : les
  /// autres gardent leur place, devant.
  Future<void> _reordonner(List<String> visibles) async {
    final photos = _session.actif?.photos ?? const <PhotoBrouillon>[];
    final avant = [
      for (final p in photos)
        if (!visibles.contains(p.id)) p.id,
    ];
    Brouillon? range;
    try {
      range = await _session.reordonner([...avant, ...visibles]);
    } catch (_) {
      range = null;
    }
    if (!mounted) return;
    setState(() {});
    if (range == null) _message("Les photos n'ont pas pu être déplacées.");
  }

  Future<void> _restaurerPhoto(String photoId) async {
    Brouillon? remis;
    try {
      remis = await _session.restaurer(photoId);
    } catch (_) {
      remis = null;
    }
    if (!mounted) return;
    if (remis == null) {
      _message("La photo n'est plus récupérable.");
      return;
    }
    setState(() {});
  }

  Future<void> _changerFlash() async {
    final suivant =
        ModeFlash.values[(_flash.index + 1) % ModeFlash.values.length];
    setState(() => _flash = suivant);
    await widget.camera.definirFlash(suivant);
    if (mounted) _message('Flash ${_libelleFlash(suivant)}');
  }

  /// « Continuer » refusé : le bouton tremble.
  var _refusContinuer = 0;

  Future<void> _continuer(int total) async {
    if (!peutContinuerCamera(total)) {
      setState(() => _refusContinuer++);
      _message(libelleTropDePhotos(total));
      return;
    }
    final brouillon = await _session.terminer();
    if (brouillon == null || !mounted) return;
    widget.surContinuer(brouillon);
  }

  void _fermer() {
    final garde =
        (_session.actif?.photos.isNotEmpty ?? false) || _enAttente.isNotEmpty;
    if (garde) {
      afficherMessage(context, 'Brouillon gardé · retrouvez-le avec « + »');
    }
    Navigator.of(context).maybePop();
  }

  void _message(String texte, {SnackBarAction? action}) {
    final messager = ScaffoldMessenger.of(context);
    final bas = MediaQuery.paddingOf(context).bottom + 140;
    messager
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texte),
          action: action,
          duration: Duration(milliseconds: action == null ? 1800 : 5000),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bas),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final marges = MediaQuery.paddingOf(context);
    final centreBas = marges.bottom + (marges.bottom > 0 ? 62.0 : 50.0);
    final actif = _session.actif;
    final enregistrees = actif?.photos ?? const <PhotoBrouillon>[];
    final enVol = {
      for (final e in _enAttente)
        if (e.enVol && e.photoId != null) e.photoId,
    };
    final nonEnregistrees = [
      for (final e in _enAttente)
        if (e.photoId == null) e,
    ];
    final photosEventail = [
      for (var i = 0; i < enregistrees.length; i++)
        VignetteEventail(
          id: enregistrees[i].id,
          image: FileImage(
            widget.brouillons.fichierPhoto(actif!.id, enregistrees[i].id),
          ),
          libelle: 'Photo ${i + 1} sur ${enregistrees.length}',
        ),
    ];
    final vignettes = [
      for (final p in enregistrees)
        if (!enVol.contains(p.id))
          VignettePile(
            image: FileImage(widget.brouillons.fichierPhoto(actif!.id, p.id)),
          ),
      for (final e in nonEnregistrees)
        if (!e.enVol)
          VignettePile(image: MemoryImage(e.octets), mouillee: true),
    ];
    final total = enregistrees.length + nonEnregistrees.length;

    return PopScope(
      canPop: !_eventailOuvert && _visionneuse == null,
      onPopInvokedWithResult: (retire, _) {
        if (retire) return;
        if (_visionneuse != null) {
          setState(() => _visionneuse = null);
        } else {
          _fermerEventail();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, contrainte) {
              final taille = contrainte.biggest;
              final arrivee = Rect.fromCenter(
                center: Offset(56, taille.height - centreBas),
                width: 52,
                height: 52,
              );
              final cote = taille.width * 0.82;
              final depart = Rect.fromCenter(
                center: Offset(taille.width / 2, taille.height * 0.46),
                width: cote,
                height: cote,
              );
              return Stack(
                children: [
                  Positioned.fill(child: _viseur()),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                            stops: const [0, 0.18, 0.72, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _eclair,
                        builder: (context, _) => ColoredBox(
                          color: TablCouleurs.sombre.fond.withValues(
                            alpha: 0.15 * (1 - _eclair.value),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    top: marges.top + 4,
                    height: 44,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TablBoutonVerre(
                          icone: Icons.close_rounded,
                          libelle: 'Fermer : le brouillon est gardé',
                          onPresse: _fermer,
                        ),
                        TablBoutonVerre(
                          icone: switch (_flash) {
                            ModeFlash.auto => Icons.flash_auto_rounded,
                            ModeFlash.active => Icons.flash_on_rounded,
                            ModeFlash.desactive => Icons.flash_off_rounded,
                          },
                          libelle: 'Flash : ${_libelleFlash(_flash)}',
                          doree: _flash == ModeFlash.active,
                          onPresse: _changerFlash,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    bottom: centreBas + 52,
                    child: CompteurPhotosCamera(
                      nombre: vignettes.length,
                      libelle: libelleCompteurPhotos(vignettes.length),
                      visible: _compteurVisible && vignettes.isNotEmpty,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: centreBas - 48,
                    height: 96,
                    child: Stack(
                      children: [
                        Positioned(
                          left: total == 0 ? 18 : 20,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: total == 0
                                ? BoutonImporterCamera(
                                    libelle: 'Importer',
                                    onPresse: () =>
                                        _importer(nombreMaxPhotosSouvenir),
                                  )
                                : PilePhotosCamera(
                                    vignettes: vignettes,
                                    nombre: vignettes.length,
                                    libelle:
                                        'Voir les ${vignettes.length} photos de ce moment',
                                    onTap: actif == null
                                        ? null
                                        : _ouvrirEventail,
                                  ),
                          ),
                        ),
                        Center(
                          child: ValueListenableBuilder<EtatCamera>(
                            valueListenable: widget.camera.etat,
                            builder: (context, etat, _) => DeclencheurCamera(
                              nombrePhotos: vignettes.length,
                              actif: etat == EtatCamera.prete,
                              onDeclencher: _declencher,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 16,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: total == 0
                                ? const SizedBox.shrink()
                                : BoutonContinuerCamera(
                                    libelle: libelleContinuer(total),
                                    grise: !peutContinuerCamera(total),
                                    refus: _refusContinuer,
                                    onPresse: () => _continuer(total),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final e in _enAttente)
                    if (e.enVol)
                      PhotoEnVol(
                        key: ObjectKey(e),
                        image: MemoryImage(e.octets),
                        depart: depart,
                        arrivee: arrivee,
                        onTermine: () => _volTermine(e),
                      ),
                  if (_eventailOuvert && photosEventail.isNotEmpty)
                    Positioned.fill(
                      child: EventailPhotosCamera(
                        vignettes: photosEventail.sublist(
                          math.max(
                            0,
                            photosEventail.length - nombreMaxEventail,
                          ),
                        ),
                        ancre: Offset(56, taille.height - centreBas),
                        bas: centreBas,
                        libelleImporter: 'Importer',
                        libelleSupprimer: 'Supprimer cette photo',
                        libelleCorbeille: 'Supprimer',
                        indice: _indiceEventailVu
                            ? null
                            : 'Glissez pour déplacer · × pour supprimer',
                        onOuvrir: (id) => setState(
                          () => _visionneuse = photosEventail.indexWhere(
                            (v) => v.id == id,
                          ),
                        ),
                        onSupprimer: _retirerPhoto,
                        onReordonner: _reordonner,
                        onImporter: _importerDepuisEventail,
                        onFermer: _fermerEventail,
                      ),
                    ),
                  if (_visionneuse != null && photosEventail.isNotEmpty)
                    Positioned.fill(
                      child: VisionneusePhotosCamera(
                        vignettes: photosEventail,
                        indexInitial: _visionneuse!,
                        textes: _textesVisionneuse,
                        onFermer: () => setState(() => _visionneuse = null),
                        onSupprimer: _retirerPhoto,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _viseur() {
    return ColoredBox(
      color: Colors.black,
      child: ValueListenableBuilder<EtatCamera>(
        valueListenable: widget.camera.etat,
        builder: (context, etat, _) => switch (etat) {
          EtatCamera.prete => Center(child: widget.camera.apercu()),
          EtatCamera.refusee => const Center(
            child: MessageViseurCamera(
              titre: "L'accès à la caméra est refusé",
              detail:
                  'Autorisez-la dans les réglages de votre téléphone, '
                  'ou importez vos photos.',
            ),
          ),
          EtatCamera.indisponible => const Center(
            child: MessageViseurCamera(
              titre: "La caméra n'est pas disponible",
              detail: 'Importez plutôt vos photos depuis votre photothèque.',
            ),
          ),
          EtatCamera.eteinte || EtatCamera.demarrage => const SizedBox.expand(),
        },
      ),
    );
  }
}

const _textesVisionneuse = TextesVisionneusePhotos(
  retour: 'Revenir',
  supprimer: 'Supprimer…',
  etat: 'Dans ce brouillon · privée',
  ok: 'OK',
  titreConfirmation: 'Supprimer cette photo ?',
  detailConfirmation:
      'Elle disparaît de ce moment. « Annuler » la remet juste après.',
  confirmer: 'Supprimer la photo',
  annuler: 'Annuler',
);

String _libelleFlash(ModeFlash mode) => switch (mode) {
  ModeFlash.auto => 'automatique',
  ModeFlash.active => 'activé',
  ModeFlash.desactive => 'désactivé',
};
