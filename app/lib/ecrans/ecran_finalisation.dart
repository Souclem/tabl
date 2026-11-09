import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';
import 'feuille_audience.dart';

/// La finalisation d'un moment, dernière étape de la création : les photos
/// en grand, le lieu, la date et la légende en haut, à droite le rail
/// (« Ajouter un mot », « Ce qui ressort », « Avec qui »), puis comment
/// c'était — obligatoire —, qui peut voir, et le bouton principal.
///
/// Un moment en création vient d'un [brouillon] : chaque choix y est écrit
/// aussitôt, « Plus tard » n'a donc rien à sauvegarder. Se ferme sur `true`
/// une fois le moment publié.
///
/// Avec [aModifier], le même écran modifie un moment déjà publié : ses
/// photos et sa date sont figées, le bouton devient « Enregistrer ». Se
/// ferme sur `true` une fois enregistré.
///
/// Toujours sombre, quelle que soit l'apparence de l'app.
class EcranFinalisation extends StatelessWidget {
  const EcranFinalisation({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.brouillons,
    this.brouillon,
    this.aModifier,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.ouvrirPhotos,
    this.maintenant = DateTime.now,
  }) : assert(
         (brouillon != null && brouillons != null) != (aModifier != null),
         'Un brouillon (avec ses BrouillonsLocaux) ou un moment à modifier.',
       );

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// Les brouillons du téléphone ; avec [brouillon].
  final BrouillonsLocaux? brouillons;

  /// Le moment à finaliser, tel qu'il est sur le téléphone.
  final Brouillon? brouillon;

  /// Le moment à modifier (l'un des siens) ; `null` : en publier un.
  final SouvenirFeed? aModifier;

  /// `null` : la feuille « Qui peut voir ? » ne propose pas de Tables.
  final TableService? tableService;

  /// `null` : ni restaurant proposé, ni recherche (saisie à la main).
  final RechercheLieuService? rechercheLieuService;

  /// `null` : pas de restaurant proposé d'après l'endroit où l'on est.
  final PositionService? positionService;

  /// « Choisir les photos » : la feuille des photos du moment. Au retour,
  /// le brouillon est relu. `null` : le bouton ne fait rien.
  final Future<void> Function()? ouvrirPhotos;

  /// L'heure d'aujourd'hui, pour dire « Hier » ou « Aujourd'hui ».
  final DateTime Function() maintenant;

  @override
  Widget build(BuildContext context) => Theme(
    data: TablTheme.sombre(),
    child: _CorpsFinalisation(parent: this),
  );
}

class _CorpsFinalisation extends StatefulWidget {
  const _CorpsFinalisation({required this.parent});

  final EcranFinalisation parent;

  @override
  State<_CorpsFinalisation> createState() => _CorpsFinalisationState();
}

