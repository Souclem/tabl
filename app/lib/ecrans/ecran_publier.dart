import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_audience.dart';

/// Les 4 emoji parmi lesquels choisir à la finalisation — ensemble et
/// ordre exacts du prototype fonctionnel (`emotionOptions` dans
/// `instruction/Clément (2)/Tabl.dc.html`).
const List<String> _emojisEmotion = ['😍', '🤩', '🙂', '😐'];

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

enum _Etape { lieu, capturer, brouillon, finaliser, animation, publie }

/// Créer un moment : Lieu → Capturer → Brouillon → Finaliser → Animation
/// → Publié (voir `instruction/Clément (2)/scraps/clement.txt`, B7-B11).
///
/// La détection automatique du restaurant (B2-B6, autorisation de
/// localisation, page restaurant à 3 états, scan de menu) n'est pas
/// construite : la saisie manuelle du lieu reste le point d'entrée de ce
/// flux, comme avant.
class EcranPublier extends StatefulWidget {
  const EcranPublier({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// `null` : pas de recherche dans l'annuaire, seulement la saisie à
  /// la main (nom + ville).
  final RechercheLieuService? rechercheLieuService;

  /// `null` : suggestions non triées par proximité, restaurant ajouté à
  /// la main sans position.
  final PositionService? positionService;

  /// `null` par défaut (même principe que `EcranPrincipal.tableService`) :
  /// si absent, la feuille "Qui peut voir ?" ne propose simplement pas
  /// de Tables — un moment reste publiable sans Table.
  final TableService? tableService;

  @override
  State<EcranPublier> createState() => _EcranPublierState();
}

class _EcranPublierState extends State<EcranPublier> {
  final _nomRestaurant = TextEditingController();
  final _ville = TextEditingController();
  final _legende = TextEditingController();
  final _boissonTexte = TextEditingController();

  _Etape _etape = _Etape.lieu;

  // Étape Lieu : recherche dans l'annuaire, ou saisie à la main si le
  // restaurant est introuvable (ou la recherche indisponible).
  final _recherche = TextEditingController();
  Timer? _attenteRecherche;
  List<LieuRestaurant> _suggestions = const [];
  bool _rechercheEnCours = false;
  late bool _saisieManuelle = widget.rechercheLieuService == null;
  Coordonnees? _position;
  LieuRestaurant? _lieu;
  Uint8List? _photo;
  Uint8List? _boissonPhoto;
  String? _emotion;
  final Set<String> _amisTaguesIds = {};
  final Set<String> _impressionsSelectionnees = {};
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;

  String? _erreurNom;
  String? _erreurVille;
  bool _enCours = false;

  // Chargé une fois : sert à la fois aux personnes à taguer, au libellé
  // de l'audience et à la feuille "Qui peut voir ?".
  late final Future<DonneesAudience> _futurAudience = chargerDonneesAudience(
    widget.abonnementService,
    widget.tableService,
  );

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

  @override
  void initState() {
    super.initState();
    _localiser();
  }

  Future<void> _localiser() async {
    final position = await widget.positionService?.positionActuelle();
    if (!mounted || position == null) return;
    setState(() => _position = position);
    // Une recherche tapée avant que la position n'arrive est relancée
    // pour profiter du tri par proximité.
    if (_recherche.text.trim().length >= 2) _rechercher(_recherche.text);
  }

  void _rechercherAvecAttente(String texte) {
    _attenteRecherche?.cancel();
    _attenteRecherche = Timer(
      const Duration(milliseconds: 250),
      () => _rechercher(texte),
    );
  }

  Future<void> _rechercher(String texte) async {
    final service = widget.rechercheLieuService;
    if (service == null) return;
    if (texte.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    setState(() => _rechercheEnCours = true);
    try {
      final resultats = await service.rechercher(
        texte,
        latitude: _position?.latitude,
        longitude: _position?.longitude,
      );
      // Une réponse plus ancienne que la frappe actuelle est ignorée.
      if (!mounted || _recherche.text != texte) return;
      setState(() => _suggestions = resultats);
    } catch (e) {
      debugPrint('EcranPublier: recherche de lieu : $e');
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _rechercheEnCours = false);
    }
  }

  void _choisirLieu(LieuRestaurant lieu) {
    FocusScope.of(context).unfocus();
    setState(() {
      _lieu = lieu;
      _etape = _Etape.capturer;
    });
  }

  void _passerEnSaisieManuelle() {
    setState(() {
      _saisieManuelle = true;
      // On reprend ce qui a déjà été tapé comme nom.
      if (_nomRestaurant.text.isEmpty) _nomRestaurant.text = _recherche.text;
    });
  }

  @override
  void dispose() {
    _attenteRecherche?.cancel();
    _recherche.dispose();
    _nomRestaurant.dispose();
    _ville.dispose();
    _legende.dispose();
    _boissonTexte.dispose();
    super.dispose();
  }

  void _validerLieu() {
    final erreurNom = ValidationSouvenir.nomRestaurant(_nomRestaurant.text);
    final erreurVille = ValidationSouvenir.ville(_ville.text);
    setState(() {
      _erreurNom = erreurNom;
      _erreurVille = erreurVille;
    });
    if (erreurNom != null || erreurVille != null) return;
    // Ajouté à la main : la position du téléphone, puisqu'on publie le
    // plus souvent depuis le restaurant lui-même.
    _choisirLieu(
      LieuRestaurant.manuel(
        nom: _nomRestaurant.text.trim(),
        ville: _ville.text.trim(),
        latitude: _position?.latitude,
        longitude: _position?.longitude,
      ),
    );
  }

  Future<void> _choisirPhoto({required bool pourBoisson}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: TablTokens.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: TablTokens.texte,
              ),
              title: const Text('Prendre une photo', style: TablTokens.corps),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_outlined,
                color: TablTokens.texte,
              ),
              title: const Text(
                'Choisir depuis la photothèque',
                style: TablTokens.corps,
              ),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final fichier = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (fichier == null) return;

    final octets = await fichier.readAsBytes();
    if (!mounted) return;
    setState(() {
      if (pourBoisson) {
        _boissonPhoto = octets;
      } else {
        _photo = octets;
      }
    });
  }

