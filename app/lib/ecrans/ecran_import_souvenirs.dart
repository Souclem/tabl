import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'ecran_ajouter_souvenir.dart';
import 'feuille_choix_restaurant.dart';

/// « Ajouter plusieurs de manière intelligente » : on choisit les photos
/// de plusieurs repas, Tabl les range en repas (d'après leur date et
/// leur position, jamais leur contenu) et propose pour chacun le
/// restaurant le plus proche. On vérifie repas par repas — rien n'entre
/// dans le profil sans accord —, puis un bilan. Les photos déjà rangées
/// dans un souvenir sont ignorées. Se ferme sur le nombre de souvenirs
/// ajoutés.
class EcranImportSouvenirs extends StatefulWidget {
  const EcranImportSouvenirs({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.tableService,
    this.rechercheLieuService,
    this.positionService,
    this.choisirPhotos = photosDuTelephone,
  });

  final SouvenirService souvenirService;
  final AbonnementService abonnementService;
  final TableService? tableService;
  final RechercheLieuService? rechercheLieuService;
  final PositionService? positionService;
  final ChoisirPhotos choisirPhotos;

  @override
  State<EcranImportSouvenirs> createState() => _EcranImportSouvenirsState();
}

enum _Etape { accueil, lecture, revue, rien, bilan }

/// Un repas retrouvé, et ce qu'on en sait au fil de la revue.
class _Repas {
  _Repas(this.photos);

  List<PhotoChoisie> photos;
  Precompletion suggestion = Precompletion.rien;
  List<Coordonnees> endroits = const [];
  List<List<LieuRestaurant>> proches = const [];
  LieuRestaurant? lieu;

  /// Choisi par l'utilisateur : plus jamais remplacé par une proposition.
  bool lieuChoisi = false;
  bool rechercheEnCours = false;
  bool ajoute = false;
}

class _EcranImportSouvenirsState extends State<EcranImportSouvenirs> {
  _Etape _etape = _Etape.accueil;

  /// Pendant la lecture : combien de photos lues, sur combien.
  int _lues = 0;
  int _total = 0;

  List<_Repas> _repas = [];
  int _dejaImportees = 0;
  int _inexploitables = 0;
  final List<({LieuRestaurant lieu, DateSouvenir date})> _ajoutes = [];

  /// Les photos déjà rangées dans des souvenirs, demandées dès
  /// l'ouverture : elles arrivent pendant qu'on choisit.
  late Future<Set<String>> _empreintes = _chargerEmpreintes();

  Future<Set<String>> _chargerEmpreintes() async {
    try {
      return await widget.souvenirService.empreintesImportees();
    } catch (e) {
      // Sans elles, on importe quand même : au pire, un doublon.
      debugPrint('EcranImportSouvenirs: empreintes : $e');
      return const {};
    }
  }

  Future<void> _choisirPhotos() async {
    setState(() {
      _etape = _Etape.lecture;
      _lues = 0;
      _total = 0;
    });
    final List<Uint8List> octets;
    try {
      octets = await widget.choisirPhotos(nombreMaxPhotosImport);
    } catch (e) {
      debugPrint('EcranImportSouvenirs: photos : $e');
      if (!mounted) return;
      setState(() => _etape = _Etape.accueil);
      afficherMessage(context, messageErreurGenerique);
      return;
    }
    if (!mounted) return;
    if (octets.isEmpty) {
      setState(() => _etape = _Etape.accueil);
      return;
    }

    setState(() => _total = octets.length);
    final photos = <PhotoChoisie>[];
    for (final o in octets) {
      photos.add((octets: o, metadonnees: await lireMetadonnees(o)));
      if (!mounted) return;
      setState(() => _lues = photos.length);
    }
    final rangement = rangerEnRepas(photos, empreintes: await _empreintes);
    if (!mounted) return;
    setState(() {
      _repas = [for (final r in rangement.repas) _Repas(r)];
      _dejaImportees = rangement.dejaImportees;
      _inexploitables = rangement.inexploitables;
      _etape = _repas.isEmpty ? _Etape.rien : _Etape.revue;
    });
    for (final r in _repas) {
      _completer(r);
    }
  }

