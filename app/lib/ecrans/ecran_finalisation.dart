import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';
import 'ecran_cloche.dart';
import 'feuille_audience.dart';
import 'feuille_avec_qui.dart';
import 'feuille_ou_et_quand.dart';

/// La finalisation d'un moment, dernière étape de la création : les photos
/// en grand, le lieu, la date et la légende en haut, à droite le rail
/// (« Ajouter un mot », « Ce qui ressort », « Avec qui »), puis comment
/// c'était — obligatoire —, qui peut voir, et le bouton principal.
///
/// Un moment en création vient d'un [brouillon] : chaque choix y est écrit
/// aussitôt, « Plus tard » n'a donc rien à sauvegarder. « Publier » écrit le
/// brouillon puis ouvre la cloche ([EcranCloche]) ; l'écran se ferme alors
/// sur le [ResultatCloche] (`null` : fermé par « Plus tard »). « Modifier »
/// dans la cloche ramène ici.
///
/// Avec [aModifier], le même écran modifie un moment déjà publié : ses
/// photos et sa date sont figées, pas de cloche, le bouton devient
/// « Enregistrer ». Se ferme sur `true` une fois enregistré.
///
/// Toujours sombre, quelle que soit l'apparence de l'app.
class EcranFinalisation extends StatelessWidget {
  const EcranFinalisation({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.brouillons,
    this.brouillon,
    this.envois,
    this.aModifier,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.reprendrePhotos,
    this.maintenant = DateTime.now,
  }) : assert(
         (brouillon != null && brouillons != null && envois != null) !=
             (aModifier != null),
         'Un brouillon (avec ses BrouillonsLocaux et les envois) ou un '
         'moment à modifier.',
       );

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// Les brouillons du téléphone ; avec [brouillon].
  final BrouillonsLocaux? brouillons;

  /// Ce qui publie un brouillon (la cloche) ; avec [brouillon].
  final EnvoiPublications? envois;

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

  /// Le bouton appareil photo, en haut à droite : retour à la caméra, sur
  /// le même brouillon (tout ce qui est choisi ici y est déjà écrit).
  /// `null` : pas de bouton (en modification).
  final VoidCallback? reprendrePhotos;

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

  int _page = 0;
  Emotion? _emotion;
  final _mot = TextEditingController();

  /// Le plat qu'on écrit dans « Ce qui ressort ».
  final _plat = TextEditingController();
  String? _erreurPlat;
  final Map<String, int> _etoiles = {};
  final Set<String> _amisTaguesIds = {};
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;
  bool _enCours = false;

  /// La rangée d'émotions, ou la ligne du lieu, « respire » : on rappelle
  /// qu'un choix manque.
  bool _rappelEmotion = false;
  bool _rappelLieu = false;
  Timer? _finRappel;

  /// L'hôte coché d'office dans « Avec qui » quand on l'a choisi (« Chez
  /// Emma ») : décoché s'il cesse d'être l'hôte.
  String? _hoteTague;