  void _continuerDepuisCapture() {
    if (_photo == null) return;
    setState(() => _etape = _Etape.brouillon);
  }

  Future<void> _plusTard() async {
    final photo = _photo;
    if (photo == null) return;

    setState(() => _enCours = true);
    try {
      await widget.souvenirService.enregistrerBrouillon(
        lieu: _lieu!,
        photo: photo,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      afficherMessage(context, 'Enregistré. Reprenez-le depuis votre profil.');
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _finaliserMaintenant() {
    setState(() => _etape = _Etape.finaliser);
  }

  Future<void> _garderCeMoment() async {
    final emotion = _emotion;
    final photo = _photo;
    if (emotion == null || photo == null) return;

    final erreurLegende = ValidationSouvenir.legende(_legende.text.trim());
    if (erreurLegende != null) {
      afficherMessage(context, erreurLegende);
      return;
    }

    setState(() => _enCours = true);
    try {
      final tablesEnEchec = await widget.souvenirService.publier(
        lieu: _lieu!,
        photo: photo,
        emotion: Emotion.depuisEmoji(emotion)!,
        legende: _legende.text.trim().isEmpty ? null : _legende.text.trim(),
        amisTaguesIds: _amisTaguesIds.toList(),
        impressions: _impressionsSelectionnees.toList(),
        boissonTexte: _boissonTexte.text.trim().isEmpty
            ? null
            : _boissonTexte.text.trim(),
        boissonPhoto: _boissonPhoto,
        audience: _audience,
      );
      if (!mounted) return;
      // Le moment est publié malgré tout (règle 51) : un message discret
      // plutôt qu'une erreur bloquante, la publication elle-même a
      // réussi.
      if (tablesEnEchec.isNotEmpty) {
        afficherMessage(
          context,
          tablesEnEchec.length == 1
              ? 'Publié, mais impossible de l\'ajouter à cette Table.'
              : 'Publié, mais impossible de l\'ajouter à ${tablesEnEchec.length} Tables.',
        );
      }
      setState(() => _etape = _Etape.animation);
    } catch (_) {
      if (!mounted) return;
      afficherMessage(context, messageErreurGenerique);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablTokens.fond,
      body: SafeArea(
        child: switch (_etape) {
          _Etape.lieu when !_saisieManuelle => _EtapeRechercheLieu(
            recherche: _recherche,
            suggestions: _suggestions,
            enCours: _rechercheEnCours,
            onAnnuler: () => Navigator.of(context).pop(),
            onChange: _rechercherAvecAttente,
            onChoisir: _choisirLieu,
            onIntrouvable: _passerEnSaisieManuelle,
          ),
          _Etape.lieu => _EtapeLieu(
            nomRestaurant: _nomRestaurant,
            ville: _ville,
            erreurNom: _erreurNom,
            erreurVille: _erreurVille,
            onAnnuler: () => Navigator.of(context).pop(),
            onNomChange: () {
              if (_erreurNom != null) setState(() => _erreurNom = null);
            },
            onVilleChange: () {
              if (_erreurVille != null) setState(() => _erreurVille = null);
            },
            onContinuer: _validerLieu,
          ),
          _Etape.capturer => _EtapeCapture(
            nomRestaurant: _lieu!.nom,
            photo: _photo,
            onAnnuler: () => Navigator.of(context).pop(),
            onDeclencher: () => _choisirPhoto(pourBoisson: false),
            onContinuer: _photo != null ? _continuerDepuisCapture : null,
          ),
          _Etape.brouillon => _EtapeBrouillon(
            photo: _photo!,
            enCours: _enCours,
            onFinaliserMaintenant: _finaliserMaintenant,
            onPlusTard: _plusTard,
          ),
          _Etape.finaliser => _EtapeFinaliser(
            photo: _photo!,
            nomRestaurant: _lieu!.nom,
            ville: _lieu!.description,
            emotion: _emotion,
            onEmotionChangee: (e) => setState(() => _emotion = e),
            legende: _legende,
            futurAudience: _futurAudience,
            amisTaguesIds: _amisTaguesIds,
            onBasculerAmi: (id) => setState(() {
              if (!_amisTaguesIds.remove(id)) _amisTaguesIds.add(id);
            }),
            impressionsSelectionnees: _impressionsSelectionnees,
            onBasculerImpression: (imp) => setState(() {
              if (!_impressionsSelectionnees.remove(imp)) {
                _impressionsSelectionnees.add(imp);
              }
            }),
            boissonTexte: _boissonTexte,
            boissonPhoto: _boissonPhoto,
            onChoisirPhotoBoisson: () => _choisirPhoto(pourBoisson: true),
            audience: _audience,
            onChoisirAudience: _choisirAudience,
            enCours: _enCours,
            onGarderCeMoment: _emotion != null ? _garderCeMoment : null,
          ),
          _Etape.animation => _EtapeAnimation(
            onTerminee: () {
              if (mounted) setState(() => _etape = _Etape.publie);
            },
          ),
          _Etape.publie => _EtapePublie(
            onRetournerAuFeed: () => Navigator.of(context).pop(),
            onVoirMonMoment: () => Navigator.of(context).pop(),
          ),
        },
      ),
    );
  }
}

/// En-tête commun aux étapes où l'utilisateur avance à son rythme (Lieu,
/// Capturer, Finaliser) : retour/annulation à gauche, indicateur de
/// progression au centre parmi ces 3 étapes-là (Brouillon, Animation et
/// Publié sont des écrans de confirmation, sans pagination).
class _EnTeteEtape extends StatelessWidget {
  const _EnTeteEtape({required this.index, required this.onAnnuler});

  final int index;
  final VoidCallback onAnnuler;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceM,
        0,
      ),
      child: Row(
        children: [
          TablBoutonRetour(onPresse: onAnnuler),
          Expanded(
            child: Center(child: TablIndicateurPage(total: 3, index: index)),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// Étape Lieu, version recherche : on tape quelques lettres, l'annuaire
/// propose, un tap choisit et passe directement à la photo.
class _EtapeRechercheLieu extends StatelessWidget {
  const _EtapeRechercheLieu({
    required this.recherche,
    required this.suggestions,
    required this.enCours,
    required this.onAnnuler,
    required this.onChange,
    required this.onChoisir,
    required this.onIntrouvable,
  });

  final TextEditingController recherche;
  final List<LieuRestaurant> suggestions;
  final bool enCours;
  final VoidCallback onAnnuler;
  final ValueChanged<String> onChange;
  final ValueChanged<LieuRestaurant> onChoisir;
  final VoidCallback onIntrouvable;

  @override
  Widget build(BuildContext context) {
    final aCherche = recherche.text.trim().length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnTeteEtape(index: 0, onAnnuler: onAnnuler),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL,
            TablTokens.espaceL,
            TablTokens.espaceL,
            TablTokens.espaceM,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Où êtes-vous ?', style: TablTokens.grandTitre),
              const SizedBox(height: TablTokens.espaceL),
              TablChampTexte(
                libelle: 'Restaurant',
                controleur: recherche,
                indication: 'Le Campus, ¡Toma!…',
                iconePrefixe: Icons.search_rounded,
                onChanged: onChange,
              ),
            ],
          ),
        ),
        if (enCours)
          const LinearProgressIndicator(
            minHeight: 2,
            color: TablTokens.primaire,
            backgroundColor: Colors.transparent,
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: TablTokens.espaceL),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              for (final lieu in suggestions)
                TablLigneSuggestionLieu(
                  nom: lieu.nom,
                  description: lieu.description,
                  onSelection: () => onChoisir(lieu),
                ),
              if (aCherche && !enCours && suggestions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: TablTokens.espaceM,
                  ),
                  child: Text(
                    'Aucun restaurant trouvé.',
                    style: TablTokens.legende,
                  ),
                ),
              if (aCherche)
                TablBoutonTexte(
                  libelle: 'Je ne trouve pas mon restaurant',
                  onPresse: onIntrouvable,
                ),
              const SizedBox(height: TablTokens.espaceL),
            ],
          ),
        ),
      ],
    );
  }
}

