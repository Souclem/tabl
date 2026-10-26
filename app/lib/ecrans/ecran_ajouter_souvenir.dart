import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'feuille_audience.dart';
import 'recherche_lieu_en_direct.dart';

/// Ajouter un souvenir à la main : un repas passé, avec ou sans photo.
/// Le restaurant, le mois et l'année suffisent ; photos, ressenti,
/// quelques mots et le moment s'ajoutent si on veut. Se ferme sur `true`
/// une fois le souvenir ajouté.
class EcranAjouterSouvenir extends StatefulWidget {
  const EcranAjouterSouvenir({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.choisirPhotos,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;
  final TableService? tableService;

  /// `null` : seulement la saisie à la main (nom + ville).
  final RechercheLieuService? rechercheLieuService;

  /// `null` : suggestions non triées par proximité.
  final PositionService? positionService;

  /// Choisit au plus `restant` photos dans la photothèque ; `null` : le
  /// sélecteur d'iOS / Android.
  final Future<List<Uint8List>> Function(int restant)? choisirPhotos;

  @override
  State<EcranAjouterSouvenir> createState() => _EcranAjouterSouvenirState();
}

class _EcranAjouterSouvenirState extends State<EcranAjouterSouvenir>
    with RechercheLieuEnDirect<EcranAjouterSouvenir> {
  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  @override
  PositionService? get positionService => widget.positionService;

  late bool _saisieManuelle = widget.rechercheLieuService == null;
  final _nomRestaurant = TextEditingController();
  final _ville = TextEditingController();
  String? _erreurNom;
  String? _erreurVille;

  LieuRestaurant? _lieu;
  DateSouvenir? _date;
  final List<Uint8List> _photos = [];
  Emotion? _emotion;
  final _legende = TextEditingController();
  String? _moment;
  AudienceSouvenir _audience = AudienceSouvenir.toutLeMonde;

  // Les rubriques facultatives ouvertes (« + Ressenti »…).
  bool _ressentiOuvert = false;
  bool _motsOuverts = false;
  bool _momentOuvert = false;

  bool _enCours = false;

  late final Future<DonneesAudience> _futurAudience = chargerDonneesAudience(
    widget.abonnementService,
    widget.tableService,
  );

  @override
  void dispose() {
    _nomRestaurant.dispose();
    _ville.dispose();
    _legende.dispose();
    super.dispose();
  }

  void _choisirLieu(LieuRestaurant lieu) {
    FocusScope.of(context).unfocus();
    setState(() => _lieu = lieu);
  }

  void _changerLieu() => setState(() => _lieu = null);

  void _passerEnSaisieManuelle() {
    setState(() {
      _saisieManuelle = true;
      if (_nomRestaurant.text.isEmpty) _nomRestaurant.text = recherche.text;
    });
  }

  void _validerLieuManuel() {
    final erreurNom = ValidationSouvenir.nomRestaurant(_nomRestaurant.text);
    final erreurVille = ValidationSouvenir.ville(_ville.text);
    setState(() {
      _erreurNom = erreurNom;
      _erreurVille = erreurVille;
    });
    if (erreurNom != null || erreurVille != null) return;
    // Sans position : on n'est plus au restaurant, celle du téléphone
    // le placerait au mauvais endroit sur la carte.
    _choisirLieu(
      LieuRestaurant.manuel(
        nom: _nomRestaurant.text.trim(),
        ville: _ville.text.trim(),
      ),
    );
  }

  Future<void> _choisirDate() async {
    final maintenant = DateTime.now();
    final choisie = await showModalBottomSheet<DateSouvenir>(
      context: context,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (_) => _FeuilleDate(
        initiale:
            _date ??
            DateSouvenir(annee: maintenant.year, mois: maintenant.month),
        maintenant: maintenant,
      ),
    );
    if (choisie != null && mounted) setState(() => _date = choisie);
  }

  Future<void> _ajouterPhotos() async {
    final restant = nombreMaxPhotosSouvenir - _photos.length;
    if (restant <= 0) return;
    try {
      final choisies = await (widget.choisirPhotos ?? _photosDuTelephone)(
        restant,
      );
      if (!mounted || choisies.isEmpty) return;
      setState(() => _photos.addAll(choisies.take(restant)));
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: photos : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  static Future<List<Uint8List>> _photosDuTelephone(int restant) async {
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
    return [for (final f in fichiers) await f.readAsBytes()];
  }

  void _choisirPrincipale(int index) {
    if (index == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _photos.insert(0, _photos.removeAt(index)));
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
          photos: List.of(_photos),
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
    final date = _date;
    final lieu = _lieu;
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: TablBoutonRetour(
                  onPresse: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  TablTokens.espaceL,
                  TablTokens.espaceM,
                  TablTokens.espaceL,
                  TablTokens.espaceL,
                ),
                children: [
                  const _Surtitre(texte: 'Souvenir'),
                  const SizedBox(height: TablTokens.espaceS),
                  Text('Ajouter un souvenir', style: TablTokens.grandTitre),
                  const SizedBox(height: TablTokens.espaceL),
                  if (lieu != null)
                    _LieuChoisi(lieu: lieu, onChanger: _changerLieu)
                  else if (_saisieManuelle)
                    _LieuManuel(
                      nom: _nomRestaurant,
                      ville: _ville,
                      erreurNom: _erreurNom,
                      erreurVille: _erreurVille,
                      onValider: _validerLieuManuel,
                    )
                  else
                    _RechercheLieu(
                      recherche: recherche,
                      suggestions: suggestions,
                      enCours: rechercheEnCours,
                      onChange: rechercherAvecAttente,
                      onChoisir: _choisirLieu,
                      onIntrouvable: _passerEnSaisieManuelle,
                    ),
                  const SizedBox(height: TablTokens.espaceL),
                  Text('Quand ?', style: TablTokens.legende),
                  const SizedBox(height: TablTokens.espaceS),
                  Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: TablCaseDate(
                          texte: date == null
                              ? 'Mois'
                              : majuscule(nomDuMois(date.mois)),
                          vide: date == null,
                          onPresse: _choisirDate,
                        ),
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                      Expanded(
                        flex: 3,
                        child: TablCaseDate(
                          texte: date == null ? 'Année' : '${date.annee}',
                          vide: date == null,
                          onPresse: _choisirDate,
                        ),
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                      Expanded(
                        flex: 4,
                        child: TablCaseDate(
                          texte: date?.jour == null
                              ? 'Jour · facultatif'
                              : '${date!.jour}',
                          vide: date?.jour == null,
                          onPresse: _choisirDate,
                        ),
                      ),
                    ],
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: TablTokens.espaceL),
                    TablPhotosSouvenir(
                      photos: _photos,
                      libelle:
                          '${pluriel(_photos.length, 'photo')} '
                          'sur $nombreMaxPhotosSouvenir',
                      onChoisirPrincipale: _choisirPrincipale,
                      onRetirer: (i) => setState(() => _photos.removeAt(i)),
                      onAjouter: _photos.length < nombreMaxPhotosSouvenir
                          ? _ajouterPhotos
                          : null,
                    ),
                  ],
                  if (_ressentiOuvert) ...[
                    const SizedBox(height: TablTokens.espaceL),
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
                  ],
                  if (_motsOuverts) ...[
                    const SizedBox(height: TablTokens.espaceL),
                    TablChampTexte(
                      libelle: 'Quelques mots',
                      controleur: _legende,
                      indication: 'Ce que vous voulez vous rappeler',
                      lignes: 2,
                    ),
                  ],
                  if (_momentOuvert) ...[
                    const SizedBox(height: TablTokens.espaceL),
                    Text('Moment', style: TablTokens.legende),
                    const SizedBox(height: TablTokens.espaceS),
                    Wrap(
                      spacing: TablTokens.espaceS,
                      children: [
                        for (final m in const ['midi', 'soir'])
                          TablPuceSelection(
                            libelle: libelleMomentRepas(m)!,
                            selectionnee: _moment == m,
                            onBascule: () => setState(
                              () => _moment = _moment == m ? null : m,
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: TablTokens.espaceL),
                  Wrap(
                    spacing: TablTokens.espaceS,
                    runSpacing: TablTokens.espaceS,
                    children: [
                      if (_photos.isEmpty)
                        TablPuceSelection(
                          libelle: '+ Photos',
                          selectionnee: false,
                          onBascule: _ajouterPhotos,
                        ),
                      if (!_ressentiOuvert)
                        TablPuceSelection(
                          libelle: '+ Ressenti',
                          selectionnee: false,
                          onBascule: () =>
                              setState(() => _ressentiOuvert = true),
                        ),
                      if (!_motsOuverts)
                        TablPuceSelection(
                          libelle: '+ Mots',
                          selectionnee: false,
                          onBascule: () => setState(() => _motsOuverts = true),
                        ),
                      if (!_momentOuvert)
                        TablPuceSelection(
                          libelle: '+ Moment',
                          selectionnee: false,
                          onBascule: () => setState(() => _momentOuvert = true),
                        ),
                    ],
                  ),
                  const SizedBox(height: TablTokens.espaceL),
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
                                in donnees?.relations ?? const <ProfilPublic>[])
                              r.id: r.pseudo,
                          },
                        ),
                        restreinte: _audience.mode != ModeAudience.toutLeMonde,
                        onPresse: _choisirAudience,
                      );
                    },
                  ),
                  const SizedBox(height: TablTokens.espaceS),
                  Row(
                    children: [
                      const Icon(
                        Icons.nightlight_round,
                        size: 14,
                        color: TablTokens.texteDoux,
                      ),
                      const SizedBox(width: TablTokens.espaceS),
                      Expanded(
                        child: Text(
                          'Visible sur votre profil, jamais dans le Feed.',
                          style: TablTokens.legende,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                TablTokens.espaceL,
                TablTokens.espaceS,
                TablTokens.espaceL,
                TablTokens.espaceM,
              ),
              child: TablBouton(
                libelle: 'Ajouter à mon profil',
                enCours: _enCours,
                onPresse: lieu != null && date != null ? _ajouter : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// « ☾ SOUVENIR » au-dessus du titre.
class _Surtitre extends StatelessWidget {
  const _Surtitre({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.nightlight_round, size: 14, color: TablTokens.texte),
        const SizedBox(width: 6),
        Text(
          texte.toUpperCase(),
          style: TablTokens.legende.copyWith(
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: TablTokens.texte,
          ),
        ),
      ],
    );
  }
}

class _RechercheLieu extends StatelessWidget {
  const _RechercheLieu({
    required this.recherche,
    required this.suggestions,
    required this.enCours,
    required this.onChange,
    required this.onChoisir,
    required this.onIntrouvable,
  });

  final TextEditingController recherche;
  final List<LieuRestaurant> suggestions;
  final bool enCours;
  final ValueChanged<String> onChange;
  final ValueChanged<LieuRestaurant> onChoisir;
  final VoidCallback onIntrouvable;

  @override
  Widget build(BuildContext context) {
    final aCherche = recherche.text.trim().length >= 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TablChampTexte(
          libelle: 'Restaurant',
          controleur: recherche,
          indication: 'Le Campus, ¡Toma!…',
          iconePrefixe: Icons.search_rounded,
          onChanged: onChange,
        ),
        if (enCours)
          const LinearProgressIndicator(
            minHeight: 2,
            color: TablTokens.primaire,
            backgroundColor: Colors.transparent,
          ),
        for (final lieu in suggestions.take(6))
          TablLigneSuggestionLieu(
            nom: lieu.nom,
            description: lieu.description,
            onSelection: () => onChoisir(lieu),
          ),
        if (aCherche && !enCours && suggestions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TablTokens.espaceM),
            child: Text('Aucun restaurant trouvé.', style: TablTokens.legende),
          ),
        if (aCherche)
          TablBoutonTexte(
            libelle: 'Je ne trouve pas mon restaurant',
            onPresse: onIntrouvable,
          ),
      ],
    );
  }
}

class _LieuManuel extends StatelessWidget {
  const _LieuManuel({
    required this.nom,
    required this.ville,
    required this.erreurNom,
    required this.erreurVille,
    required this.onValider,
  });

  final TextEditingController nom;
  final TextEditingController ville;
  final String? erreurNom;
  final String? erreurVille;
  final VoidCallback onValider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TablChampTexte(
          libelle: 'Restaurant',
          controleur: nom,
          indication: 'Le Comptoir',
          erreur: erreurNom,
        ),
        const SizedBox(height: TablTokens.espaceM),
        TablChampTexte(
          libelle: 'Ville',
          controleur: ville,
          indication: 'Paris',
          erreur: erreurVille,
          actionClavier: TextInputAction.done,
          onSoumis: (_) => onValider(),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TablBoutonTexte(libelle: 'Valider', onPresse: onValider),
        ),
      ],
    );
  }
}

