import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

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

/// Résumé humain du partage, affiché juste avant "Garder ce moment."
/// (megaprompt Bloc 5, règles 13-14, 17) — jamais de jargon ("audience",
/// "grant"), jamais un libellé contradictoire : une fois qu'une Table
/// est choisie, le résultat effectif n'est plus "Personnel" même si
/// [partagerAvecCercle] est resté à `false` (règle 14).
String resumePartage(bool partagerAvecCercle, List<String> nomsTables) {
  if (nomsTables.isEmpty) {
    return partagerAvecCercle
        ? 'Visible par votre cercle.'
        : 'Visible uniquement par vous.';
  }
  final tables = nomsTables.join(' + ');
  return partagerAvecCercle
      ? 'Visible par votre cercle et les membres de $tables.'
      : 'Visible uniquement par les membres de $tables.';
}

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
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;

  /// `null` par défaut (même principe que `EcranPrincipal.tableService`) :
  /// si absent, le picker "Ajouter à une Table" (megaprompt Bloc 5,
  /// règle 19) reste simplement masqué plutôt que de planter — un moment
  /// reste publiable sans Table, ce n'est jamais obligatoire.
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
  Uint8List? _photo;
  Uint8List? _boissonPhoto;
  String? _emotion;
  final Set<String> _amisTaguesIds = {};
  final Set<String> _impressionsSelectionnees = {};
  bool _partagerAvecCercle = true;
  final Set<String> _tablesSelectionneesIds = {};

  String? _erreurNom;
  String? _erreurVille;
  bool _enCours = false;

  late final Future<List<ProfilPublic>> _futurAmis =
      widget.abonnementService.mesAmis();
  late final Future<List<ResumeTable>> _futurTables =
      widget.tableService?.mesTables() ?? Future.value(const []);

  @override
  void dispose() {
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
    setState(() => _etape = _Etape.capturer);
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
        nomRestaurant: _nomRestaurant.text.trim(),
        ville: _ville.text.trim(),
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
        nomRestaurant: _nomRestaurant.text.trim(),
        ville: _ville.text.trim(),
        photo: photo,
        emotion: Emotion.depuisEmoji(emotion)!,
        legende: _legende.text.trim().isEmpty ? null : _legende.text.trim(),
        amisTaguesIds: _amisTaguesIds.toList(),
        impressions: _impressionsSelectionnees.toList(),
        boissonTexte: _boissonTexte.text.trim().isEmpty
            ? null
            : _boissonTexte.text.trim(),
        boissonPhoto: _boissonPhoto,
        partagerAvecCercle: _partagerAvecCercle,
        tableIds: _tablesSelectionneesIds.toList(),
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
            nomRestaurant: _nomRestaurant.text,
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
            nomRestaurant: _nomRestaurant.text,
            ville: _ville.text,
            emotion: _emotion,
            onEmotionChangee: (e) => setState(() => _emotion = e),
            legende: _legende,
            futurAmis: _futurAmis,
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
            partagerAvecCercle: _partagerAvecCercle,
            onVisibiliteChangee: (v) =>
                setState(() => _partagerAvecCercle = v),
            futurTables: _futurTables,
            tablesSelectionneesIds: _tablesSelectionneesIds,
            onBasculerTable: (id) => setState(() {
              if (!_tablesSelectionneesIds.remove(id)) {
                _tablesSelectionneesIds.add(id);
              }
            }),
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
    required this.futurAmis,
    required this.amisTaguesIds,
    required this.onBasculerAmi,
    required this.impressionsSelectionnees,
    required this.onBasculerImpression,
    required this.boissonTexte,
    required this.boissonPhoto,
    required this.onChoisirPhotoBoisson,
    required this.partagerAvecCercle,
    required this.onVisibiliteChangee,
    required this.futurTables,
    required this.tablesSelectionneesIds,
    required this.onBasculerTable,
    required this.enCours,
    required this.onGarderCeMoment,
  });

  final Uint8List photo;
  final String nomRestaurant;
  final String ville;
  final String? emotion;
  final ValueChanged<String> onEmotionChangee;
  final TextEditingController legende;
  final Future<List<ProfilPublic>> futurAmis;
  final Set<String> amisTaguesIds;
  final ValueChanged<String> onBasculerAmi;
  final Set<String> impressionsSelectionnees;
  final ValueChanged<String> onBasculerImpression;
  final TextEditingController boissonTexte;
  final Uint8List? boissonPhoto;
  final VoidCallback onChoisirPhotoBoisson;
  final bool partagerAvecCercle;
  final ValueChanged<bool> onVisibiliteChangee;

  /// Tables où l'utilisateur a une adhésion active (megaprompt Bloc 5,
  /// règle 19) — jamais les Tables en attente/quittées.
  final Future<List<ResumeTable>> futurTables;
  final Set<String> tablesSelectionneesIds;
  final ValueChanged<String> onBasculerTable;

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
          Text('Amis présents', style: TablTokens.sousTitre),
          const SizedBox(height: TablTokens.espaceS),
          FutureBuilder<List<ProfilPublic>>(
            future: futurAmis,
            builder: (context, snapshot) {
              final amis = snapshot.data ?? const [];
              if (amis.isEmpty) {
                return Text(
                  'Personne à taguer pour l\'instant.',
                  style: TablTokens.legende,
                );
              }
              return Wrap(
                spacing: TablTokens.espaceS,
                runSpacing: TablTokens.espaceS,
                children: [
                  for (final ami in amis)
                    FilterChip(
                      label: Text(ami.pseudo),
                      selected: amisTaguesIds.contains(ami.id),
                      onSelected: (_) => onBasculerAmi(ami.id),
                      backgroundColor: TablTokens.surface,
                      selectedColor: TablTokens.primaire.withValues(
                        alpha: 0.2,
                      ),
                      labelStyle: TablTokens.corps,
                      side: const BorderSide(color: TablTokens.bordure),
                    ),
                ],
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
                FilterChip(
                  label: Text(impression),
                  selected: impressionsSelectionnees.contains(impression),
                  onSelected: (_) => onBasculerImpression(impression),
                  backgroundColor: TablTokens.surface,
                  selectedColor: TablTokens.primaire.withValues(alpha: 0.2),
                  labelStyle: TablTokens.legende,
                  side: const BorderSide(color: TablTokens.bordure),
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
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                label: Text('Partager avec mon cercle'),
              ),
              ButtonSegment(value: false, label: Text('Garder pour moi')),
            ],
            selected: {partagerAvecCercle},
            onSelectionChanged: (selection) =>
                onVisibiliteChangee(selection.first),
            // Segment actif en aplat doré plein, texte foncé dessus —
            // même traitement que le sélecteur Carte/Liste de la
            // direction artistique (`scraps/04-e3.png`), pas une simple
            // teinte.
            style: SegmentedButton.styleFrom(
              backgroundColor: TablTokens.surface,
              selectedBackgroundColor: TablTokens.primaire,
              foregroundColor: TablTokens.texte,
              selectedForegroundColor: TablTokens.texteSurPrimaire,
            ),
          ),
          FutureBuilder<List<ResumeTable>>(
            future: futurTables,
            builder: (context, snapshot) {
              final tables = snapshot.data ?? const [];
              // Masqué plutôt qu'un état vide inutile (règle 75 : le
              // composer doit rester léger) — pas de Table, rien à
              // proposer ici.
              if (tables.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: TablTokens.espaceL),
                  Text('Ajouter à une Table', style: TablTokens.sousTitre),
                  const SizedBox(height: TablTokens.espaceS),
                  Wrap(
                    spacing: TablTokens.espaceS,
                    runSpacing: TablTokens.espaceS,
                    children: [
                      for (final table in tables)
                        FilterChip(
                          label: Text(
                            table.emoji == null
                                ? table.nom
                                : '${table.nom} ${table.emoji}',
                          ),
                          selected: tablesSelectionneesIds.contains(table.id),
                          onSelected: (_) => onBasculerTable(table.id),
                          backgroundColor: TablTokens.surface,
                          selectedColor: TablTokens.primaire.withValues(
                            alpha: 0.2,
                          ),
                          labelStyle: TablTokens.legende,
                          side: const BorderSide(color: TablTokens.bordure),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: TablTokens.espaceM),
          FutureBuilder<List<ResumeTable>>(
            future: futurTables,
            builder: (context, snapshot) {
              final tables = snapshot.data ?? const [];
              final nomsSelectionnes = [
                for (final table in tables)
                  if (tablesSelectionneesIds.contains(table.id)) table.nom,
              ];
              return Text(
                resumePartage(partagerAvecCercle, nomsSelectionnes),
                textAlign: TextAlign.center,
                style: TablTokens.legende.copyWith(
                  color: TablTokens.texteDoux,
                ),
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