class _EtapeLieu extends StatelessWidget {
  const _EtapeLieu({
    required this.nomRestaurant,
    required this.ville,
    required this.erreurNom,
    required this.erreurVille,
    required this.onAnnuler,
    required this.onNomChange,
    required this.onVilleChange,
    required this.onContinuer,
  });

  final TextEditingController nomRestaurant;
  final TextEditingController ville;
  final String? erreurNom;
  final String? erreurVille;
  final VoidCallback onAnnuler;
  final VoidCallback onNomChange;
  final VoidCallback onVilleChange;
  final VoidCallback onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnTeteEtape(index: 0, onAnnuler: onAnnuler),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(TablTokens.espaceL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Où êtes-vous ?', style: TablTokens.grandTitre),
                const SizedBox(height: TablTokens.espaceXl),
                TablChampTexte(
                  libelle: 'Restaurant',
                  controleur: nomRestaurant,
                  indication: 'Le Comptoir',
                  erreur: erreurNom,
                  onChanged: (_) => onNomChange(),
                ),
                const SizedBox(height: TablTokens.espaceL),
                TablChampTexte(
                  libelle: 'Ville',
                  controleur: ville,
                  indication: 'Paris',
                  erreur: erreurVille,
                  onChanged: (_) => onVilleChange(),
                ),
                const Spacer(),
                TablBouton(libelle: 'Continuer', onPresse: onContinuer),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EtapeCapture extends StatelessWidget {
  const _EtapeCapture({
    required this.nomRestaurant,
    required this.photo,
    required this.onAnnuler,
    required this.onDeclencher,
    required this.onContinuer,
  });

  final String nomRestaurant;
  final Uint8List? photo;
  final VoidCallback onAnnuler;
  final VoidCallback onDeclencher;
  final VoidCallback? onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _EnTeteEtape(index: 1, onAnnuler: onAnnuler),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceS),
          child: Text(
            nomRestaurant,
            textAlign: TextAlign.center,
            style: TablTokens.sousTitre,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: TablTokens.espaceL,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TablTokens.arrondiL),
              child: photo != null
                  ? Image.memory(
                      photo!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Container(
                      color: TablTokens.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.restaurant_outlined,
                        size: 40,
                        color: TablTokens.texteDoux,
                      ),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(TablTokens.espaceL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                key: const Key('bouton-declencheur'),
                onTap: onDeclencher,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: TablTokens.primaire,
                    border: Border.all(color: TablTokens.texte, width: 3),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (photo != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL,
              0,
              TablTokens.espaceL,
              TablTokens.espaceL,
            ),
            child: TablBouton(libelle: 'Continuer', onPresse: onContinuer),
          ),
      ],
    );
  }
}