class _LieuChoisi extends StatelessWidget {
  const _LieuChoisi({required this.lieu, required this.onChanger});

  final LieuRestaurant lieu;
  final VoidCallback onChanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceM,
        TablTokens.espaceS,
        TablTokens.espaceXs,
        TablTokens.espaceS,
      ),
      decoration: BoxDecoration(
        color: TablTokens.surfaceBasse,
        borderRadius: BorderRadius.circular(TablTokens.arrondiM),
        border: Border.all(color: TablTokens.bordure),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lieu.nom, style: TablTokens.sousTitre),
                if (lieu.description.isNotEmpty)
                  Text(lieu.description, style: TablTokens.legende),
              ],
            ),
          ),
          TablBoutonTexte(libelle: 'Changer', onPresse: onChanger),
        ],
      ),
    );
  }
}

/// Les roues du « Quand ? » : mois et année, le jour si on s'en
/// souvient. « Valider » reste éteint sur une date pas encore passée.
class _FeuilleDate extends StatefulWidget {
  const _FeuilleDate({required this.initiale, required this.maintenant});

  final DateSouvenir initiale;
  final DateTime maintenant;

  @override
  State<_FeuilleDate> createState() => _FeuilleDateState();
}

class _FeuilleDateState extends State<_FeuilleDate> {
  late DateSouvenir _date = widget.initiale;
  late final List<int> _annees = anneesSouvenir(widget.maintenant);

  @override
  Widget build(BuildContext context) {
    final futur = _date.estDansLeFutur(widget.maintenant);
    final jours = joursDansLeMois(_date.annee, _date.mois);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TablTokens.espaceL,
          0,
          TablTokens.espaceL,
          TablTokens.espaceM,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quand ?', style: TablTokens.titre),
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
              indexAnnee: _annees.indexOf(_date.annee),
              onAnnee: (i) =>
                  setState(() => _date = _date.copierAvec(annee: _annees[i])),
            ),
            SizedBox(
              height: 24,
              child: futur
                  ? Text(
                      'Cette date n\'est pas encore passée.',
                      textAlign: TextAlign.center,
                      style: TablTokens.legende.copyWith(
                        color: TablTokens.erreur,
                      ),
                    )
                  : null,
            ),
            TablBouton(
              libelle: 'Valider',
              onPresse: futur ? null : () => Navigator.of(context).pop(_date),
            ),
          ],
        ),
      ),
    );
  }
}
