import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';
import 'feuille_audience.dart';

/// Ce qui ressort — catégories les plus fréquentes, reprises telles
/// quelles du prototype (`instruction/Clément (2)/uploads/Capture
/// d'écran 2026-08-26 à 08.59.14.png` et le bottom sheet "Ce qui
/// ressort"). Une sélection simplifiée en une liste, plutôt que le
/// tunnel catégorie → qualificatif du prototype (`pubSheet: 'impression'`),
/// qui demanderait un composant à part entière.
const List<String> _impressionsDisponibles = [
  'Assiette · Exceptionnelle',
  'Service · Attentionné',
  'Ambiance · Intime',
  'Ambiance · Festive',
  'Cadre · Élégant',
  'Prix · Correct',
];

/// Publier un moment, sur place : la photo au centre — en grand, on
/// glisse après la dernière pour en ajouter une —, le restaurant proposé
/// d'après l'endroit où l'on est (ou celui des photos), puis comment
/// c'était, quelques mots, avec qui, ce qui ressort, la boisson, et qui
/// peut voir. Même écran que « Ajouter un souvenir » ([EditionPhotos],
/// [PropositionLieu]) pour un repas de maintenant, qui part dans le Feed.
///
/// Se ferme sur `true` une fois le moment publié.
///
/// Avec [aModifier], le même écran modifie un moment déjà publié : tout
/// s'y change sauf ses photos et sa date — c'est ce qui a eu lieu. Se
/// ferme sur `true` une fois enregistré.
class EcranPublier extends StatefulWidget {
  const EcranPublier({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.prendrePhoto = photoDeLAppareil,
    this.choisirPhotos = photosDuTelephone,
    this.aModifier,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// `null` par défaut (même principe que `EcranPrincipal.tableService`) :
  /// si absent, la feuille "Qui peut voir ?" ne propose simplement pas
  /// de Tables — un moment reste publiable sans Table.
  final TableService? tableService;

  /// `null` : ni restaurant proposé, ni recherche (saisie à la main).
  final RechercheLieuService? rechercheLieuService;

  /// `null` : pas de restaurant proposé d'après l'endroit où l'on est.
  final PositionService? positionService;
  final PrendrePhoto prendrePhoto;
  final ChoisirPhotos choisirPhotos;

  /// Le moment à modifier (l'un des siens) ; `null` : en publier un.
  final SouvenirFeed? aModifier;

  @override
  State<EcranPublier> createState() => _EcranPublierState();
}

class _EcranPublierState extends State<EcranPublier>
    with EditionPhotos<EcranPublier>, PropositionLieu<EcranPublier> {
  @override
  List<PhotoChoisie> get photosInitiales => const [];

  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  @override
  PositionService? get positionService => widget.positionService;

  /// Là où l'on est, une fois connu.
  Coordonnees? _ici;

  Emotion? _emotion;
  final _legende = TextEditingController();
  final Set<String> _amisTaguesIds = {};
  final Set<String> _impressions = {};
  final _boissonTexte = TextEditingController();
  Uint8List? _boissonPhoto;
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;
  bool _enCours = false;

  /// Publié : la coche s'affiche, puis l'écran se ferme.
  bool _publie = false;

  bool get _modification => widget.aModifier != null;

  /// Le moment à modifier tel qu'il était ; `null` tant qu'il se charge.
  MomentModifiable? _initial;

  // Chargé une fois : sert à la fois aux personnes à taguer, au libellé
  // de l'audience et à la feuille "Qui peut voir ?".
  late final Future<DonneesAudience> _futurAudience = chargerDonneesAudience(
    widget.abonnementService,
    widget.tableService,
  );
  DonneesAudience? _donnees;

  @override
  void initState() {
    super.initState();
    if (_modification) {
      _chargerMoment();
    } else {
      _localiser();
    }
    _futurAudience.then((donnees) {
      if (mounted) setState(() => _donnees = donnees);
    }, onError: (Object e) => debugPrint('EcranPublier: audience : $e'));
  }

  @override
  void dispose() {
    _legende.dispose();
    _boissonTexte.dispose();
    super.dispose();
  }

  /// Le moment à modifier : tout est prérempli, et son restaurant ne
  /// sera pas remplacé par une proposition.
  Future<void> _chargerMoment() async {
    try {
      final m = await widget.souvenirService.momentModifiable(
        widget.aModifier!.id,
      );
      if (!mounted) return;
      setState(() {
        _initial = m;
        lieu = m.lieu;
        lieuChoisi = true;
        _emotion = m.emotion;
        _legende.text = m.legende ?? '';
        _amisTaguesIds.addAll(m.amisTaguesIds);
        _impressions.addAll(m.impressions);
        _boissonTexte.text = m.boissonTexte ?? '';
        _audience = m.audience;
      });
    } catch (e) {
      debugPrint('EcranPublier: moment à modifier : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      Navigator.of(context).pop();
    }
  }

  /// Quelque chose a changé depuis l'ouverture du moment à modifier.
  bool get _aChange {
    final i = _initial;
    if (i == null) return false;
    return lieu?.restaurantId != i.lieu.restaurantId ||
        lieu?.nom != i.lieu.nom ||
        _emotion != i.emotion ||
        _legende.text.trim() != (i.legende ?? '').trim() ||
        !setEquals(_amisTaguesIds, i.amisTaguesIds) ||
        !setEquals(_impressions, i.impressions.toSet()) ||
        _boissonTexte.text.trim() != (i.boissonTexte ?? '').trim() ||
        _audience.mode != i.audience.mode ||
        !setEquals(_audience.tableIds, i.audience.tableIds) ||
        !setEquals(_audience.personneIds, i.audience.personneIds);
  }

  Future<void> _localiser() async {
    try {
      final ici = await widget.positionService?.positionActuelle();
      if (!mounted || ici == null) return;
      _ici = ici;
      _choisirEndroits();
    } catch (e) {
      debugPrint('EcranPublier: position : $e');
    }
  }

  @override
  void photosAjoutees() => _choisirEndroits();

  /// Où chercher le restaurant : là où les photos ont été prises, si
  /// l'une le dit (un repas de tout à l'heure, choisi dans la
  /// photothèque) ; sinon là où l'on est.
  void _choisirEndroits() {
    final suggestion = precompleter([
      for (final p in photos) p.metadonnees,
    ], maintenant: DateTime.now());
    final position = suggestion.position;
    final ici = _ici;
    if (position != null) {
      if (endroits.isEmpty || repere != RepereDistance.photo) {
        chercherAutour([
          position,
          ...suggestion.autresEndroits.take(2),
        ], repere: RepereDistance.photo);
      }
    } else if (ici != null && endroits.isEmpty) {
      chercherAutour([ici], repere: RepereDistance.vous);
    }
  }

  /// Saisi à la main : on y est, il prend la position du téléphone.
  @override
  LieuRestaurant completerLieuManuel(LieuRestaurant lieu) {
    final ici = _ici;
    if (ici == null) return lieu;
    return LieuRestaurant.manuel(
      nom: lieu.nom,
      ville: lieu.ville,
      latitude: ici.latitude,
      longitude: ici.longitude,
    );
  }

  Future<void> _prendrePhoto() async {
    try {
      final photo = await widget.prendrePhoto();
      if (photo != null) await ajouterPhotos([photo]);
    } catch (e) {
      debugPrint('EcranPublier: appareil photo : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _choisirPhotos() async {
    try {
      await ajouterPhotos(await widget.choisirPhotos(placesRestantes));
    } catch (e) {
      debugPrint('EcranPublier: photothèque : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  List<ActionAjoutPhoto> get _actionsPhoto => [
    (
      icone: Icons.photo_camera_outlined,
      libelle: 'Prendre une photo',
      onPresse: _prendrePhoto,
    ),
    (
      icone: Icons.photo_library_outlined,
      libelle: 'Photothèque',
      onPresse: _choisirPhotos,
    ),
  ];

  Map<String, String> get _pseudos => {
    for (final r in _donnees?.relations ?? const <ProfilPublic>[])
      r.id: r.pseudo,
  };

  Future<void> _choisirAudience() async {
    final choisie = await ouvrirFeuilleAudience(
      context,
      audienceInitiale: _audience,
      abonnementService: widget.abonnementService,
      tableService: widget.tableService,
      donnees: _futurAudience,
      amisTaguesIds: _amisTaguesIds,
    );
    if (choisie == null || !mounted) return;
    setState(() => _audience = choisie);
  }

  /// Une feuille d'option : son titre, ce qu'on y règle — chaque
  /// changement se voit aussitôt sur l'écran —, et « Valider ».
  Future<void> _feuille(
    String titre,
    Widget Function(VoidCallback redessiner) contenu,
  ) {
    final c = TablCouleurs.of(context);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      showDragHandle: true,
      builder: (contexteFeuille) => StatefulBuilder(
        builder: (contexteFeuille, redessinerFeuille) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              TablTokens.espaceL - 4,
              0,
              TablTokens.espaceL - 4,
              TablTokens.espaceM +
                  MediaQuery.viewInsetsOf(contexteFeuille).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(titre, style: c.titreAffichage.copyWith(fontSize: 26)),
                const SizedBox(height: TablTokens.espaceM),
                contenu(() {
                  setState(() {});
                  redessinerFeuille(() {});
                }),
                const SizedBox(height: TablTokens.espaceL),
                TablBouton(
                  libelle: 'Valider',
                  onPresse: () => Navigator.of(contexteFeuille).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _choisirAvecQui() {
    final c = TablCouleurs.of(context);
    _feuille('Avec qui ?', (redessiner) {
      final relations = _donnees?.relations ?? const <ProfilPublic>[];
      if (relations.isEmpty) {
        return Text(
          'Personne à taguer pour l\'instant : suivez des gens pour les '
          'retrouver ici.',
          style: c.legende,
        );
      }
      return TablSelecteurPersonnes(
        personnes: [
          for (final r in relations)
            PersonneSelectionnable(
              id: r.id,
              pseudo: r.pseudo,
              photoUrl: r.photoUrl,
            ),
        ],
        selection: _amisTaguesIds,
        onBascule: (id) {
          if (!_amisTaguesIds.remove(id)) _amisTaguesIds.add(id);
          redessiner();
        },
      );
    });
  }

  void _choisirCeQuiRessort() {
    _feuille(
      'Ce qui ressort',
      (redessiner) => Wrap(
        spacing: TablTokens.espaceS,
        runSpacing: TablTokens.espaceS,
        children: [
          for (final impression in _impressionsDisponibles)
            TablPuceSelection(
              libelle: impression,
              selectionnee: _impressions.contains(impression),
              onBascule: () {
                if (!_impressions.remove(impression)) {
                  _impressions.add(impression);
                }
                redessiner();
              },
            ),
        ],
      ),
    );
  }

  void _choisirBoisson() {
    _feuille(
      'Une boisson ?',
      (redessiner) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TablChampTexte(
              libelle: '',
              controleur: _boissonTexte,
              indication: 'Un Margaux 2018',
              onChanged: (_) => redessiner(),
            ),
          ),
          // Une fois publié, la photo de la boisson reste ce qu'elle
          // était, comme les autres photos.
          if (!_modification) ...[
            const SizedBox(width: TablTokens.espaceS),
            _VignetteBoisson(
              photo: _boissonPhoto,
              onPresse: () async {
                await _photographierBoisson();
                redessiner();
              },
            ),
          ],
        ],
      ),
    );
  }

  /// L'étiquette, la bouteille : l'appareil photo, ou une photo déjà
  /// prise.
  Future<void> _photographierBoisson() async {
    final c = TablCouleurs.of(context);
    final appareil = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: c.surface,
      builder: (contexteFeuille) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera_outlined, color: c.texte),
              title: Text('Prendre une photo', style: c.corps),
              onTap: () => Navigator.of(contexteFeuille).pop(true),
            ),
            ListTile(
              leading: Icon(Icons.photo_library_outlined, color: c.texte),
              title: Text('Photothèque', style: c.corps),
              onTap: () => Navigator.of(contexteFeuille).pop(false),
            ),
          ],
        ),
      ),
    );
    if (appareil == null) return;
    try {
      final photo = appareil
          ? await widget.prendrePhoto()
          : (await widget.choisirPhotos(1)).firstOrNull;
      if (photo != null && mounted) setState(() => _boissonPhoto = photo);
    } catch (e) {
      debugPrint('EcranPublier: photo de la boisson : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  /// Ce qui manque encore pour publier ; `null` : rien.
  String? get _manque {
    if (_modification && _initial == null) return null;
    if (!_modification && photos.isEmpty) return 'Une photo d\'abord.';
    if (lieu == null) return 'Où êtes-vous ?';
    if (_emotion == null) return 'Comment c\'était ?';
    return null;
  }

  Future<void> _garderCeMoment() async {
    final lieu = this.lieu;
    final emotion = _emotion;
    if (lieu == null || emotion == null || photos.isEmpty) return;
    final legende = _legende.text.trim();
    final erreurLegende = ValidationSouvenir.legende(legende);
    if (erreurLegende != null) {
      afficherMessage(context, erreurLegende);
      return;
    }
    final boisson = _boissonTexte.text.trim();

    setState(() => _enCours = true);
    try {
      final tablesEnEchec = await widget.souvenirService.publier(
        lieu: lieu,
        photos: [for (final p in photos) p.octets],
        emotion: emotion,
        legende: legende.isEmpty ? null : legende,
        amisTaguesIds: _amisTaguesIds.toList(),
        impressions: _impressions.toList(),
        boissonTexte: boisson.isEmpty ? null : boisson,
        boissonPhoto: _boissonPhoto,
        audience: _audience,
        empreintes: [for (final p in photos) ?p.metadonnees.empreinte],
      );
      if (!mounted) return;
      // Le moment est publié malgré tout (règle 51) : un message discret
      // plutôt qu'une erreur bloquante, la publication elle-même a
      // réussi.
      if (tablesEnEchec.isNotEmpty) {
        afficherMessage(
          context,
          'Publié, mais impossible de le partager avec '
          '${pluriel(tablesEnEchec.length, 'Table')}.',
        );
      }
      HapticFeedback.lightImpact();
      setState(() => _publie = true);
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EcranPublier: $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  /// Enregistre les changements du moment à modifier.
  Future<void> _enregistrer() async {
    final lieu = this.lieu;
    final emotion = _emotion;
    if (lieu == null || emotion == null) return;
    final legende = _legende.text.trim();
    final erreurLegende = ValidationSouvenir.legende(legende);
    if (erreurLegende != null) {
      afficherMessage(context, erreurLegende);
      return;
    }
    final boisson = _boissonTexte.text.trim();

    setState(() => _enCours = true);
    try {
      final tablesEnEchec = await widget.souvenirService.modifier(
        widget.aModifier!.id,
        MomentModifiable(
          lieu: lieu,
          emotion: emotion,
          legende: legende.isEmpty ? null : legende,
          amisTaguesIds: Set.of(_amisTaguesIds),
          impressions: _impressions.toList(),
          boissonTexte: boisson.isEmpty ? null : boisson,
          audience: _audience,
        ),
      );
      if (!mounted) return;
      if (tablesEnEchec.isNotEmpty) {
        afficherMessage(
          context,
          'Modifié, mais impossible de le partager avec '
          '${pluriel(tablesEnEchec.length, 'Table')}.',
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EcranPublier: modification : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  /// Fermer un moment modifié : les changements ne se perdent pas sans
  /// le vouloir.
  Future<void> _fermerModification() async {
    if (!_aChange) {
      Navigator.of(context).pop();
      return;
    }
    final c = TablCouleurs.of(context);
    final abandonner = await showDialog<bool>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Abandonner les modifications ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(false),
            child: const Text('Continuer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(true),
            child: Text('Abandonner', style: TextStyle(color: c.erreur)),
          ),
        ],
      ),
    );
    if (abandonner == true && mounted) Navigator.of(context).pop();
  }

  /// Fermer avec des photos : rien ne se perd sans le vouloir. Avec un
  /// restaurant, on peut aussi le garder pour plus tard (brouillon).
  Future<void> _fermer() async {
    if (_modification) return _fermerModification();
    if (photos.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    final lieu = this.lieu;
    final c = TablCouleurs.of(context);
    final choix = await showDialog<_Fermeture>(
      context: context,
      builder: (contexteDialogue) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Abandonner ce moment ?'),
        content: const Text('Vos photos ne seront pas gardées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexteDialogue).pop(),
            child: const Text('Continuer'),
          ),
          if (lieu != null)
            TextButton(
              onPressed: () =>
                  Navigator.of(contexteDialogue).pop(_Fermeture.plusTard),
              child: const Text('Plus tard'),
            ),
          TextButton(
            onPressed: () =>
                Navigator.of(contexteDialogue).pop(_Fermeture.abandonner),
            child: Text('Abandonner', style: TextStyle(color: c.erreur)),
          ),
        ],
      ),
    );
    if (!mounted || choix == null) return;
    if (choix == _Fermeture.abandonner || lieu == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _enCours = true);
    try {
      await widget.souvenirService.enregistrerBrouillon(
        lieu: lieu,
        photo: photos.first.octets,
      );
      if (!mounted) return;
      afficherMessage(context, 'Gardé en brouillon.');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('EcranPublier: brouillon : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    final lieu = this.lieu;
    final pseudos = _pseudos;
    final tagues = [for (final id in _amisTaguesIds) ?pseudos[id]];
    final relations = {
      for (final r in _donnees?.relations ?? const <ProfilPublic>[]) r.id: r,
    };
    final boisson = _boissonTexte.text.trim();
    final horsAudience =
        _donnees?.contexte.taguesHorsAudience(_audience, _amisTaguesIds) ??
        const <String>{};
    final manque = _manque;

    final aModifier = widget.aModifier;
    return PopScope(
      // Un moment modifié passe toujours par [_fermer] : taper du texte
      // ne redessine pas l'écran, [_aChange] ne se lit qu'au moment de
      // partir.
      canPop: !_enCours && !_modification && photos.isEmpty,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && !_enCours && !_publie) _fermer();
      },
      child: Scaffold(
        backgroundColor: c.fond,
        body: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (aModifier != null)
                    TablZonePhotos(
                      photos: [
                        for (final url in [
                          ?aModifier.photoUrl,
                          ...aModifier.autresPhotosUrls,
                        ])
                          NetworkImage(url),
                      ],
                      page: page,
                      hauteur: hauteurPhotosCreation(
                        MediaQuery.sizeOf(context),
                      ),
                      onPage: (p) => setState(() => page = p),
                      actionsAjout: const [],
                    )
                  else
                    zonePhotos(
                      context,
                      actions: _actionsPhoto,
                      titreAjout: 'Le plat, la table, la tablée',
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TablTokens.espaceL - 4,
                      TablTokens.espaceL,
                      TablTokens.espaceL - 4,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TablSurtitreSouvenir(
                          icone: Icons.restaurant_rounded,
                          texte: aModifier != null
                              ? 'Moment · ${dateLisibleSouvenir(aModifier.dateVisite)}'
                              : momentDuJour(DateTime.now()) == 'midi'
                              ? 'Moment · ce midi'
                              : 'Moment · ce soir',
                        ),
                        const SizedBox(height: 10),
                        TablTitreLieuSouvenir(
                          nom: lieu?.nom,
                          detail: detailLieu,
                          indication: 'Où êtes-vous ?',
                          action: lieu == null ? 'Choisir' : 'Changer',
                          onPresse: changerLieu,
                        ),
                        const SizedBox(height: TablTokens.espaceM),
                        Divider(height: 1, color: c.surface),
                        const SizedBox(height: TablTokens.espaceL - 4),
                        Text('Comment c\'était ?', style: c.legende),
                        const SizedBox(height: TablTokens.espaceS),
                        TablSelecteurEmotion(
                          emojis: [for (final e in Emotion.values) e.emoji],
                          selection: _emotion?.emoji,
                          onSelection: (emoji) => setState(() {
                            final choisie = Emotion.depuisEmoji(emoji);
                            _emotion = choisie == _emotion ? null : choisie;
                          }),
                        ),
                        const SizedBox(height: TablTokens.espaceL - 4),
                        TablChampLegende(
                          controleur: _legende,
                          indication: 'Ce que vous voudrez vous rappeler',
                        ),
                        const SizedBox(height: TablTokens.espaceM),
                        Divider(height: 1, color: c.surface),
                        const SizedBox(height: TablTokens.espaceXs),
                        TablLigneOption(
                          icone: Icons.people_outline_rounded,
                          texte: tagues.isEmpty
                              ? 'Avec qui ?'
                              : 'Avec ${listeDeNoms(tagues)}',
                          vide: tagues.isEmpty,
                          fin: tagues.isEmpty
                              ? null
                              : TablBullesPersonnes(
                                  taille: 26,
                                  bulles: [
                                    for (final id in _amisTaguesIds.take(3))
                                      if (relations[id] case final r?)
                                        BullePersonne(
                                          pseudo: r.pseudo,
                                          photoUrl: r.photoUrl,
                                        ),
                                  ],
                                ),
                          onPresse: _choisirAvecQui,
                        ),
                        TablLigneOption(
                          icone: Icons.auto_awesome_outlined,
                          texte: _impressions.isEmpty
                              ? 'Ce qui ressort'
                              : _impressions.join(', '),
                          vide: _impressions.isEmpty,
                          onPresse: _choisirCeQuiRessort,
                        ),
                        TablLigneOption(
                          icone: Icons.wine_bar_outlined,
                          texte: boisson.isNotEmpty
                              ? boisson
                              : _boissonPhoto != null
                              ? 'La boisson, en photo'
                              : 'Une boisson ?',
                          vide: boisson.isEmpty && _boissonPhoto == null,
                          fin: _boissonPhoto == null
                              ? null
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    TablTokens.arrondiS,
                                  ),
                                  child: Image.memory(
                                    _boissonPhoto!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                          onPresse: _choisirBoisson,
                        ),
                        const SizedBox(height: TablTokens.espaceXs),
                        Divider(height: 1, color: c.surface),
                        const SizedBox(height: TablTokens.espaceM),
                        TablLigneAudience(
                          libelle: libelleAudience(
                            _audience,
                            nomsTables: {
                              for (final t
                                  in _donnees?.tables ?? const <ResumeTable>[])
                                t.id: t.nom,
                            },
                            pseudos: pseudos,
                          ),
                          restreinte:
                              _audience.mode != ModeAudience.toutLeMonde,
                          onPresse: _choisirAudience,
                        ),
                        for (final id in horsAudience)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: TablTokens.espaceXs,
                            ),
                            child: Text(
                              '${pseudos[id] ?? 'Une personne taguée'} '
                              'ne verra pas ce moment.',
                              style: c.legende.copyWith(color: c.primaire),
                            ),
                          ),
                        // La place du bouton, qui flotte par-dessus.
                        SizedBox(
                          height: 130 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TablTokens.espaceM,
                    vertical: TablTokens.espaceS,
                  ),
                  child: Row(
                    children: [
                      TablBoutonVerre(
                        icone: Icons.close_rounded,
                        libelle: 'Fermer',
                        onPresse: _enCours ? () {} : _fermer,
                      ),
                      const Spacer(),
                      if (photos.isNotEmpty &&
                          placesRestantes > 0 &&
                          page < photos.length)
                        TablBoutonVerre(
                          icone: Icons.add_photo_alternate_outlined,
                          libelle: 'Ajouter une photo',
                          onPresse: () => setState(() => page = photos.length),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.fond.withValues(alpha: 0), c.fond],
                    stops: const [0, 0.22],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TablTokens.espaceL - 4,
                      TablTokens.espaceL,
                      TablTokens.espaceL - 4,
                      TablTokens.espaceS,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (manque != null && !_enCours) ...[
                          Text(
                            manque,
                            textAlign: TextAlign.center,
                            style: c.legende.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: TablTokens.espaceS),
                        ],
                        if (_modification)
                          TablBouton(
                            libelle: 'Enregistrer',
                            enCours: _enCours || _initial == null,
                            onPresse: manque == null ? _enregistrer : null,
                          )
                        else
                          TablBouton(
                            libelle: 'Garder ce moment.',
                            enCours: _enCours,
                            onPresse: manque == null ? _garderCeMoment : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_publie) const Positioned.fill(child: _MomentGarde()),
          ],
        ),
      ),
    );
  }
}

enum _Fermeture { plusTard, abandonner }

/// La photo de la boisson dans sa feuille : la voir, ou en prendre une.
class _VignetteBoisson extends StatelessWidget {
  const _VignetteBoisson({required this.photo, required this.onPresse});

  final Uint8List? photo;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return Semantics(
      button: true,
      label: 'Photo de la boisson',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onPresse,
        child: Container(
          width: TablTokens.hauteurControle,
          height: TablTokens.hauteurControle,
          decoration: BoxDecoration(
            color: c.surfaceBasse,
            borderRadius: BorderRadius.circular(TablTokens.arrondiS),
            border: Border.all(color: c.bordure),
          ),
          clipBehavior: Clip.antiAlias,
          child: photo != null
              ? Image.memory(photo!, fit: BoxFit.cover)
              : Icon(Icons.add_a_photo_outlined, color: c.texteDoux, size: 20),
        ),
      ),
    );
  }
}

/// Le moment est gardé : une coche dorée qui apparaît, un instant, avant
/// de revenir au Feed.
class _MomentGarde extends StatelessWidget {
  const _MomentGarde();

  @override
  Widget build(BuildContext context) {
    final c = TablCouleurs.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, t, enfant) => Opacity(
        opacity: t,
        child: ColoredBox(
          color: c.fond.withValues(alpha: 0.86),
          child: Center(
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: enfant),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: c.primaire, size: 64),
          const SizedBox(height: TablTokens.espaceM),
          Text('Moment gardé.', style: c.titreAffichage.copyWith(fontSize: 26)),
        ],
      ),
    );
  }
}