class _EtapeBrouillon extends StatelessWidget {
  const _EtapeBrouillon({
    required this.photo,
    required this.enCours,
    required this.onFinaliserMaintenant,
    required this.onPlusTard,
  });

  final Uint8List photo;
  final bool enCours;
  final VoidCallback onFinaliserMaintenant;
  final VoidCallback onPlusTard;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: TablTokens.espaceL),
          Text('Moment enregistré.', style: TablTokens.grandTitre),
          const SizedBox(height: TablTokens.espaceL),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TablTokens.arrondiL),
              child: Image.memory(
                photo,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          const SizedBox(height: TablTokens.espaceL),
          TablBouton(
            libelle: 'Finaliser maintenant',
            enCours: enCours,
            onPresse: onFinaliserMaintenant,
          ),
          const SizedBox(height: TablTokens.espaceS),
          TablBoutonTexte(
            libelle: 'Plus tard',
            onPresse: enCours ? null : onPlusTard,
          ),
        ],
      ),
    );
  }
}

class _EtapeFinaliser extends StatelessWidget {
  const _EtapeFinaliser({
    required this.photo,
    required this.nomRestaurant,
    required this.ville,
    required this.emotion,
    required this.onEmotionChangee,
    required this.legende,
    required this.futurAudience,
    required this.amisTaguesIds,
    required this.onBasculerAmi,
    required this.impressionsSelectionnees,
    required this.onBasculerImpression,
    required this.boissonTexte,
    required this.boissonPhoto,
    required this.onChoisirPhotoBoisson,
    required this.audience,
    required this.onChoisirAudience,
    required this.enCours,
    required this.onGarderCeMoment,
  });

