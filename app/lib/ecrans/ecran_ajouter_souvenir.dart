import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'creation_moment.dart';
import 'feuille_audience.dart';

/// Ajouter un souvenir : un repas passé, tel qu'il apparaîtra sur le
/// profil. Les photos en grand d'abord — il en faut au moins une ;
/// d'elles, Tabl déduit le restaurant le plus proche, le jour et le
/// moment, des propositions toutes modifiables. Se ferme sur le
/// [NouveauSouvenir] ajouté (`null` : fermé sans rien ajouter).
class EcranAjouterSouvenir extends StatefulWidget {
  const EcranAjouterSouvenir({
    super.key,
    required this.souvenirService,
    required this.abonnementService,
    this.photos = const [],
    this.lieuPropose,
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

  /// Déjà choisi (dans la revue d'un import) : proposé tel quel, à la
  /// place du plus proche.
  final LieuRestaurant? lieuPropose;
  final TableService? tableService;

  /// `null` : ni lieu proposé, ni recherche (saisie à la main).
  final RechercheLieuService? rechercheLieuService;

  /// Sans photo localisée : la recherche est triée autour du téléphone.
  final PositionService? positionService;
  final ChoisirPhotos choisirPhotos;

  @override
  State<EcranAjouterSouvenir> createState() => _EcranAjouterSouvenirState();
}

class _EcranAjouterSouvenirState extends State<EcranAjouterSouvenir>
    with
        EditionPhotos<EcranAjouterSouvenir>,
        PropositionLieu<EcranAjouterSouvenir> {
  @override
  List<PhotoChoisie> get photosInitiales => widget.photos;

  @override
  RechercheLieuService? get rechercheLieuService => widget.rechercheLieuService;

  @override
  PositionService? get positionService => widget.positionService;

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
    final propose = widget.lieuPropose;
    if (propose != null) {
      lieu = propose;
      lieuChoisi = true;
    }
    _completerDepuisPhotos();
  }

  @override
  void dispose() {
    _legende.dispose();
    super.dispose();
  }

  @override
  void photosAjoutees() => _completerDepuisPhotos();

  /// Ce que les photos disent, pour ce qui n'est pas encore choisi :
  /// jamais par-dessus un choix de l'utilisateur.
  void _completerDepuisPhotos() {
    final suggestion = precompleter([
      for (final p in photos) p.metadonnees,
    ], maintenant: DateTime.now());
    if (_date == null && suggestion.date != null) {
      _date = suggestion.date;
      _moment = suggestion.moment;
      _heurePhotos = suggestion.premierePhoto;
    }
    final position = suggestion.position;
    if (position != null && endroits.isEmpty) {
      // Au plus deux autres endroits : au-delà, ce sont sans doute
      // d'autres repas (l'import de plusieurs souvenirs s'en chargera).
      chercherAutour([
        position,
        ...suggestion.autresEndroits.take(2),
      ], repere: RepereDistance.photo);
    }
  }

  Future<void> _ajouterPhotos() async {
    try {
      await ajouterPhotos(await widget.choisirPhotos(placesRestantes));
    } catch (e) {
      debugPrint('EcranAjouterSouvenir: photos : $e');
      if (mounted) afficherMessage(context, messageErreurGenerique);
    }
  }

  Future<void> _choisirQuand() async {
    final maintenant = DateTime.now();
    final choisi =
        await showModalBottomSheet<({DateSouvenir date, String? moment})>(
          context: context,
          backgroundColor: TablCouleurs.of(context).surface,
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
    final lieu = this.lieu;
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
      final souvenir = NouveauSouvenir(
        lieu: lieu,
        date: date,
        photos: [for (final p in photos) p.octets],
        emotion: _emotion,
        legende: legende.isEmpty ? null : legende,
        moment: _moment,
        audience: _audience,
        empreintes: [for (final p in photos) ?p.metadonnees.empreinte],
      );
      final tablesEnEchec = await widget.souvenirService.ajouterSouvenir(
        souvenir,
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
      Navigator.of(context).pop(souvenir);
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
    final c = TablCouleurs.of(context);
    final lieu = this.lieu;
    final date = _date;
    final heurePhotos = _heurePhotos;

    return Scaffold(
      backgroundColor: c.fond,
      body: Stack(
        children: [
          SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                zonePhotos(
                  context,
                  actions: [
                    (
                      icone: Icons.photo_library_outlined,
                      libelle: 'Ajouter des photos',
                      onPresse: _ajouterPhotos,
                    ),
                  ],
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
                        texte: endroits.isNotEmpty || heurePhotos != null
                            ? 'Souvenir · d\'après vos photos'
                            : 'Souvenir',
                      ),
                      const SizedBox(height: 10),
                      TablTitreLieuSouvenir(
                        nom: lieu?.nom,
                        detail: detailLieu,
                        indication: 'Quel restaurant ?',
                        action: lieu == null ? 'Choisir' : 'Changer',
                        onPresse: changerLieu,
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      TablLigneOption(
                        icone: Icons.event_outlined,
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
                        indication: 'Quelques mots, si vous le souhaitez',
                      ),
                      const SizedBox(height: TablTokens.espaceM),
                      Divider(height: 1, color: c.surface),
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
                          Icon(
                            Icons.nightlight_round,
                            size: 13,
                            color: c.texteDoux,
                          ),
                          const SizedBox(width: TablTokens.espaceS),
                          Expanded(
                            child: Text(
                              'Visible sur votre profil, jamais dans le Feed.',
                              style: c.legende.copyWith(fontSize: 13),
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
                    if (photos.isNotEmpty && placesRestantes > 0)
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
                  child: TablBouton(
                    libelle: 'Ajouter à mon profil',
                    enCours: _enCours,
                    onPresse: photos.isNotEmpty && lieu != null && date != null
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
    final c = TablCouleurs.of(context);
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
              style: c.titreAffichage.copyWith(fontSize: 26),
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
                        style: c.legende.copyWith(color: c.erreur),
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
