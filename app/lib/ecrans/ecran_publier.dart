import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

/// Les 4 phrases parmi lesquelles choisir à l'étape 2 — reprises telles
/// quelles de la maquette Claude Design (`ratingOptions`).
const List<String> _phrases = [
  'Belle découverte.',
  'Moment réussi.',
  "J'y retourne.",
  'Inoubliable.',
];

/// Publier un souvenir : capture d'abord, comme dans la maquette
/// (`isPublish` de `Tabl.dc.html`) — une photo, une phrase, le
/// restaurant. Rien d'autre : pas de date ni de moment à choisir (déduits
/// de maintenant), pas de suggestion de lieux proches (pas de géoloc
/// branchée), pas de retour en arrière entre étapes — seul `X` annule
/// tout, comme dans la maquette.
class EcranPublier extends StatefulWidget {
  const EcranPublier({super.key, required this.souvenirService});

  final SouvenirService souvenirService;

  @override
  State<EcranPublier> createState() => _EcranPublierState();
}

class _EcranPublierState extends State<EcranPublier> {
  final _nomRestaurant = TextEditingController();
  final _ville = TextEditingController();

  int _etape = 0;
  Uint8List? _photo;
  String _legende = _phrases.first;
  String? _erreurNom;
  String? _erreurVille;
  bool _enCours = false;

  @override
  void dispose() {
    _nomRestaurant.dispose();
    _ville.dispose();
    super.dispose();
  }

  Future<void> _choisirPhoto() async {
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
              title: const Text(
                'Prendre une photo',
                style: TablTokens.corps,
              ),
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
    setState(() => _photo = octets);
  }

  void _continuerDepuisPhoto() {
    if (_photo == null) return;
    setState(() => _etape = 1);
  }

  void _continuerDepuisPhrase() {
    setState(() => _etape = 2);
  }

  Future<void> _publier() async {
    final erreurNom = ValidationSouvenir.nomRestaurant(_nomRestaurant.text);
    final erreurVille = ValidationSouvenir.ville(_ville.text);

    setState(() {
      _erreurNom = erreurNom;
      _erreurVille = erreurVille;
    });
    if (erreurNom != null || erreurVille != null) return;

    final photo = _photo;
    if (photo == null) return;

    setState(() => _enCours = true);
    try {
      await widget.souvenirService.publier(
        nomRestaurant: _nomRestaurant.text.trim(),
        ville: _ville.text.trim(),
        photo: photo,
        legende: _legende,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      afficherMessage(context, 'Souvenir publié.');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceM,
                TablTokens.espaceS,
                TablTokens.espaceM,
                0,
              ),
              child: Row(
                children: [
                  TablBoutonRetour(
                    onPresse: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: TablIndicateurPage(total: 3, index: _etape),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(TablTokens.espaceL),
                child: switch (_etape) {
                  0 => _EtapePhoto(
                    photo: _photo,
                    onChoisirPhoto: _choisirPhoto,
                    onContinuer: _photo != null ? _continuerDepuisPhoto : null,
                  ),
                  1 => _EtapePhrase(
                    phraseActive: _legende,
                    onSelection: (p) => setState(() => _legende = p),
                    onContinuer: _continuerDepuisPhrase,
                  ),
                  _ => _EtapeRestaurant(
                    nomRestaurant: _nomRestaurant,
                    ville: _ville,
                    erreurNom: _erreurNom,
                    erreurVille: _erreurVille,
                    enCours: _enCours,
                    onNomChange: () {
                      if (_erreurNom != null) setState(() => _erreurNom = null);
                    },
                    onVilleChange: () {
                      if (_erreurVille != null) {
                        setState(() => _erreurVille = null);
                      }
                    },
                    onPublier: _publier,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EtapePhoto extends StatelessWidget {
  const _EtapePhoto({
    required this.photo,
    required this.onChoisirPhoto,
    required this.onContinuer,
  });

  final Uint8List? photo;
  final VoidCallback onChoisirPhoto;
  final VoidCallback? onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Capturez ce moment.', style: TablTokens.grandTitre),
        const SizedBox(height: TablTokens.espaceL),
        Expanded(
          child: GestureDetector(
            onTap: onChoisirPhoto,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TablTokens.arrondiL),
              child: photo != null
                  ? Image.memory(photo!, fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: TablTokens.surface,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_a_photo_outlined,
                            size: 40,
                            color: TablTokens.texteDoux,
                          ),
                          const SizedBox(height: TablTokens.espaceM),
                          Text(
                            'Ajoutez la photo de votre souvenir',
                            style: TablTokens.corps.copyWith(
                              color: TablTokens.texteDoux,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablBouton(libelle: 'Continuer', onPresse: onContinuer),
      ],
    );
  }
}

class _EtapePhrase extends StatelessWidget {
  const _EtapePhrase({
    required this.phraseActive,
    required this.onSelection,
    required this.onContinuer,
  });

  final String phraseActive;
  final ValueChanged<String> onSelection;
  final VoidCallback onContinuer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Comment c\'était ?', style: TablTokens.grandTitre),
        const SizedBox(height: TablTokens.espaceXl),
        for (final phrase in _phrases) ...[
          _BoutonPhrase(
            phrase: phrase,
            actif: phrase == phraseActive,
            onPresse: () => onSelection(phrase),
          ),
          const SizedBox(height: TablTokens.espaceM),
        ],
        const Spacer(),
        TablBouton(libelle: 'Continuer', onPresse: onContinuer),
      ],
    );
  }
}

class _BoutonPhrase extends StatelessWidget {
  const _BoutonPhrase({
    required this.phrase,
    required this.actif,
    required this.onPresse,
  });

  final String phrase;
  final bool actif;
  final VoidCallback onPresse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: OutlinedButton(
        onPressed: onPresse,
        style: OutlinedButton.styleFrom(
          backgroundColor: actif
              ? TablTokens.primaire.withValues(alpha: 0.14)
              : null,
          side: BorderSide(
            color: actif ? TablTokens.primaire : TablTokens.bordure,
            width: actif ? 2 : 1,
          ),
          foregroundColor: TablTokens.texte,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TablTokens.arrondiL),
          ),
        ),
        child: Text(phrase, style: TablTokens.sousTitre),
      ),
    );
  }
}

class _EtapeRestaurant extends StatelessWidget {
  const _EtapeRestaurant({
    required this.nomRestaurant,
    required this.ville,
    required this.erreurNom,
    required this.erreurVille,
    required this.enCours,
    required this.onNomChange,
    required this.onVilleChange,
    required this.onPublier,
  });

  final TextEditingController nomRestaurant;
  final TextEditingController ville;
  final String? erreurNom;
  final String? erreurVille;
  final bool enCours;
  final VoidCallback onNomChange;
  final VoidCallback onVilleChange;
  final VoidCallback onPublier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Racontez le souvenir.', style: TablTokens.grandTitre),
        const SizedBox(height: TablTokens.espaceXl),
        TablChampTexte(
          libelle: 'Restaurant',
          controleur: nomRestaurant,
          indication: 'Le Comptoir',
          erreur: erreurNom,
          actif: !enCours,
          onChanged: (_) => onNomChange(),
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablChampTexte(
          libelle: 'Ville',
          controleur: ville,
          indication: 'Paris',
          erreur: erreurVille,
          actif: !enCours,
          onChanged: (_) => onVilleChange(),
        ),
        const Spacer(),
        TablBouton(
          libelle: 'Publier ce souvenir',
          enCours: enCours,
          onPresse: onPublier,
        ),
      ],
    );
  }
}