  final Uint8List photo;
  final String nomRestaurant;
  final String ville;
  final String? emotion;
  final ValueChanged<String> onEmotionChangee;
  final TextEditingController legende;
  final Future<DonneesAudience> futurAudience;
  final Set<String> amisTaguesIds;
  final ValueChanged<String> onBasculerAmi;
  final Set<String> impressionsSelectionnees;
  final ValueChanged<String> onBasculerImpression;
  final TextEditingController boissonTexte;
  final Uint8List? boissonPhoto;
  final VoidCallback onChoisirPhotoBoisson;
  final AudienceSouvenir audience;
  final VoidCallback onChoisirAudience;

  final bool enCours;
  final VoidCallback? onGarderCeMoment;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(TablTokens.espaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(TablTokens.arrondiM),
                child: Image.memory(
                  photo,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: TablTokens.espaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomRestaurant, style: TablTokens.sousTitre),
                    Text(
                      ville,
                      style: TablTokens.legende.copyWith(
                        color: TablTokens.texteDoux,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TablTokens.espaceXl),
          Text(
            'Comment c\'était ?',
            textAlign: TextAlign.center,
            style: TablTokens.titre,
          ),
          const SizedBox(height: TablTokens.espaceM),
          TablSelecteurEmotion(
            emojis: _emojisEmotion,
            selection: emotion,
            onSelection: onEmotionChangee,
          ),
          const SizedBox(height: TablTokens.espaceXl),
          TablChampTexte(
            libelle: 'Qu\'est-ce que tu voudrais te rappeler dans 5 ans ?',
            controleur: legende,
            indication: 'Quelques mots (facultatif)',
            lignes: 2,
          ),
          const SizedBox(height: TablTokens.espaceL),
          Text('Personnes présentes', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
          FutureBuilder<DonneesAudience>(
            future: futurAudience,
            builder: (context, snapshot) {
              final amis = snapshot.data?.relations ?? const [];
              if (amis.isEmpty) {
                return Text(
                  'Personne à taguer pour l\'instant.',
                  style: TablTokens.legende,
                );
              }
              return TablSelecteurPersonnes(
                personnes: [
                  for (final ami in amis)
                    PersonneSelectionnable(
                      id: ami.id,
                      pseudo: ami.pseudo,
                      photoUrl: ami.photoUrl,
                    ),
                ],
                selection: amisTaguesIds,
                onBascule: onBasculerAmi,
              );
            },
          ),
          const SizedBox(height: TablTokens.espaceL),
          Text('Ce qui ressort (facultatif)', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
          Wrap(
            spacing: TablTokens.espaceS,
            runSpacing: TablTokens.espaceS,
            children: [
              for (final impression in _impressionsDisponibles)
                TablPuceSelection(
                  libelle: impression,
                  selectionnee: impressionsSelectionnees.contains(impression),
                  onBascule: () => onBasculerImpression(impression),
                ),
            ],
          ),
          const SizedBox(height: TablTokens.espaceL),
          Text('Boisson (facultatif)', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TablChampTexte(
                  libelle: '',
                  controleur: boissonTexte,
                  indication: 'Un Margaux 2018',
                ),
              ),
              const SizedBox(width: TablTokens.espaceS),
              GestureDetector(
                onTap: onChoisirPhotoBoisson,
                child: Container(
                  width: TablTokens.hauteurControle,
                  height: TablTokens.hauteurControle,
                  decoration: BoxDecoration(
                    color: TablTokens.surface,
                    borderRadius: BorderRadius.circular(TablTokens.arrondiS),
                    border: Border.all(color: TablTokens.bordure),
                  ),
                  child: boissonPhoto != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(
                            TablTokens.arrondiS,
                          ),
                          child: Image.memory(boissonPhoto!, fit: BoxFit.cover),
                        )
                      : const Icon(
                          Icons.add_a_photo_outlined,
                          color: TablTokens.texteDoux,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TablTokens.espaceL),
          FutureBuilder<DonneesAudience>(
            future: futurAudience,
            builder: (context, snapshot) {
              final donnees = snapshot.data;
              final pseudos = {
                for (final r in donnees?.relations ?? const <ProfilPublic>[])
                  r.id: r.pseudo,
              };
              final horsAudience =
                  donnees?.contexte.taguesHorsAudience(
                    audience,
                    amisTaguesIds,
                  ) ??
                  const <String>{};
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TablLigneAudience(
                    libelle: libelleAudience(
                      audience,
                      nomsTables: {
                        for (final t in donnees?.tables ?? const <ResumeTable>[])
                          t.id: t.nom,
                      },
                      pseudos: pseudos,
                    ),
                    restreinte: audience.mode != ModeAudience.toutLeMonde,
                    onPresse: onChoisirAudience,
                  ),
                  for (final id in horsAudience)
                    Padding(
                      padding: const EdgeInsets.only(top: TablTokens.espaceXs),
                      child: Text(
                        '${pseudos[id] ?? 'Une personne taguée'} '
                        'ne verra pas ce moment.',
                        style: TablTokens.legende.copyWith(
                          color: TablTokens.primaire,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: TablTokens.espaceL),
          TablBouton(
            libelle: 'Garder ce moment.',
            enCours: enCours,
            onPresse: onGarderCeMoment,
          ),
        ],
      ),
    );
  }
}

/// Écran purement transitoire (~1,5 s), non cliquable, enchaîne
/// automatiquement — voir B10. Déclenche une vibration haptique légère
/// à la confirmation (impossible à montrer sur une maquette statique,
/// mais déclenchable ici).
class _EtapeAnimation extends StatefulWidget {
  const _EtapeAnimation({required this.onTerminee});

  final VoidCallback onTerminee;

  @override
  State<_EtapeAnimation> createState() => _EtapeAnimationState();
}

class _EtapeAnimationState extends State<_EtapeAnimation> {
  Timer? _minuteur;

  @override
  void initState() {
    super.initState();
    HapticFeedback.lightImpact();
    _minuteur = Timer(
      const Duration(milliseconds: 1500),
      widget.onTerminee,
    );
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.check_circle_rounded, color: TablTokens.primaire, size: 64),
    );
  }
}

class _EtapePublie extends StatelessWidget {
  const _EtapePublie({
    required this.onRetournerAuFeed,
    required this.onVoirMonMoment,
  });

  final VoidCallback onRetournerAuFeed;
  final VoidCallback onVoirMonMoment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Moment ajouté.',
            textAlign: TextAlign.center,
            style: TablTokens.grandTitre,
          ),
          const SizedBox(height: TablTokens.espaceXxl),
          TablBouton(libelle: 'Retourner au feed', onPresse: onRetournerAuFeed),
          const SizedBox(height: TablTokens.espaceS),
          TablBoutonTexte(
            libelle: 'Voir mon moment',
            onPresse: onVoirMonMoment,
          ),
        ],
      ),
    );
  }
}