  /// Ce que les photos d'un repas disent (jour, moment, endroits), et le
  /// restaurant le plus proche, sauf s'il a été choisi.
  Future<void> _completer(_Repas repas) async {
    final suggestion = precompleter([
      for (final p in repas.photos) p.metadonnees,
    ], maintenant: DateTime.now());
    final position = suggestion.position;
    final endroits = [?position, ...suggestion.autresEndroits.take(2)];
    setState(() {
      repas.suggestion = suggestion;
      repas.endroits = endroits;
    });
    final service = widget.rechercheLieuService;
    if (service == null || endroits.isEmpty) {
      setState(() => repas.proches = const []);
      return;
    }
    setState(() => repas.rechercheEnCours = true);
    try {
      final proches = await Future.wait([
        for (var i = 0; i < endroits.length; i++)
          service.lieuxProches(
            latitude: endroits[i].latitude,
            longitude: endroits[i].longitude,
            limite: i == 0 ? 8 : 4,
          ),
      ]);
      if (!mounted || !identical(repas.endroits, endroits)) return;
      setState(() {
        repas.proches = proches;
        if (!repas.lieuChoisi) repas.lieu = proches.first.firstOrNull;
      });
    } catch (e) {
      debugPrint('EcranImportSouvenirs: lieux proches : $e');
    } finally {
      if (mounted) setState(() => repas.rechercheEnCours = false);
    }
  }

  Future<void> _changerLieu(_Repas repas) async {
    final choisi = await choisirRestaurant(
      context,
      rechercheLieuService: widget.rechercheLieuService,
      positionService: widget.positionService,
      endroits: repas.endroits,
      prochesParEndroit: repas.proches,
      choisi: repas.lieu,
    );
    if (choisi == null || !mounted) return;
    setState(() {
      repas.lieu = choisi;
      repas.lieuChoisi = true;
    });
  }