  /// Les personnes que je suis : chez qui l'on peut avoir mangé. Chargées
  /// la première fois qu'on ouvre « Où et quand ».
  Future<List<ProfilPublic>>? _futurSuivis;

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
    _plat.dispose();
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
      // Seulement pour trier les restaurants proches : jamais enregistrée.
      final ici = await _ecran.positionService?.positionActuelle();
      if (!mounted || ici == null) return;
      chercherAutour([ici], repere: RepereDistance.vous);
    } catch (e) {
      debugPrint('EcranFinalisation: position : $e');
    }
  }

  /// Écrit un changement dans le brouillon, sans attendre.
  Future<void> _persister(
    Brouillon Function(Brouillon actuel) transformation,
  ) async {
    final b = _brouillon;
    final brouillons = _ecran.brouillons;
    if (b == null || brouillons == null) return;
    try {
      final maj = await brouillons.mettreAJour(b.id, transformation);
      if (maj == null || !mounted) return;
      setState(() => _brouillon = maj);
    } catch (e) {
      debugPrint('EcranFinalisation: brouillon : $e');
    }
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

  EtapeFinalisation get _etape =>
      etapeFinalisation(modification: _modification);

  // --- Les gestes du rail et des commandes -----------------------------

  Future<void> _ajouterUnMot() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: voileFeuilleCreation,
      elevation: 0,
      builder: (contexteFeuille) => StatefulBuilder(
        builder: (contexteFeuille, redessiner) {
          final media = MediaQuery.of(contexteFeuille);
          return Padding(
            padding: EdgeInsets.only(
              bottom: media.viewInsets.bottom > 0
                  ? media.viewInsets.bottom
                  : media.padding.bottom,
            ),
            child: TablBarreMot(
              controleur: _mot,
              indication: 'Une anecdote, un mot, un souvenir…',
              compteur: compteurMot(_mot.text.characters.length),
              erreur: ValidationSouvenir.mot(_mot.text.trim()),
              onChanged: (_) {
                setState(() {});
                redessiner(() {});
              },
              onValider: () => Navigator.of(contexteFeuille).pop(),
            ),
          );
        },
      ),
    );
    final texte = _mot.text.trim();
    _persister((b) => b.copieAvec(legende: () => texte.isEmpty ? null : texte));
  }

  Future<void> _ceQuiRessort() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: voileFeuilleCreation,
      builder: (contexteFeuille) => StatefulBuilder(
        builder: (contexteFeuille, redessiner) {
          void noter(VoidCallback changement) {
            changement();
            setState(() {});
            redessiner(() {});
          }

          void ajouterPlat(String nom) {
            if (nom.trim().isEmpty) return;
            final erreur = validationPlat(nom, _etoiles);
            noter(() {
              _erreurPlat = erreur;
              if (erreur == null) {
                _etoiles[clePlat(nom)] = 0;
                _plat.clear();
              }
            });
          }

          return TablCadreFeuilleCreation(
            titre: 'Ce qui ressort',
            note: 'facultatif',
            libelleAction: _etoiles.isEmpty ? 'Passer' : 'Valider',
            onAction: () => Navigator.of(contexteFeuille).pop(),
            contenu: TablNotesEtoiles(
              lignes: [
                for (final categorie in categoriesEtoiles)
                  (
                    cle: categorie.cle,
                    libelle: categorie.libelle,
                    note: _etoiles[categorie.cle] ?? 0,
                  ),
              ],
              note: noteEtoiles,
              onNote: (cle, note) {
                HapticFeedback.selectionClick();
                noter(() => _etoiles[cle] = note);
              },
              onEffacer: (cle) => noter(() => _etoiles.remove(cle)),
              rubriqueEcrites: 'Plats',
              lignesEcrites: [
                for (final cle in clesPlats(_etoiles))
                  (cle: cle, libelle: nomPlat(cle), note: _etoiles[cle]!),
              ],
              onRetirer: (cle) => noter(() => _etoiles.remove(cle)),
              controleurAjout: _plat,
              indicationAjout: 'Noter un plat, un vin…',
              onAjouter: ajouterPlat,
              erreurAjout: _erreurPlat,
              limiteAjout: peutAjouterPlat(_etoiles)
                  ? null
                  : libelleLimitePlats,
            ),
          );
        },
      ),
    );
    // Un plat écrit sans toucher « Ajouter » n'est pas perdu.
    if (validationPlat(_plat.text, _etoiles) == null) {
      _etoiles[clePlat(_plat.text)] = 0;
    }
    _plat.clear();
    _erreurPlat = null;
    if (mounted) setState(() {});
    final notes = Map.of(_etoiles);
    _persister((b) => b.copieAvec(etoiles: notes));
  }

  Future<void> _avecQui() => ouvrirFeuilleAvecQui(
    context,
    personnes: _donnees?.relations ?? const <ProfilPublic>[],
    selection: _amisTaguesIds,
    onChange: (ids) {
      setState(() {
        _amisTaguesIds
          ..clear()
          ..addAll(ids);
      });
      _persister((b) => b.copieAvec(avecQuiIds: ids));
    },
  );

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

  /// « Où et quand » : le lieu, et pour un moment en création le moment du
  /// repas. Se change en touchant le lieu en haut ; « Publier » ne l'ouvre
  /// jamais.
  Future<void> _choisirLieu() async {
    final b = _brouillon;
    final resultat = await ouvrirFeuilleOuEtQuand(
      context,
      lieu: lieu,
      moment: b == null ? null : momentDuBrouillon(b.priseLe),
      endroits: endroits,
      prochesParEndroit: prochesParEndroit,
      repere: repere,
      rechercheLieuService: rechercheLieuService,
      positionService: positionService,
      personnesSuivies: _futurSuivis ??= _chargerSuivis(),
      prioritairesIds: _amisTaguesIds,
    );
    if (resultat == null || !mounted) return;
    final choisi = resultat.lieu;
    final moment = resultat.moment;
    final tagues = _taguerHote(choisi?.hoteId);
    setState(() {
      lieu = choisi ?? lieu;
      lieuChoisi = choisi != null || lieuChoisi;
    });
    if (b == null) return;
    final priseLe = moment == null
        ? null
        : priseLePourMoment(b.priseLe, moment);
    _persister(
      (actuel) => actuel.copieAvec(
        lieu: choisi == null ? null : () => choisi,
        priseLe: priseLe,
        avecQuiIds: tagues,
      ),
    );
  }

  /// Une erreur (même immédiate) ne bloque pas la feuille : elle propose
  /// alors Chez moi et le reste, sans personne.
  Future<List<ProfilPublic>> _chargerSuivis() async =>
      (await _ecran.abonnementService.abonnesEtAbonnements()).abonnements;

  /// Chez quelqu'un de Tabl : il était à table, coché d'office dans « Avec
  /// qui » (décochable, comme un tag : l'audience ne change pas). L'hôte
  /// d'avant, coché d'office, est décoché. Renvoie la sélection si elle a
  /// changé.
  Set<String>? _taguerHote(String? hoteId) {
    final avant = _hoteTague;
    if (hoteId == avant) return null;
    setState(() {
      if (avant != null) _amisTaguesIds.remove(avant);
      _hoteTague = hoteId != null && _amisTaguesIds.add(hoteId) ? hoteId : null;
    });
    return Set.of(_amisTaguesIds);
  }

  void _choisirEmotion(String emoji) {
    final choisie = Emotion.depuisEmoji(emoji);
    if (choisie == null) return;
    HapticFeedback.selectionClick();
    setState(() => _emotion = choisie);
    _persister((b) => b.copieAvec(emotion: () => choisie));
  }

  /// Le bouton grisé a été touché : ce qui manque (le lieu, l'émotion)
  /// respire un instant.
  void _rappelerCeQuiManque() {
    HapticFeedback.lightImpact();
    _finRappel?.cancel();
    setState(() {
      _rappelLieu = lieu == null;
      _rappelEmotion = _emotion == null;
    });
    _finRappel = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _rappelEmotion = false;
          _rappelLieu = false;
        });
      }
    });
  }

  Future<void> _actionPrincipale() async {
    if (_emotion == null || lieu == null) {
      _rappelerCeQuiManque();
      return;
    }
    switch (_etape) {
      case EtapeFinalisation.publier:
        await _publier();
      case EtapeFinalisation.enregistrer:
        await _enregistrer();
    }
  }

  Future<void> _publier() async {
    final b = _brouillon;
    final brouillons = _ecran.brouillons;
    final envois = _ecran.envois;
    final choisi = lieu;
    final emotion = _emotion;
    if (b == null ||
        brouillons == null ||
        envois == null ||
        choisi == null ||
        emotion == null) {
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
      // La cloche publie le brouillon tel qu'il est écrit : tout ce qui est
      // à l'écran (même un lieu seulement proposé) y passe d'abord.
      final ecrit = await brouillons.mettreAJour(
        b.id,
        (actuel) => actuel.copieAvec(
          lieu: () => choisi,
          emotion: () => emotion,
          legende: () => legende.isEmpty ? null : legende,
          etoiles: Map.of(_etoiles),
          avecQuiIds: Set.of(_amisTaguesIds),
          audience: _audience,
        ),
      );
      if (ecrit == null) throw StateError('Brouillon ${b.id} introuvable.');
      if (!mounted) return;
      final resultat = await Navigator.of(context).push<ResultatCloche>(
        MaterialPageRoute(
          builder: (_) => EcranCloche(brouillonId: b.id, envois: envois),
        ),
      );
      if (!mounted) return;
      if (resultat != null && resultat.issue != IssueCloche.modifier) {
        Navigator.of(context).pop(resultat);
      }
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
    final grise = _emotion == null || lieu == null;
    final choisi = lieu;

    return PopScope(
      canPop: !_enCours && !_modification,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte && !_enCours) _fermer();
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
            if (_ecran.reprendrePhotos case final reprendre?)
              Positioned(
                right: TablTokens.espaceM,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: TablTokens.espaceL),
                    child: TablBoutonIconeVerre(
                      icone: Icons.photo_camera_outlined,
                      libelle: 'Reprendre des photos',
                      onPresse: _enCours ? () {} : reprendre,
                    ),
                  ),
                ),
              ),
            // Le lieu, le moment du repas et le mot, sous « Plus tard ».
            Positioned(
              left: 20,
              right: 20,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  // « Plus tard » : 40 px de haut, puis 14 px d'air.
                  padding: const EdgeInsets.only(
                    top: TablTokens.espaceL + 40 + 14,
                  ),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: TablEnteteFinalisation(
                      // « Chez vous », « Chez Emma », « Bibo ».
                      lieu:
                          choisi?.libelle ??
                          // Le moment à modifier, le temps qu'il se charge.
                          (_modification
                              ? _ecran.aModifier!.restaurantNom
                              : null),
                      lieuPrive: choisi?.personnel ?? false,
                      hotePseudo: choisi?.hotePseudo,
                      hotePhotoUrl: choisi?.hotePhotoUrl,
                      rappelLieu: _rappelLieu,
                      dateLisible: _dateLisible,
                      legende: legendeAffichee(_mot.text),
                      onPresseLieu: _choisirLieu,
                      onPresseLegende: _ajouterUnMot,
                    ),
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
                      Align(
                        alignment: Alignment.centerRight,
                        child: TablRailFinalisation(
                          actions: [
                            (
                              libelle: 'Ajouter un mot',
                              icone: const IconeMot(),
                              renseigne: _mot.text.trim().isNotEmpty,
                              onPresse: _ajouterUnMot,
                            ),
                            if (!_modification)
                              (
                                libelle: 'Ce qui ressort',
                                icone: const IconeEtincelle(),
                                renseigne: _etoiles.isNotEmpty,
                                onPresse: _ceQuiRessort,
                              ),
                            (
                              libelle: 'Avec qui',
                              icone: const IconeAvecQui(),
                              renseigne: _amisTaguesIds.isNotEmpty,
                              onPresse: _avecQui,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: TablTokens.espaceL),
                      Text(
                        'Comment c\'était ?',
                        textAlign: TextAlign.center,
                        style: c.titreAffichage.copyWith(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(blurRadius: 8, color: Color(0x99000000)),
                          ],
                        ),
                      ),
                      const SizedBox(height: TablTokens.espaceS),
                      TablSelecteurEmotion(
                        emojis: [for (final e in Emotion.proposees) e.emoji],
                        libelles: [
                          for (final e in Emotion.proposees) e.libelle,
                        ],
                        selection: _emotion?.emoji,
                        montrerNoms: _rappelEmotion,
                        enCapsule: true,
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
                      LayoutBuilder(
                        builder: (context, rangee) => Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: TablPiluleAudience(
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
                            ),
                            const SizedBox(width: 10),
                            // L'audience garde toujours de quoi se lire.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(128, rangee.maxWidth - 130),
                              ),
                              child: TablBoutonPrincipalFinalisation(
                                libelle: etape.libelle,
                                grise: grise,
                                enCours: _enCours,
                                onPresse: _actionPrincipale,
                              ),
                            ),
                          ],
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
    );
  }
}