class _CorpsFinalisationState extends State<_CorpsFinalisation>
    with PropositionLieu<_CorpsFinalisation> {
  EcranFinalisation get _ecran => widget.parent;

  @override
  RechercheLieuService? get rechercheLieuService => _ecran.rechercheLieuService;

  @override
  PositionService? get positionService => _ecran.positionService;

  bool get _modification => _ecran.aModifier != null;

  /// Le brouillon tel qu'il est écrit sur le téléphone (création).
  Brouillon? _brouillon;

  /// Le moment à modifier tel qu'il était ; `null` tant qu'il se charge.
  MomentModifiable? _initial;

  Coordonnees? _ici;
  int _page = 0;
  Emotion? _emotion;
  final _mot = TextEditingController();
  final Map<String, int> _etoiles = {};
  final Set<String> _amisTaguesIds = {};
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;
  bool _enCours = false;
  bool _publie = false;

  /// La rangée d'émotions « respire » : on rappelle qu'un choix manque.
  bool _rappelEmotion = false;
  Timer? _finRappel;

  late final Future<DonneesAudience> _futurAudience = chargerDonneesAudience(
    _ecran.abonnementService,
    _ecran.tableService,
  );
  DonneesAudience? _donnees;

  @override
  void initState() {
    super.initState();
    final brouillon = _ecran.brouillon;
    if (brouillon != null) {
      _appliquer(brouillon);
      if (brouillon.lieu == null) _chercherLieu();
    } else {
      _chargerMoment();
    }
    _futurAudience.then((donnees) {
      if (mounted) setState(() => _donnees = donnees);
    }, onError: (Object e) => debugPrint('EcranFinalisation: audience : $e'));
  }

  @override
  void dispose() {
    _finRappel?.cancel();
    _mot.dispose();
    super.dispose();
  }

  void _appliquer(Brouillon b) {
    _brouillon = b;
    lieu = b.lieu;
    lieuChoisi = b.lieu != null;
    _emotion = b.emotion;
    _mot.text = b.legende ?? '';
    _etoiles
      ..clear()
      ..addAll(b.etoiles);
    _amisTaguesIds
      ..clear()
      ..addAll(b.avecQuiIds);
    _audience = b.audience;
  }

  Future<void> _chargerMoment() async {
    try {
      final m = await _ecran.souvenirService.momentModifiable(
        _ecran.aModifier!.id,
      );
      if (!mounted) return;
      setState(() {
        _initial = m;
        lieu = m.lieu;
        lieuChoisi = true;
        _emotion = m.emotion;
        _mot.text = m.legende ?? '';
        _amisTaguesIds.addAll(m.amisTaguesIds);
        _audience = m.audience;
      });
    } catch (e) {
      debugPrint('EcranFinalisation: moment à modifier : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      Navigator.of(context).pop();
    }
  }

  /// Le restaurant proposé : là où les photos ont été prises, sinon là où
  /// l'on est.
  Future<void> _chercherLieu() async {
    final b = _brouillon;
    final prises = [
      for (final p in b?.photos ?? const <PhotoBrouillon>[])
        MetadonneesPhoto(
          prisLe: p.priseLe,
          latitude: p.position?.latitude,
          longitude: p.position?.longitude,
        ),
    ];
    final suggestion = precompleter(prises, maintenant: _ecran.maintenant());
    final position = suggestion.position;
    if (position != null) {
      chercherAutour([
        position,
        ...suggestion.autresEndroits.take(2),
      ], repere: RepereDistance.photo);
      return;
    }
    try {
      final ici = await _ecran.positionService?.positionActuelle();
      if (!mounted || ici == null) return;
      _ici = ici;
      chercherAutour([ici], repere: RepereDistance.vous);
    } catch (e) {
      debugPrint('EcranFinalisation: position : $e');
    }
  }

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

  /// Écrit un changement dans le brouillon, sans attendre.
  void _persister(Brouillon Function(Brouillon actuel) transformation) {
    final b = _brouillon;
    final brouillons = _ecran.brouillons;
    if (b == null || brouillons == null) return;
    brouillons
        .mettreAJour(b.id, transformation)
        .then((maj) {
          if (maj != null) _brouillon = maj;
        })
        .catchError((Object e) {
          debugPrint('EcranFinalisation: brouillon : $e');
        });
  }

  /// Quelque chose a changé depuis l'ouverture du moment à modifier.
  bool get _aChange {
    final i = _initial;
    if (i == null) return false;
    return lieu?.restaurantId != i.lieu.restaurantId ||
        lieu?.nom != i.lieu.nom ||
        _emotion != i.emotion ||
        _mot.text.trim() != (i.legende ?? '').trim() ||
        !setEquals(_amisTaguesIds, i.amisTaguesIds) ||
        _audience.mode != i.audience.mode ||
        !setEquals(_audience.tableIds, i.audience.tableIds) ||
        !setEquals(_audience.personneIds, i.audience.personneIds);
  }

  Map<String, String> get _pseudos => {
    for (final r in _donnees?.relations ?? const <ProfilPublic>[])
      r.id: r.pseudo,
  };

  List<ImageProvider> get _images {
    final b = _brouillon;
    final brouillons = _ecran.brouillons;
    if (b != null && brouillons != null) {
      return [for (final p in b.photos) brouillons.imagePhoto(b.id, p.id)];
    }
    final m = _ecran.aModifier;
    if (m == null) return const [];
    return [
      for (final url in [?m.photoUrl, ...m.autresPhotosUrls]) NetworkImage(url),
    ];
  }

  EtapeFinalisation get _etape => etapeFinalisation(
    modification: _modification,
    aDesPhotos: _images.isNotEmpty,
    aUnLieu: lieu != null,
  );

  // --- Les gestes du rail et des commandes -----------------------------

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

  Future<void> _ajouterUnMot() async {
    final c = TablCouleurs.of(context);
    await _feuille(
      'Ajouter un mot',
      (redessiner) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TablChampTexte(
            libelle: '',
            controleur: _mot,
            indication: 'Ce que vous voudrez vous rappeler',
            lignes: 4,
            erreur: ValidationSouvenir.mot(_mot.text.trim()),
            onChanged: (_) => redessiner(),
          ),
          if (compteurMot(_mot.text.characters.length) case final compteur?)
            Padding(
              padding: const EdgeInsets.only(top: TablTokens.espaceXs),
              child: Text(compteur, style: c.legende),
            ),
        ],
      ),
    );
    final texte = _mot.text.trim();
    _persister((b) => b.copieAvec(legende: () => texte.isEmpty ? null : texte));
  }

  Future<void> _ceQuiRessort() async {
    await _feuille(
      'Ce qui ressort',
      (redessiner) => TablNotesEtoiles(
        lignes: [
          for (final categorie in categoriesEtoiles)
            (
              cle: categorie.cle,
              libelle: categorie.libelle,
              note: _etoiles[categorie.cle] ?? 0,
            ),
        ],
        onNote: (cle, note) {
          HapticFeedback.selectionClick();
          _etoiles[cle] = note;
          redessiner();
        },
        onEffacer: (cle) {
          _etoiles.remove(cle);
          redessiner();
        },
      ),
    );
    final notes = Map.of(_etoiles);
    _persister((b) => b.copieAvec(etoiles: notes));
  }

  Future<void> _avecQui() async {
    final c = TablCouleurs.of(context);
    await _feuille('Avec qui ?', (redessiner) {
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
    final ids = Set.of(_amisTaguesIds);
    _persister((b) => b.copieAvec(avecQuiIds: ids));
  }

  Future<void> _choisirAudience() async {
    final choisie = await ouvrirFeuilleAudience(
      context,
      audienceInitiale: _audience,
      abonnementService: _ecran.abonnementService,
      tableService: _ecran.tableService,
      donnees: _futurAudience,
      amisTaguesIds: _amisTaguesIds,
    );
    if (choisie == null || !mounted) return;
    setState(() => _audience = choisie);
    _persister((b) => b.copieAvec(audience: choisie));
  }

  Future<void> _choisirLieu() async {
    await changerLieu();
    final choisi = lieu;
    if (!lieuChoisi || choisi == null) return;
    _persister((b) => b.copieAvec(lieu: () => choisi));
  }

  void _choisirEmotion(String emoji) {
    final choisie = Emotion.depuisEmoji(emoji);
    if (choisie == null) return;
    HapticFeedback.selectionClick();
    setState(() => _emotion = choisie);
    _persister((b) => b.copieAvec(emotion: () => choisie));
  }

  /// Le bouton grisé a été touché : la rangée d'émotions respire un
  /// instant.
  void _rappelerEmotion() {
    HapticFeedback.lightImpact();
    _finRappel?.cancel();
    setState(() => _rappelEmotion = true);
    _finRappel = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _rappelEmotion = false);
    });
  }

  Future<void> _actionPrincipale() async {
    final etape = _etape;
    if (etape.exigeEmotion && _emotion == null) {
      _rappelerEmotion();
      return;
    }
    switch (etape) {
      case EtapeFinalisation.choisirPhotos:
        await _ecran.ouvrirPhotos?.call();
        await _relireBrouillon();
      case EtapeFinalisation.choisirLieu:
        await _choisirLieu();
      case EtapeFinalisation.publier:
        await _publier();
      case EtapeFinalisation.enregistrer:
        await _enregistrer();
    }
  }

  /// Les photos ont pu changer pendant la feuille « Photos du moment ».
  Future<void> _relireBrouillon() async {
    final b = _brouillon;
    final relu = b == null ? null : await _ecran.brouillons?.charger(b.id);
    if (relu == null || !mounted) return;
    setState(() {
      _brouillon = relu;
      _page = _page.clamp(0, relu.photos.isEmpty ? 0 : relu.photos.length - 1);
    });
    if (lieu == null && endroits.isEmpty) _chercherLieu();
  }

  Future<void> _publier() async {
    final b = _brouillon;
    final brouillons = _ecran.brouillons;
    final lieu = this.lieu;
    final emotion = _emotion;
    if (b == null || brouillons == null || lieu == null || emotion == null) {
      return;
    }
    final legende = _mot.text.trim();
    final erreur = ValidationSouvenir.mot(legende);
    if (erreur != null) {
      afficherMessage(context, erreur);
      return;
    }

    setState(() => _enCours = true);
    try {
      final octets = [
        for (final p in b.photos) await brouillons.octetsPhoto(b.id, p.id),
      ];
      final lues = await lirePhotos(octets);
      final tablesEnEchec = await _ecran.souvenirService.publier(
        lieu: lieu,
        photos: octets,
        emotion: emotion,
        legende: legende.isEmpty ? null : legende,
        amisTaguesIds: _amisTaguesIds.toList(),
        notes: Map.of(_etoiles),
        audience: _audience,
        empreintes: [for (final p in lues) ?p.metadonnees.empreinte],
      );
      await brouillons.supprimerBrouillon(b.id);
      if (!mounted) return;
      // Le moment est publié malgré tout (règle 51) : un message discret
      // plutôt qu'une erreur bloquante.
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
      debugPrint('EcranFinalisation: $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _enregistrer() async {
    final initial = _initial;
    final lieu = this.lieu;
    final emotion = _emotion;
    if (initial == null || lieu == null || emotion == null) return;
    final legende = _mot.text.trim();
    final erreur = ValidationSouvenir.mot(legende);
    if (erreur != null) {
      afficherMessage(context, erreur);
      return;
    }

    setState(() => _enCours = true);
    try {
      final tablesEnEchec = await _ecran.souvenirService.modifier(
        _ecran.aModifier!.id,
        MomentModifiable(
          lieu: lieu,
          emotion: emotion,
          legende: legende.isEmpty ? null : legende,
          amisTaguesIds: Set.of(_amisTaguesIds),
          impressions: initial.impressions,
          boissonTexte: initial.boissonTexte,
          notes: initial.notes,
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
      debugPrint('EcranFinalisation: modification : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
      setState(() => _enCours = false);
    }
  }

  /// Fermer. Un moment en création est déjà gardé sur le téléphone ; un
  /// moment modifié ne perd pas ses changements sans le vouloir.
  Future<void> _fermer() async {
    if (!_modification || !_aChange) {
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

  // --- L'écran -----------------------------------------------------------

  String get _dateLisible {
    final maintenant = _ecran.maintenant();
    final m = _ecran.aModifier;
    if (m != null) {
      return dateLisibleMomentPublie(
        m.dateVisite,
        m.moment,
        maintenant: maintenant,
      );
    }
    final b = _brouillon;
    return b == null
        ? ''
        : dateLisibleBrouillon(b.priseLe, maintenant: maintenant);
  }

  @override
  Widget build(BuildContext context) {
    const c = TablCouleurs.sombre;
    final images = _images;
    final etape = _etape;
    final pseudos = _pseudos;
    final horsAudience =
        _donnees?.contexte.taguesHorsAudience(_audience, _amisTaguesIds) ??
        const <String>{};
    final grise = etape.exigeEmotion && _emotion == null;
    final lieuAffiche =
        lieu?.nom ?? (_modification ? _ecran.aModifier!.restaurantNom : null);

    return PopScope(
      canPop: !_enCours && !_modification,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && !_enCours && !_publie) _fermer();
      },
      child: Scaffold(
        backgroundColor: c.fond,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            TablCarrouselFinalisation(
              images: images,
              page: _page.clamp(0, images.isEmpty ? 0 : images.length - 1),
              onPage: (p) => setState(() => _page = p),
            ),
            Positioned(
              left: TablTokens.espaceM,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: TablTokens.espaceL),
                  child: _modification
                      ? TablBoutonVerre(
                          icone: Icons.close_rounded,
                          libelle: 'Fermer',
                          onPresse: _enCours ? () {} : _fermer,
                        )
                      : TablBoutonTexteVerre(
                          libelle: 'Plus tard',
                          onPresse: _enCours ? () {} : _fermer,
                        ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TablTokens.espaceL - 4,
                    0,
                    TablTokens.espaceL - 4,
                    TablTokens.espaceS,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TablEnteteFinalisation(
                              lieu: lieuAffiche,
                              indicationLieu: 'Où étiez-vous ?',
                              aConfirmer:
                                  !_modification && lieu != null && !lieuChoisi,
                              dateLisible: _dateLisible,
                              legende: legendeAffichee(_mot.text),
                              indicationLegende: 'Ajouter un mot',
                              onPresseLieu: _choisirLieu,
                              onPresseLegende: _ajouterUnMot,
                            ),
                          ),
                          const SizedBox(width: TablTokens.espaceM),
                          TablRailFinalisation(
                            actions: [
                              (
                                libelle: 'Ajouter un mot',
                                icone: Icons.edit_outlined,
                                renseigne: _mot.text.trim().isNotEmpty,
                                onPresse: _ajouterUnMot,
                              ),
                              if (!_modification)
                                (
                                  libelle: 'Ce qui ressort',
                                  icone: Icons.star_outline_rounded,
                                  renseigne: _etoiles.isNotEmpty,
                                  onPresse: _ceQuiRessort,
                                ),
                              (
                                libelle: 'Avec qui',
                                icone: Icons.people_outline_rounded,
                                renseigne: _amisTaguesIds.isNotEmpty,
                                onPresse: _avecQui,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: TablTokens.espaceL),
                      Text(
                        'Comment c\'était ?',
                        style: c.legende.copyWith(color: c.texte),
                      ),
                      const SizedBox(height: TablTokens.espaceXs),
                      TablSelecteurEmotion(
                        emojis: [for (final e in Emotion.proposees) e.emoji],
                        libelles: [
                          for (final e in Emotion.proposees) e.libelle,
                        ],
                        selection: _emotion?.emoji,
                        montrerNoms: _rappelEmotion,
                        onSelection: _choisirEmotion,
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
                      const SizedBox(height: TablTokens.espaceM),
                      Row(
                        children: [
                          TablPiluleAudience(
                            libelle: libelleAudience(
                              _audience,
                              nomsTables: {
                                for (final t
                                    in _donnees?.tables ??
                                        const <ResumeTable>[])
                                  t.id: t.nom,
                              },
                              pseudos: pseudos,
                            ),
                            restreinte:
                                _audience.mode != ModeAudience.toutLeMonde,
                            onPresse: _choisirAudience,
                          ),
                          const SizedBox(width: TablTokens.espaceM),
                          Expanded(
                            child: TablBoutonPrincipalFinalisation(
                              libelle: etape.libelle,
                              grise: grise,
                              vitre: !etape.exigeEmotion,
                              enCours: _enCours,
                              onPresse: _actionPrincipale,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_publie) const Positioned.fill(child: TablMomentGarde()),
          ],
        ),
      ),
    );
  }
}