  /// Ce qu'on peut faire d'une photo d'un repas : la retirer, la passer
  /// au repas d'à côté, ou en faire un repas à part.
  Future<void> _toucherPhoto(_Repas repas, int index) async {
    final rang = _repas.indexOf(repas);
    final precedent = rang > 0 ? _repas[rang - 1] : null;
    final suivant = rang < _repas.length - 1 ? _repas[rang + 1] : null;
    final choix = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TablTokens.surface,
      showDragHandle: true,
      builder: (contexte) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(TablTokens.arrondiM),
              child: Image.memory(
                repas.photos[index].octets,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: TablTokens.espaceS),
            if (precedent != null && !precedent.ajoute)
              _choix(
                contexte,
                'precedent',
                Icons.arrow_upward_rounded,
                'Avec le repas d\'avant',
              ),
            if (suivant != null && !suivant.ajoute)
              _choix(
                contexte,
                'suivant',
                Icons.arrow_downward_rounded,
                'Avec le repas d\'après',
              ),
            if (repas.photos.length > 1)
              _choix(
                contexte,
                'apart',
                Icons.call_split_rounded,
                'En faire un repas à part',
              ),
            _choix(
              contexte,
              'retirer',
              Icons.remove_circle_outline_rounded,
              'Retirer cette photo',
            ),
          ],
        ),
      ),
    );
    if (choix == null || !mounted) return;
    final photo = repas.photos[index];
    final touches = <_Repas>{repas};
    setState(() {
      repas.photos = [...repas.photos]..removeAt(index);
      switch (choix) {
        case 'precedent':
          precedent!.photos = _parHeure([...precedent.photos, photo]);
          touches.add(precedent);
        case 'suivant':
          suivant!.photos = _parHeure([...suivant.photos, photo]);
          touches.add(suivant);
        case 'apart':
          final nouveau = _Repas([photo]);
          _repas.insert(rang + 1, nouveau);
          touches.add(nouveau);
      }
      _repas.removeWhere((r) => r.photos.isEmpty);
    });
    for (final r in touches) {
      if (_repas.contains(r)) _completer(r);
    }
  }

  Widget _choix(
    BuildContext contexte,
    String valeur,
    IconData icone,
    String libelle,
  ) => ListTile(
    leading: Icon(icone, color: TablTokens.texte),
    title: Text(libelle, style: TablTokens.corps),
    onTap: () => Navigator.of(contexte).pop(valeur),
  );

  static List<PhotoChoisie> _parHeure(List<PhotoChoisie> photos) {
    final sansDate = DateTime(9999);
    return photos..sort(
      (a, b) => (a.metadonnees.prisLe ?? sansDate).compareTo(
        b.metadonnees.prisLe ?? sansDate,
      ),
    );
  }

  /// La suite : jour, moment, ressenti, mots, audience — sur l'écran
  /// d'un souvenir, déjà rempli.
  Future<void> _ajouter(_Repas repas) async {
    final ajoute = await Navigator.of(context).push<NouveauSouvenir>(
      MaterialPageRoute(
        builder: (_) => EcranAjouterSouvenir(
          souvenirService: widget.souvenirService,
          abonnementService: widget.abonnementService,
          photos: repas.photos,
          lieuPropose: repas.lieu,
          tableService: widget.tableService,
          rechercheLieuService: widget.rechercheLieuService,
          positionService: widget.positionService,
          choisirPhotos: widget.choisirPhotos,
        ),
      ),
    );
    if (ajoute == null || !mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      repas.ajoute = true;
      repas.lieu = ajoute.lieu;
      _ajoutes.add((lieu: ajoute.lieu, date: ajoute.date));
    });
  }

  void _ignorer(_Repas repas) => setState(() => _repas.remove(repas));

  bool get _resteAVerifier => _repas.any((r) => !r.ajoute);

  /// Quitter en pleine revue : ce qui est ajouté reste, le reste est
  /// abandonné — on le dit avant.
  Future<void> _quitter() async {
    if (_etape == _Etape.revue && _resteAVerifier) {
      final quitter = await showDialog<bool>(
        context: context,
        builder: (contexte) => AlertDialog(
          backgroundColor: TablTokens.surface,
          title: const Text('Quitter l\'importation ?'),
          content: const Text(
            'Vos souvenirs ajoutés sont conservés ; les autres repas seront '
            'abandonnés.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(contexte).pop(false),
              child: const Text('Continuer la revue'),
            ),
            TextButton(
              onPressed: () => Navigator.of(contexte).pop(true),
              child: const Text('Quitter'),
            ),
          ],
        ),
      );
      if (quitter != true || !mounted) return;
    }
    Navigator.of(context).pop(_ajoutes.length);
  }

  void _terminer() {
    if (_ajoutes.isEmpty) {
      Navigator.of(context).pop(0);
      return;
    }
    setState(() => _etape = _Etape.bilan);
  }

  void _recommencer() {
    setState(() {
      _etape = _Etape.accueil;
      _repas = [];
      _empreintes = _chargerEmpreintes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (aQuitte, _) {
        if (!aQuitte) _quitter();
      },
      child: Scaffold(
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
                    TablBoutonVerre(
                      icone: _etape == _Etape.accueil
                          ? Icons.arrow_back_rounded
                          : Icons.close_rounded,
                      libelle: 'Fermer',
                      onPresse: _quitter,
                    ),
                    const Spacer(),
                    if (_etape == _Etape.revue)
                      // « repas » ne prend pas de s.
                      Text('${_repas.length} repas', style: TablTokens.legende),
                  ],
                ),
              ),
              Expanded(
                child: switch (_etape) {
                  _Etape.accueil => _accueil(),
                  _Etape.lecture => _lecture(),
                  _Etape.revue => _revue(),
                  _Etape.rien => _rien(),
                  _Etape.bilan => _bilan(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titre(String surtitre, String titre, {String? texte}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TablSurtitreSouvenir(texte: surtitre),
      const SizedBox(height: TablTokens.espaceS),
      Text(
        titre,
        style: TablTokens.titreAffichage.copyWith(fontSize: 30, height: 1.15),
      ),
      if (texte != null) ...[
        const SizedBox(height: TablTokens.espaceS),
        Text(texte, style: TablTokens.legende.copyWith(fontSize: 14)),
      ],
    ],
  );

  Widget _accueil() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
        TablTokens.espaceL - 4,
        TablTokens.espaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titre(
            'Importer des photos',
            'Trois temps, et rien sans votre accord.',
          ),
          const SizedBox(height: TablTokens.espaceL),
          const TablEtapesImport(
            etapes: [
              (
                icone: Icons.photo_library_outlined,
                titre: 'Vous choisissez des photos',
                texte:
                    'Celles de vos repas, jusqu\'à $nombreMaxPhotosImport à la '
                    'fois, dans le sélecteur du téléphone.',
              ),
              (
                icone: Icons.place_outlined,
                titre: 'Tabl les range en repas',
                texte:
                    'D\'après leur date, leur heure et leur position '
                    'seulement. Le contenu des images n\'est pas analysé.',
              ),
              (
                icone: Icons.check_rounded,
                titre: 'Vous vérifiez',
                texte:
                    'Rien n\'entre dans votre profil sans votre accord, '
                    'repas par repas.',
              ),
            ],
          ),
          const Spacer(),
          TablBouton(libelle: 'Choisir des photos', onPresse: _choisirPhotos),
          const SizedBox(height: TablTokens.espaceS),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 13,
                color: TablTokens.texteDoux,
              ),
              const SizedBox(width: 6),
              Text(
                'Les photos déjà importées seront ignorées.',
                style: TablTokens.legende.copyWith(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lecture() {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceL - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Lecture de vos photos',
            textAlign: TextAlign.center,
            style: TablTokens.titreAffichage.copyWith(fontSize: 28),
          ),
          const SizedBox(height: TablTokens.espaceL),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 3,
              value: _total == 0 ? null : _lues / _total,
              color: TablTokens.texte,
              backgroundColor: TablTokens.surface,
            ),
          ),
          const SizedBox(height: TablTokens.espaceM),
          Text(
            _total == 0
                ? 'Préparation de vos photos…'
                : '$_lues photos lues sur $_total',
            textAlign: TextAlign.center,
            style: TablTokens.legende,
          ),
        ],
      ),
    );
  }

  Widget _revue() {
    final mentions = [
      if (_dejaImportees > 0)
        _dejaImportees == 1
            ? '1 photo déjà importée a été ignorée.'
            : '$_dejaImportees photos déjà importées ont été ignorées.',
      if (_inexploitables > 0)
        _inexploitables == 1
            ? '1 photo sans date ni lieu utilisable a été laissée de côté.'
            : '$_inexploitables photos sans date ni lieu utilisables ont été '
                  'laissées de côté.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TablTokens.espaceL - 4,
              TablTokens.espaceM,
              TablTokens.espaceL - 4,
              TablTokens.espaceL,
            ),
            children: [
              _titre(
                'Souvenirs · d\'après vos photos',
                'Repas retrouvés',
                texte:
                    'Un repas par carte. Vérifiez le restaurant, puis '
                    'ajoutez-le ; touchez une photo pour la déplacer.',
              ),
              const SizedBox(height: TablTokens.espaceL),
              for (final r in _repas) ...[
                TablCarteRepas(
                  key: ObjectKey(r),
                  quand: _quand(r),
                  photos: [for (final p in r.photos) p.octets],
                  mention: mentionSansPosition(r.photos),
                  nomLieu: r.lieu?.nom,
                  detailLieu: r.lieu != null
                      ? detailLieuSouvenir(
                          r.lieu!,
                          depuisLaPhoto: r.endroits.isNotEmpty,
                        )
                      : r.rechercheEnCours
                      ? 'Recherche du restaurant…'
                      : r.endroits.isEmpty
                      ? 'Ces photos n\'ont pas de position.'
                      : 'Aucun restaurant trouvé près de ces photos.',
                  ajoute: r.ajoute,
                  onToucherPhoto: (i) => _toucherPhoto(r, i),
                  onChangerLieu: () => _changerLieu(r),
                  onAjouter: r.lieu == null ? null : () => _ajouter(r),
                  onIgnorer: () => _ignorer(r),
                ),
                const SizedBox(height: TablTokens.espaceM),
              ],
              for (final m in mentions)
                Padding(
                  padding: const EdgeInsets.only(top: TablTokens.espaceXs),
                  child: Text(
                    m,
                    textAlign: TextAlign.center,
                    style: TablTokens.legende.copyWith(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TablTokens.espaceL - 4,
            TablTokens.espaceS,
            TablTokens.espaceL - 4,
            TablTokens.espaceM,
          ),
          child: TablBouton(
            libelle: _ajoutes.isEmpty
                ? 'Terminer'
                : 'Terminer · ${pluriel(_ajoutes.length, 'souvenir')}',
            onPresse: _terminer,
          ),
        ),
      ],
    );
  }

  /// "3 novembre 2023 · Dîner", ou "Date inconnue".
  String _quand(_Repas r) {
    final date = r.suggestion.date;
    if (date == null) return 'Date inconnue';
    return [
      date.libelle,
      ?libelleMomentRepas(r.suggestion.moment ?? ''),
    ].join(' · ');
  }

  Widget _rien() {
    return Padding(
      padding: const EdgeInsets.all(TablTokens.espaceL - 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(child: TablPileDePhotos(hauteur: 90)),
          const SizedBox(height: TablTokens.espaceL),
          Text(
            'Aucun repas retrouvé',
            textAlign: TextAlign.center,
            style: TablTokens.titreAffichage.copyWith(fontSize: 28),
          ),
          const SizedBox(height: TablTokens.espaceS),
          Text(
            _dejaImportees > 0 && _inexploitables == 0
                ? 'Ces photos sont déjà dans vos souvenirs.'
                : 'Ces photos n\'ont ni date ni position utilisables. Elles '
                      'restent sur votre téléphone, rien n\'a été ajouté.',
            textAlign: TextAlign.center,
            style: TablTokens.legende.copyWith(fontSize: 14),
          ),
          const Spacer(),
          TablBouton(
            libelle: 'Choisir d\'autres photos',
            onPresse: _recommencer,
          ),
        ],
      ),
    );
  }

  Widget _bilan() {
    final bilan = bilanImport(_ajoutes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
        TablTokens.espaceL - 4,
        TablTokens.espaceM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titre('Votre bilan · privé', 'Vos souvenirs ont trouvé leur place.'),
          const SizedBox(height: TablTokens.espaceXl),
          TablBilanImport(
            chiffres: [
              (
                nombre: '${bilan.souvenirs}',
                libelle: bilan.souvenirs == 1
                    ? 'souvenir ajouté'
                    : 'souvenirs ajoutés',
              ),
              (
                nombre: '${bilan.restaurants}',
                libelle: bilan.restaurants == 1 ? 'restaurant' : 'restaurants',
              ),
            ],
            periode: bilan.periode,
          ),
          const Spacer(),
          TablBouton(
            libelle: 'Voir mes souvenirs',
            onPresse: () => Navigator.of(context).pop(_ajoutes.length),
          ),
          const SizedBox(height: TablTokens.espaceS),
          TablBoutonTexte(
            libelle: 'Importer d\'autres photos',
            onPresse: _recommencer,
          ),
        ],
      ),
    );
  }
}
