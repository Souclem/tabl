import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:app/services/services.dart';
import 'package:app/widgets/widgets.dart';

import 'recherche_lieu_en_direct.dart';

/// « Quel restaurant ? » pour un souvenir : ceux près des [endroits] des
/// photos d'abord (un par liste de [prochesParEndroit]), en liste ou sur
/// la carte, ses lieux personnels (« Mes lieux »), la recherche au fil
/// de la frappe — triée autour des photos, sinon du téléphone
/// ([positionService]) —, la saisie à la main en dernier recours, ou un
/// nouveau lieu personnel. `null` : fermée sans choisir.
Future<LieuRestaurant?> choisirRestaurant(
  BuildContext context, {
  required RechercheLieuService? rechercheLieuService,
  required PositionService? positionService,
  List<Coordonnees> endroits = const [],
  List<List<LieuRestaurant>> prochesParEndroit = const [],
  LieuRestaurant? choisi,
}) {
  return showModalBottomSheet<LieuRestaurant>(
    context: context,
    isScrollControlled: true,
    backgroundColor: TablTokens.surface,
    showDragHandle: true,
    builder: (_) => _FeuilleRestaurant(
      rechercheLieuService: rechercheLieuService,
      positionService: endroits.isNotEmpty
          ? _PositionFixe(endroits.first)
          : positionService,
      endroits: endroits,
      prochesParEndroit: prochesParEndroit,
      choisi: choisi,
    ),
  );
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

  /// « Créer un lieu personnel » : seulement un nom.
  bool _nouveauLieuPersonnel = false;
  final _nomLieuPersonnel = TextEditingController();
  String? _erreurLieuPersonnel;

  /// Mes lieux personnels, jamais proposés par la recherche.
  List<LieuRestaurant> _mesLieux = const [];

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
  void initState() {
    super.initState();
    _chargerMesLieux();
  }

  Future<void> _chargerMesLieux() async {
    try {
      final mesLieux = await widget.rechercheLieuService?.mesLieuxPersonnels();
      if (mounted && mesLieux != null) setState(() => _mesLieux = mesLieux);
    } catch (e) {
      debugPrint('choisirRestaurant: mes lieux : $e');
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _ville.dispose();
    _nomLieuPersonnel.dispose();
    super.dispose();
  }

  void _creerUnLieuPersonnel() => setState(() {
    _nouveauLieuPersonnel = true;
    _surLaCarte = false;
    if (_nomLieuPersonnel.text.isEmpty) {
      _nomLieuPersonnel.text = recherche.text.trim();
    }
  });

  void _validerLieuPersonnel() {
    final nom = _nomLieuPersonnel.text.trim();
    final erreur = nom.isEmpty
        ? 'Donnez-lui un nom.'
        : nom.length > 60
        ? '60 caractères au plus.'
        : null;
    setState(() => _erreurLieuPersonnel = erreur);
    if (erreur != null) return;
    // Le même nom qu'un de ses lieux : c'est lui.
    final existant = _mesLieux.where(
      (l) => normaliserPourRecherche(l.nom) == normaliserPourRecherche(nom),
    );
    Navigator.of(
      context,
    ).pop(existant.firstOrNull ?? LieuRestaurant.personnel(nom: nom));
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
                  if (!_aLaMain && !_nouveauLieuPersonnel)
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
              child: _nouveauLieuPersonnel
                  ? _vueLieuPersonnel()
                  : _aLaMain
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

  Widget _vueLieuPersonnel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TablTokens.espaceL - 4,
        0,
        TablTokens.espaceL - 4,
        TablTokens.espaceL,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: TablTokens.texteDoux,
              ),
            ),
            const SizedBox(width: TablTokens.espaceS),
            Expanded(
              child: Text(
                'Un lieu à vous, comme « Chez mes parents ». Seul son nom '
                'apparaît sur vos souvenirs : jamais d\'adresse ni de '
                'position, et personne d\'autre ne le retrouve.',
                style: TablTokens.legende.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: TablTokens.espaceM),
        TablChampTexte(
          libelle: 'Nom du lieu',
          controleur: _nomLieuPersonnel,
          indication: 'Chez mes parents',
          erreur: _erreurLieuPersonnel,
          actionClavier: TextInputAction.done,
          onSoumis: (_) => _validerLieuPersonnel(),
        ),
        const SizedBox(height: TablTokens.espaceL),
        TablBouton(libelle: 'Créer ce lieu', onPresse: _validerLieuPersonnel),
      ],
    );
  }

  Widget _vueListe() {
    final aCherche = recherche.text.trim().length >= 2;
    final texte = normaliserPourRecherche(recherche.text.trim());
    final mesLieux = aCherche
        ? [
            for (final l in _mesLieux)
              if (normaliserPourRecherche(l.nom).contains(texte)) l,
          ]
        : _mesLieux;
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
        if (aCherche && mesLieux.isNotEmpty) ...[
          section('MES LIEUX'),
          for (final lieu in mesLieux) ligne(lieu),
        ],
        if (aCherche) ...[
          for (final lieu in suggestions) ligne(_depuisPhotos(lieu)),
          if (!rechercheEnCours && suggestions.isEmpty && mesLieux.isEmpty)
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
        if (!aCherche && mesLieux.isNotEmpty) ...[
          section('MES LIEUX'),
          for (final lieu in mesLieux) ligne(lieu),
        ],
        const SizedBox(height: TablTokens.espaceS),
        TablBoutonTexte(
          libelle: 'Je ne trouve pas mon restaurant',
          onPresse: _passerALaMain,
        ),
        TablBoutonTexte(
          libelle: 'Créer un lieu personnel',
          onPresse: _creerUnLieuPersonnel,
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
