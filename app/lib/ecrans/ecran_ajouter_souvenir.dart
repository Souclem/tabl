import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_audience.dart';
import 'recherche_lieu_en_direct.dart';

/// Choisit au plus `restant` photos dans la photothèque.
typedef ChoisirPhotos = Future<List<Uint8List>> Function(int restant);

/// Le sélecteur de photos du téléphone. Les photos sont réduites, mais
/// gardent leur date et leur position (c'est d'elles que part le
/// souvenir).
Future<List<Uint8List>> photosDuTelephone(int restant) async {
  if (restant <= 0) return const [];
  final selecteur = ImagePicker();
  // Le sélecteur multiple refuse une limite de 1.
  final fichiers = restant == 1
      ? [
          ?await selecteur.pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
            maxWidth: 1600,
          ),
        ]
      : await selecteur.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1600,
          limit: restant,
        );
  return [for (final f in fichiers.take(restant)) await f.readAsBytes()];
}

/// Ajouter un souvenir : un repas passé, tel qu'il apparaîtra sur le
/// profil. Les photos en grand d'abord — il en faut au moins une ;
/// d'elles, Tabl déduit le restaurant le plus proche, le jour et le
/// moment, des propositions toutes modifiables. Se ferme sur `true` une
/// fois le souvenir ajouté.
class EcranAjouterSouvenir extends StatefulWidget {
  const EcranAjouterSouvenir({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.photos = const [],
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.choisirPhotos = photosDuTelephone,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// Celles déjà choisies (la première est la principale). Toutes
  /// retirées, il faut en rajouter une pour pouvoir ajouter le souvenir.
  final List<PhotoChoisie> photos;
  final TableService? tableService;

  /// `null` : ni lieu proposé, ni recherche (saisie à la main).
  final RechercheLieuService? rechercheLieuService;

  /// Sans photo localisée : la recherche est triée autour du téléphone.
  final PositionService? positionService;
  final ChoisirPhotos choisirPhotos;

  @override
  State<EcranAjouterSouvenir> createState() => _EcranAjouterSouvenirState();
}

class _EcranAjouterSouvenirState extends State<EcranAjouterSouvenir> {
  late final List<PhotoChoisie> _photos = List.of(widget.photos);
  int _page = 0;

  /// Les endroits où les photos ont été prises, le principal d'abord :
  /// c'est autour d'eux qu'on cherche le restaurant.
  List<Coordonnees> _endroitsPhotos = const [];

  /// Les restaurants autour de chacun des [_endroitsPhotos], du plus
  /// proche au plus loin.
  List<List<LieuRestaurant>> _prochesParEndroit = const [];
  bool _rechercheProches = false;

  LieuRestaurant? _lieu;

  /// La distance de [_lieu] est celle qui le sépare des photos.
  bool _lieuDepuisPhotos = false;

  DateSouvenir? _date;
  String? _moment;

  /// L'heure de la première photo, quand le jour vient d'elles.
  DateTime? _heurePhotos;

  Emotion? _emotion;
  final _legende = TextEditingController();
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;
  bool _enCours = false;

  late final Future<DonneesAudience> _futurAudience = chargerDonneesAudience(
    widget.abonnementService,
    widget.tableService,
  );

  @override
  void initState() {
    super.initState();
    _completerDepuisPhotos();
  }

  @override
  void dispose() {
    _legende.dispose();
    super.dispose();
  }

  /// Ce que les photos disent, pour ce qui n'est pas encore choisi :
  /// jamais par-dessus un choix de l'utilisateur.
  void _completerDepuisPhotos() {
    final suggestion = precompleter([
      for (final p in _photos) p.metadonnees,
    ], maintenant: DateTime.now());
    if (_date == null && suggestion.date != null) {
      _date = suggestion.date;
      _moment = suggestion.moment;
      _heurePhotos = suggestion.premierePhoto;
    }
    final position = suggestion.position;
    if (position != null && _endroitsPhotos.isEmpty) {
      // Au plus deux autres endroits : au-delà, ce sont sans doute
      // d'autres repas (l'import de plusieurs souvenirs s'en chargera).
      _endroitsPhotos = [position, ...suggestion.autresEndroits.take(2)];
      _chercherLieuxProches(_endroitsPhotos);
    }
  }

  Future<void> _chercherLieuxProches(List<Coordonnees> endroits) async {
    final service = widget.rechercheLieuService;
    if (service == null) return;
    // Appelé depuis initState : l'état ne change qu'après la première
    // image.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    setState(() => _rechercheProches = true);
    try {
      final proches = await Future.wait([
        for (var i = 0; i < endroits.length; i++)
          service.lieuxProches(
            latitude: endroits[i].latitude,
            longitude: endroits[i].longitude,
            limite: i == 0 ? 8 : 4,
          ),
      ]);
      if (!mounted) return;
      setState(() {
        _prochesParEndroit = proches;
        // Le plus proche de l'endroit principal, proposé : on peut en
        // changer d'un tap.
        final propose = proches.first.firstOrNull;
        if (_lieu == null && propose != null) {
          _lieu = propose;
          _lieuDepuisPhotos = true;
        }
      });
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: lieux proches : $e');
    } finally {
      if (mounted) setState(() => _rechercheProches = false);
    }
  }

  Future<void> _ajouterPhotos() async {
    final restant = nombreMaxPhotosSouvenir - _photos.length;
    if (restant <= 0) return;
    try {
      final nouvelles = await lirePhotos(await widget.choisirPhotos(restant));
      if (!mounted || nouvelles.isEmpty) return;
      setState(() {
        _photos.addAll(nouvelles.take(restant));
        _completerDepuisPhotos();
      });
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: photos : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  void _rendrePrincipale() {
    if (_page == 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _photos.insert(0, _photos.removeAt(_page));
      _page = 0;
    });
  }

  void _retirerPhoto() {
    setState(() {
      _photos.removeAt(_page);
      _page = math.min(_page, math.max(_photos.length - 1, 0));
    });
  }

  Future<void> _choisirLieu() async {
    final endroits = _endroitsPhotos;
    final choisi = await showModalBottomSheet<LieuRestaurant>(
      context: context,
      isScrollControlled: true,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (_) => _FeuilleRestaurant(
        rechercheLieuService: widget.rechercheLieuService,
        positionService: endroits.isNotEmpty
            ? _PositionFixe(endroits.first)
            : widget.positionService,
        endroits: endroits,
        prochesParEndroit: _prochesParEndroit,
        choisi: _lieu,
      ),
    );
    if (choisi == null || !mounted) return;
    setState(() {
      _lieu = choisi;
      _lieuDepuisPhotos = endroits.isNotEmpty && !choisi.estManuel;
    });
  }

  Future<void> _choisirQuand() async {
    final maintenant = DateTime.now();
    final choisi =
        await showModalBottomSheet<({DateSouvenir date, String? moment})>(
          context: context,
          backgroundColor: TablTokens.surface,
          showDragHandle: true,
          builder: (_) => _FeuilleQuand(
            date:
                _date ??
                DateSouvenir(annee: maintenant.year, mois: maintenant.month),
            moment: _moment,
            maintenant: maintenant,
          ),
        );
    if (choisi == null || !mounted) return;
    setState(() {
      _date = choisi.date;
      _moment = choisi.moment;
      _heurePhotos = null;
    });
  }

  Future<void> _choisirAudience() async {
    final choisie = await ouvrirFeuilleAudience(
      context,
      audienceInitiale: _audience,
      abonnementService: widget.abonnementService,
      tableService: widget.tableService,
      donnees: _futurAudience,
    );
    if (choisie == null || !mounted) return;
    setState(() => _audience = choisie);
  }

  Future<void> _ajouter() async {
    final lieu = _lieu;
    final date = _date;
    if (lieu == null || date == null) return;
    final legende = _legende.text.trim();
    final erreurLegende = ValidationSouvenir.legende(legende);
    if (erreurLegende != null) {
      afficherMessage(context, erreurLegende);
      return;
    }

    setState(() => _enCours = true);
    try {
      final tablesEnEchec = await widget.souvenirService.ajouterSouvenir(
        NouveauSouvenir(
          lieu: lieu,
          date: date,
          photos: [for (final p in _photos) p.octets],
          emotion: _emotion,
          legende: legende.isEmpty ? null : legende,
          moment: _moment,
          audience: _audience,
        ),
      );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (tablesEnEchec.isNotEmpty) {
        afficherMessage(
          context,
          'Ajouté, mais impossible de le partager avec '
          '${pluriel(tablesEnEchec.length, 'Table')}.',
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taille = MediaQuery.sizeOf(context);
    final hauteurPhoto = math.min(taille.width * 1.12, taille.height * 0.56);
    final lieu = _lieu;
    final date = _date;
    final heurePhotos = _heurePhotos;
    final peutAjouterPhotos = _photos.length < nombreMaxPhotosSouvenir;
    final octets = [for (final p in _photos) p.octets];

    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: Stack(
        children: [
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: hauteurPhoto,
                  child: _photos.isEmpty
                      ? TablApercuSansPhoto(
                          libelle: 'Ajouter des photos',
                          onAjouter: _ajouterPhotos,
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            TablApercuPhotos(
                              photos: octets,
                              page: _page,
                              onPage: (page) => setState(() => _page = page),
                            ),
                            Positioned(
                              right: TablTokens.espaceM,
                              bottom: TablTokens.espaceL + 22,
                              child: Row(
                                children: [
                                  if (_page > 0) ...[
                                    TablPiluleVerre(
                                      icone: Icons.star_rounded,
                                      libelle: 'Principale',
                                      onPresse: _rendrePrincipale,
                                    ),
                                    const SizedBox(width: TablTokens.espaceS),
                                  ],
                                  TablPiluleVerre(
                                    icone: Icons.delete_outline_rounded,
                                    libelle: 'Retirer',
                                    onPresse: _retirerPhoto,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                if (_photos.length > 1 ||
                    (_photos.isNotEmpty && peutAjouterPhotos)) ...[
                  const SizedBox(height: TablTokens.espaceXs),
                  TablBandeVignettes(
                    photos: octets,
                    page: _page,
                    onChoisir: (i) => setState(() => _page = i),
                    onAjouter: peutAjouterPhotos ? _ajouterPhotos : null,
                  ),
                ],
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
                        texte: _lieuDepuisPhotos || heurePhotos != null
                            ? 'Souvenir · d\'après vos photos'
                            : 'Souvenir',
                      ),
                      const SizedBox(height: 10),
                      TablTitreLieuSouvenir(
                        nom: lieu?.nom,
                        detail: lieu != null
                            ? detailLieuSouvenir(
                                lieu,
                                depuisLaPhoto: _lieuDepuisPhotos,
                              )
                            : _rechercheProches
                            ? 'Recherche du restaurant…'
                            : null,
                        indication: 'Quel restaurant ?',
                        action: lieu == null ? 'Choisir' : 'Changer',
                        onPresse: _choisirLieu,
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      TablLigneQuandSouvenir(
                        texte: date == null
                            ? 'Quand était-ce ?'
                            : [
                                date.libelle,
                                ?libelleMomentRepas(_moment ?? ''),
                              ].join(' · '),
                        detail: heurePhotos == null
                            ? null
                            : 'D\'après vos photos · '
                                  '${heureLisible(heurePhotos)}',
                        vide: date == null,
                        onPresse: _choisirQuand,
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      const Divider(height: 1, color: TablTokens.surface),
                      const SizedBox(height: TablTokens.espaceL - 4),
                      Text('Comment c\'était ?', style: TablTokens.legende),
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
                        indication: 'Quelques mots, si vous le souhaitez',
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      const Divider(height: 1, color: TablTokens.surface),
                      const SizedBox(height: TablTokens.espaceM),
                      FutureBuilder<DonneesAudience>(
                        future: _futurAudience,
                        builder: (context, snapshot) {
                          final donnees = snapshot.data;
                          return TablLigneAudience(
                            libelle: libelleAudience(
                              _audience,
                              nomsTables: {
                                for (final t
                                    in donnees?.tables ?? const <ResumeTable>[])
                                  t.id: t.nom,
                              },
                              pseudos: {
                                for (final r
                                    in donnees?.relations ??
                                        const <ProfilPublic>[])
                                  r.id: r.pseudo,
                              },
                            ),
                            restreinte:
                                _audience.mode != ModeAudience.toutLeMonde,
                            onPresse: _choisirAudience,
                          );
                        },
                      ),
                      const SizedBox(height: TablTokens.espaceS),
                      Row(
                        children: [
                          const Icon(
                            Icons.nightlight_round,
                            size: 13,
                            color: TablTokens.texteDoux,
                          ),
                          const SizedBox(width: TablTokens.espaceS),
                          Expanded(
                            child: Text(
                              'Visible sur votre profil, jamais dans le Feed.',
                              style: TablTokens.legende.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      // La place du bouton, qui flotte par-dessus.
                      SizedBox(
                        height: 110 + MediaQuery.paddingOf(context).bottom,
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
                      onPresse: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    if (_photos.isNotEmpty && peutAjouterPhotos)
                      TablBoutonVerre(
                        icone: Icons.add_photo_alternate_outlined,
                        libelle: 'Ajouter des photos',
                        onPresse: _ajouterPhotos,
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
                  colors: [
                    TablTokens.fond.withValues(alpha: 0),
                    TablTokens.fond,
                  ],
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
                  child: TablBouton(
                    libelle: 'Ajouter à mon profil',
                    enCours: _enCours,
                    onPresse: _photos.isNotEmpty && lieu != null && date != null
                        ? _ajouter
                        : null,
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

/// Une position qui ne bouge pas : celle des photos, pour trier la
/// recherche autour d'elles plutôt qu'autour du téléphone.
class _PositionFixe implements PositionService {
  const _PositionFixe(this.position);

  final Coordonnees position;

  @override
  Future<Coordonnees?> positionActuelle() async => position;
}

/// « Quel restaurant ? » : ceux près des photos d'abord, en liste ou
/// sur la carte (avec l'endroit de chaque photo), la recherche au fil
/// de la frappe, et la saisie à la main en dernier recours.
class _FeuilleRestaurant extends StatefulWidget {
  const _FeuilleRestaurant({
    required this.rechercheLieuService,
    required this.positionService,
    required this.endroits,
    required this.prochesParEndroit,
    required this.choisi,
  });

  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;

  /// Les endroits des photos, le principal d'abord ; vide sans photo
  /// localisée.
  final List<Coordonnees> endroits;
  final List<List<LieuRestaurant>> prochesParEndroit;

  /// Celui déjà choisi, qui ressort sur la carte.
  final LieuRestaurant? choisi;

  @override
  State<_FeuilleRestaurant> createState() => _FeuilleRestaurantState();
}

class _FeuilleRestaurantState extends State<_FeuilleRestaurant>
    with RechercheLieuEnDirect<_FeuilleRestaurant> {
  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  @override
  PositionService? get positionService => widget.positionService;

  late bool _aLaMain = widget.rechercheLieuService == null;
  final _nom = TextEditingController();
  final _ville = TextEditingController();
  String? _erreurNom;
  String? _erreurVille;

  bool _surLaCarte = false;

  /// Les restaurants de la carte : ceux près des photos, puis ceux de la
  /// zone regardée.
  late List<LieuRestaurant> _lieuxCarte = _sansDoublon([
    for (final proches in widget.prochesParEndroit) ...proches,
    ?widget.choisi,
  ]);
  late LieuRestaurant? _toucheSurCarte = widget.choisi;
  int _derniereZone = 0;

  @override
  void dispose() {
    _nom.dispose();
    _ville.dispose();
    super.dispose();
  }

  static List<LieuRestaurant> _sansDoublon(Iterable<LieuRestaurant> lieux) =>
      {for (final l in lieux) l.cle: l}.values.toList();

  /// Sa distance à la photo la plus proche, quand il y a des photos.
  LieuRestaurant _depuisPhotos(LieuRestaurant lieu) => widget.endroits.isEmpty
      ? lieu
      : aDistanceDesPhotos(lieu, widget.endroits);

  String _detail(LieuRestaurant lieu) =>
      detailLieuSouvenir(lieu, depuisLaPhoto: widget.endroits.isNotEmpty);

  void _passerALaMain() => setState(() {
    _aLaMain = true;
    if (_nom.text.isEmpty) _nom.text = recherche.text;
  });

  void _validerALaMain() {
    final erreurNom = ValidationSouvenir.nomRestaurant(_nom.text);
    final erreurVille = ValidationSouvenir.ville(_ville.text);
    setState(() {
      _erreurNom = erreurNom;
      _erreurVille = erreurVille;
    });
    if (erreurNom != null || erreurVille != null) return;
    // Sans position : celle du téléphone placerait le restaurant au
    // mauvais endroit sur la carte, on n'y est plus.
    Navigator.of(context).pop(
      LieuRestaurant.manuel(nom: _nom.text.trim(), ville: _ville.text.trim()),
    );
  }

  /// La carte a bougé : les restaurants de la zone regardée s'ajoutent.
  Future<void> _zoneVisible(
    double sud,
    double ouest,
    double nord,
    double est,
    double zoom,
  ) async {
    final service = widget.rechercheLieuService;
    // De trop loin, les plus proches du centre ne disent rien.
    if (service == null || zoom < 13) return;
    final latitude = (sud + nord) / 2;
    final longitude = (ouest + est) / 2;
    final rayon = math.min(
      distanceEnMetres(latitude, longitude, nord, est),
      1500.0,
    );
    final demande = ++_derniereZone;
    try {
      final autour = await service.lieuxProches(
        latitude: latitude,
        longitude: longitude,
        rayonM: rayon,
        limite: 20,
      );
      if (!mounted || demande != _derniereZone) return;
      setState(() {
        _lieuxCarte = _sansDoublon([
          ..._lieuxCarte,
          for (final l in autour) _depuisPhotos(l),
        ]);
      });
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: carte : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hauteur = MediaQuery.sizeOf(context).height * 0.85;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: hauteur,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL - 4,
                0,
                TablTokens.espaceL - 4,
                TablTokens.espaceM,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quel restaurant ?',
                      style: TablTokens.titreAffichage.copyWith(fontSize: 26),
                    ),
                  ),
                  if (!_aLaMain)
                    TablSegmentModeCarte(
                      options: const ['Liste', 'Carte'],
                      selectionne: _surLaCarte ? 1 : 0,
                      onSelection: (i) {
                        FocusScope.of(context).unfocus();
                        setState(() => _surLaCarte = i == 1);
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: _aLaMain
                  ? _vueALaMain()
                  : _surLaCarte
                  ? _vueCarte()
                  : _vueListe(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueALaMain() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        0,
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
      ),
      children: [
        TablChampTexte(
          libelle: 'Restaurant',
          controleur: _nom,
          indication: 'Le Comptoir',
          erreur: _erreurNom,
        ),
        const SizedBox(height: TablTokens.espaceM),
        TablChampTexte(
          libelle: 'Ville',
          controleur: _ville,
          indication: 'Paris',
          erreur: _erreurVille,
          actionClavier: TextInputAction.done,
          onSoumis: (_) => _validerALaMain(),
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablBouton(libelle: 'Valider', onPresse: _validerALaMain),
      ],
    );
  }

  Widget _vueListe() {
    final aCherche = recherche.text.trim().length >= 2;
    Widget section(String titre) => Padding(
      padding: const EdgeInsets.only(top: TablTokens.espaceM),
      child: Text(
        titre,
        style: TablTokens.legende.copyWith(
          fontSize: 11,
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    Widget ligne(LieuRestaurant lieu) => TablLigneSuggestionLieu(
      nom: lieu.nom,
      description: _detail(lieu),
      onSelection: () => Navigator.of(context).pop(lieu),
    );
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        0,
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
      ),
      children: [
        TablChampTexte(
          libelle: '',
          controleur: recherche,
          indication: 'Chercher un restaurant',
          iconePrefixe: Icons.search_rounded,
          onChanged: (texte) {
            setState(() {});
            rechercherAvecAttente(texte);
          },
        ),
        if (rechercheEnCours)
          const LinearProgressIndicator(
            minHeight: 2,
            color: TablTokens.primaire,
            backgroundColor: Colors.transparent,
          ),
        if (aCherche) ...[
          for (final lieu in suggestions) ligne(_depuisPhotos(lieu)),
          if (!rechercheEnCours && suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
              child: Text(
                'Aucun restaurant trouvé.',
                style: TablTokens.legende,
              ),
            ),
        ] else
          for (var i = 0; i < widget.prochesParEndroit.length; i++)
            if (widget.prochesParEndroit[i].isNotEmpty) ...[
              section(
                i == 0 ? 'PRÈS DE VOS PHOTOS' : 'PRÈS D\'UNE AUTRE PHOTO',
              ),
              for (final lieu in widget.prochesParEndroit[i]) ligne(lieu),
            ],
        const SizedBox(height: TablTokens.espaceS),
        TablBoutonTexte(
          libelle: 'Je ne trouve pas mon restaurant',
          onPresse: _passerALaMain,
        ),
      ],
    );
  }

  Widget _vueCarte() {
    final centre =
        widget.endroits.firstOrNull ??
        position ??
        // Bruxelles, faute de mieux.
        (latitude: 50.8467, longitude: 4.3525);
    final touche = _toucheSurCarte;
    return Stack(
      children: [
        Positioned.fill(
          child: TablCarteMapbox(
            geojsonLieux: geojsonChoixLieux(
              _lieuxCarte,
              reperes: widget.endroits,
              cleChoisie: touche?.cle,
            ),
            latitudeInitiale: centre.latitude,
            longitudeInitiale: centre.longitude,
            zoomInitial: 16,
            onTapLieu: (cle) => setState(() {
              _toucheSurCarte = _lieuxCarte
                  .where((l) => l.cle == cle)
                  .firstOrNull;
            }),
            onTapCarte: () => setState(() => _toucheSurCarte = null),
            onZoneVisible: _zoneVisible,
            avecMaPosition: widget.endroits.isEmpty,
            dansUneFeuille: true,
          ),
        ),
        if (widget.endroits.isNotEmpty && touche == null)
          Positioned(
            left: TablTokens.espaceM,
            right: TablTokens.espaceM,
            bottom: TablTokens.espaceL,
            child: Center(
              child: TablPiluleVerre(
                icone: Icons.circle_outlined,
                libelle: widget.endroits.length > 1
                    ? 'Ronds blancs : les endroits de vos photos'
                    : 'Rond blanc : l\'endroit de vos photos',
              ),
            ),
          ),
        if (touche != null)
          Positioned(
            left: TablTokens.espaceM,
            right: TablTokens.espaceM,
            bottom: TablTokens.espaceL,
            child: TablCarteChoixLieu(
              nom: touche.nom,
              detail: _detail(touche),
              libelleBouton: 'Choisir ce restaurant',
              onChoisir: () => Navigator.of(context).pop(touche),
            ),
          ),
      ],
    );
  }
}

/// « Quand était-ce ? » : le mois et l'année, le jour si on s'en
/// souvient, et le moment du repas. « Valider » reste éteint sur une
/// date pas encore passée.
class _FeuilleQuand extends StatefulWidget {
  const _FeuilleQuand({
    required this.date,
    required this.moment,
    required this.maintenant,
  });

  final DateSouvenir date;
  final String? moment;
  final DateTime maintenant;

  @override
  State<_FeuilleQuand> createState() => _FeuilleQuandState();
}

class _FeuilleQuandState extends State<_FeuilleQuand> {
  late DateSouvenir _date = widget.date;
  late String? _moment = widget.moment;
  late final List<int> _annees = anneesSouvenir(widget.maintenant);

  @override
  Widget build(BuildContext context) {
    final futur = _date.estDansLeFutur(widget.maintenant);
    final jours = joursDansLeMois(_date.annee, _date.mois);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TablTokens.espaceL - 4,
          0,
          TablTokens.espaceL - 4,
          TablTokens.espaceM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Quand était-ce ?',
              style: TablTokens.titreAffichage.copyWith(fontSize: 26),
            ),
            const SizedBox(height: TablTokens.espaceS),
            TablRouesDate(
              jours: ['—', for (var j = 1; j <= jours; j++) '$j'],
              indexJour: _date.jour ?? 0,
              onJour: (i) => setState(
                () => _date = _date.copierAvec(jour: () => i == 0 ? null : i),
              ),
              mois: [for (var m = 1; m <= 12; m++) majuscule(nomDuMois(m))],
              indexMois: _date.mois - 1,
              onMois: (i) =>
                  setState(() => _date = _date.copierAvec(mois: i + 1)),
              annees: [for (final a in _annees) '$a'],
              indexAnnee: math.max(_annees.indexOf(_date.annee), 0),
              onAnnee: (i) =>
                  setState(() => _date = _date.copierAvec(annee: _annees[i])),
            ),
            const SizedBox(height: TablTokens.espaceS),
            Wrap(
              spacing: TablTokens.espaceS,
              alignment: WrapAlignment.center,
              children: [
                for (final m in const ['midi', 'soir'])
                  TablPuceSelection(
                    libelle: libelleMomentRepas(m)!,
                    selectionnee: _moment == m,
                    onBascule: () =>
                        setState(() => _moment = _moment == m ? null : m),
                  ),
              ],
            ),
            SizedBox(
              height: 28,
              child: futur
                  ? Center(
                      child: Text(
                        'Cette date n\'est pas encore passée.',
                        style: TablTokens.legende.copyWith(
                          color: TablTokens.erreur,
                        ),
                      ),
                    )
                  : null,
            ),
            TablBouton(
              libelle: 'Valider',
              onPresse: futur
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop((date: _date, moment: _moment)),
            ),
          ],
        ),
      ),
    );
  }
}
